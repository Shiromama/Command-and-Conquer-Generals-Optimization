#![cfg(windows)]
mod windows;
use serde_json::{json, Value};
use std::os::windows::fs::{symlink_file, MetadataExt};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use std::{
    cmp::Ordering,
    collections::{BTreeMap, BTreeSet},
};
use std::{
    fs::{self, OpenOptions},
    io::Write,
    path::{Path, PathBuf},
    process::Command,
};
type Result<T> = std::result::Result<T, String>;
const STATE: &str = ".zhpatch-alpha";
const MODS: &str = "mods";
const MOD_JOURNAL: &str = "mod-journal.json";
const MOD_BACKUPS: &str = "mod-backups";
const MOD_STAGE: &str = "mod-stage.bin";
const VERSION: &str = env!("CARGO_PKG_VERSION");
const COMPATIBLE_PROFILE: &str = "compatible-local-zero-hour";

#[derive(Clone, Copy, Default)]
struct Progress(bool);

impl Progress {
    fn show(self, message: std::fmt::Arguments<'_>) {
        if self.0 {
            let mut out = std::io::stdout().lock();
            let _ = writeln!(out, "  {message}");
            let _ = out.flush();
        }
    }

    fn count(self, label: &str, done: usize, total: Option<usize>, last: &mut Instant) {
        if !self.0 || (total != Some(done) && last.elapsed() < Duration::from_secs(1)) {
            return;
        }
        if let Some(total) = total {
            let filled = 12 * done / total;
            self.show(format_args!(
                "[{}{}] {label} {done}/{total}",
                "#".repeat(filled),
                "-".repeat(12 - filled)
            ));
        } else {
            self.show(format_args!("{label} {done} files so far..."));
        }
        *last = Instant::now();
    }
}

#[derive(Eq)]
struct WindowsPath(String);

impl Ord for WindowsPath {
    fn cmp(&self, other: &Self) -> Ordering {
        windows::compare_paths(&self.0, &other.0)
    }
}
impl PartialOrd for WindowsPath {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}
impl PartialEq for WindowsPath {
    fn eq(&self, other: &Self) -> bool {
        self.cmp(other) == Ordering::Equal
    }
}
fn error<T>(message: impl Into<String>) -> Result<T> {
    Err(message.into())
}
fn io<T>(value: std::io::Result<T>) -> Result<T> {
    value.map_err(|e| e.to_string())
}
fn string<'a>(v: &'a Value, key: &str) -> Result<&'a str> {
    v[key]
        .as_str()
        .ok_or_else(|| format!("Missing/invalid {key}"))
}
fn load(p: &Path) -> Result<Value> {
    serde_json::from_slice(&io(fs::read(p))?).map_err(|e| e.to_string())
}
fn safe_name(name: &str) -> Result<()> {
    if name.is_empty()
        || name.contains(['\\', ':'])
        || name.split('/').any(|p| {
            p.is_empty() || p == "." || p == ".." || p.ends_with(['.', ' ']) || p.contains('~')
        })
    {
        return error("Unsafe relative path");
    }
    Ok(())
}
fn unlinked(p: &Path) -> Result<()> {
    let m = io(fs::symlink_metadata(p))?;
    if m.file_attributes() & 0x400 != 0 {
        return error(format!("Linked path refused: {}", p.display()));
    }
    if m.is_file() && !io(windows::single_link(p))? {
        return error(format!("Hard link refused: {}", p.display()));
    }
    Ok(())
}
fn unlinked_tree(root: &Path) -> Result<()> {
    let mut pending = vec![root.to_path_buf()];
    while let Some(dir) = pending.pop() {
        unlinked(&dir)?;
        for item in io(fs::read_dir(&dir))? {
            let path = io(item)?.path();
            unlinked(&path)?;
            if path.is_dir() {
                pending.push(path);
            }
        }
    }
    Ok(())
}
fn target(input: &Path) -> Result<PathBuf> {
    let absolute = if input.is_absolute() {
        input.to_path_buf()
    } else {
        io(std::env::current_dir())?.join(input)
    };
    for c in absolute.components() {
        if let std::path::Component::Normal(s) = c {
            safe_name(&s.to_string_lossy())?
        }
    }
    for a in absolute.ancestors() {
        if a.exists() {
            unlinked(a)?
        }
    }
    let root = io(fs::canonicalize(&absolute))?;
    if !root.is_dir() {
        return error("Game directory required");
    }
    for a in root.ancestors() {
        if a.file_name()
            .map(|s| {
                s.to_string_lossy()
                    .eq_ignore_ascii_case("baseline-pristine")
            })
            .unwrap_or(false)
        {
            return error("Immutable baseline refused");
        }
        if a.join("AGENTS.md").is_file() && a.join("docs/state.json").is_file() {
            let parent = root.parent().unwrap_or(&root);
            if parent != a.join("game") || root.file_name().map(|s| s == "profiles").unwrap_or(true)
            {
                return error(
                    "Only mutable game copies may be patched inside the development workspace",
                );
            }
        }
    }
    Ok(root)
}
fn scan(
    root: &Path,
    overlay: &BTreeSet<WindowsPath>,
    progress: Progress,
) -> Result<BTreeMap<String, String>> {
    fn walk(
        root: &Path,
        dir: &Path,
        overlay: &BTreeSet<WindowsPath>,
        result: &mut BTreeMap<String, String>,
        progress: Progress,
        last_report: &mut Instant,
    ) -> Result<()> {
        for item in io(fs::read_dir(dir))? {
            let p = io(item)?.path();
            let rel = io(p.strip_prefix(root).map_err(std::io::Error::other))?
                .to_string_lossy()
                .replace('\\', "/");
            safe_name(&rel)?;
            if rel.eq_ignore_ascii_case(STATE) || overlay.contains(&WindowsPath(rel.clone())) {
                continue;
            }
            unlinked(&p)?;
            let rel = rel.to_lowercase();
            if p.is_dir() {
                walk(root, &p, overlay, result, progress, last_report)?
            } else {
                let ext = p
                    .extension()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_lowercase();
                if catalog_file(&rel, &ext) {
                    result.insert(rel, windows::hash(&p)?);
                    progress.count("Checked", result.len(), None, last_report);
                }
            }
        }
        Ok(())
    }
    let mut result = BTreeMap::new();
    walk(root, root, overlay, &mut result, progress, &mut Instant::now())?;
    Ok(result)
}
fn catalog_file(rel: &str, ext: &str) -> bool {
    rel.starts_with("data/")
        || rel.starts_with("maps/")
        || ["big", "gib", "scb", "dll", "exe", "asi"].contains(&ext)
        || rel == "game.dat"
        || rel == "shockwave_lnchr.dat"
}
fn atomic_bytes(path: &Path, bytes: &[u8]) -> Result<()> {
    // Deterministic scratch names are reserved; refuse leftovers instead of deleting unknown files.
    let temp = path.with_file_name(format!(
        "{}.zhpatch-tmp",
        path.file_name().unwrap().to_string_lossy()
    ));
    if temp.exists() {
        return error(format!(
            "Reserved temporary file exists: {}",
            temp.display()
        ));
    }
    let mut f = io(OpenOptions::new().write(true).create_new(true).open(&temp))?;
    io(f.write_all(bytes))?;
    io(f.sync_all())?;
    drop(f);
    io(windows::replace(&temp, path))
}
fn save(path: &Path, value: &Value) -> Result<()> {
    atomic_bytes(
        path,
        &serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?,
    )
}
fn digest(path: &Path) -> Result<Value> {
    if path.exists() {
        unlinked(path)?;
        Ok(json!(windows::hash(path)?))
    } else {
        Ok(Value::Null)
    }
}
fn package(dir: &Path) -> Result<Value> {
    let m = load(&dir.join("manifest.json"))?;
    if m["version"] != VERSION || m["schema"] != 1 {
        return error("Unsupported package version/schema");
    }
    for (name, hash) in m["payload"].as_object().ok_or("Invalid payload")? {
        safe_name(name)?;
        unlinked(&dir.join(name))?;
        if windows::hash(&dir.join(name))? != hash.as_str().ok_or("Invalid payload hash")? {
            return error(format!("Package checksum mismatch: {name}"));
        }
    }
    if m["payload"]["engine.exe"].as_str().is_none() {
        return error("Engine payload missing");
    }
    Ok(m)
}
fn identify(root: &Path, m: &Value, progress: Progress) -> Result<Value> {
    let actual = scan(root, &BTreeSet::new(), progress)?;
    for p in m["profiles"].as_array().ok_or("Missing profiles")? {
        let expected: BTreeMap<String, String> =
            serde_json::from_value(p["files"].clone()).map_err(|e| e.to_string())?;
        if actual == expected {
            return Ok(p.clone());
        }
    }
    if m["compatible_runtime"] == true {
        return compatible_profile(serde_json::to_value(actual).map_err(|e| e.to_string())?, m);
    }
    error("Unknown or changed runtime file set. This alpha supports only the exact cataloged stock/ShockWave snapshots; nothing changed.")
}
fn compatible_profile(files: Value, m: &Value) -> Result<Value> {
    if m["compatible_runtime"] != true || !files.is_object() {
        return error("Compatible runtime profile unavailable");
    }
    let profiles = m["profiles"].as_array().ok_or("Missing profiles")?;
    let recognized = |name: &str| {
        files[name].is_string() && profiles.iter().any(|p| p["files"][name] == files[name])
    };
    if !recognized("generals.exe") || (!files["game.dat"].is_null() && !recognized("game.dat")) {
        return error("Unsupported Zero Hour engine build. This package requires a recognized Generals.exe and game.dat if present.");
    }
    if !files["inizh.big"].is_string() || !files["w3dzh.big"].is_string() {
        return error("Zero Hour data archives INIZH.big and W3DZH.big are required.");
    }
    if !files["d3d8.dll"].is_null() && !recognized("d3d8.dll") {
        return error("Unsupported d3d8.dll graphics proxy. Use a game copy with system Direct3D or the cataloged GenTool proxy.");
    }
    if files["shockwave_lnchr.dat"].is_string() {
        let profile = profiles.iter().find(|p| {
            p["files"]["shockwave_lnchr.dat"] == files["shockwave_lnchr.dat"]
        }).ok_or("Unsupported ShockWave launcher layout")?;
        // Only reuse the known mapping when every source and destination has its cataloged hash.
        let mappings = profile["materialize"].as_array().ok_or("Invalid materialization map")?;
        for mapping in mappings {
            for key in ["from", "to"] {
                let path = string(mapping, key)?.to_lowercase();
                if files[path.as_str()] != profile["files"][path.as_str()] {
                    return error("ShockWave launcher-managed files differ from the supported layout. Use the reference copy or an active data-only layout.");
                }
            }
        }
        return Ok(json!({"id":COMPATIBLE_PROFILE,"files":files,"materialize":mappings}));
    }
    Ok(json!({"id":COMPATIBLE_PROFILE,"files":files,"materialize":[]}))
}
fn journal_profile(j: &Value, m: &Value) -> Result<Value> {
    if j["profile"] == COMPATIBLE_PROFILE {
        return compatible_profile(j["local_inventory"].clone(), m);
    }
    m["profiles"]
        .as_array()
        .ok_or("Missing profiles")?
        .iter()
        .find(|p| p["id"] == j["profile"])
        .cloned()
        .ok_or("Journal profile missing from package".into())
}
fn entries(j: &Value) -> Result<&Vec<Value>> {
    j["entries"]
        .as_array()
        .ok_or("Invalid journal entries".into())
}
fn validate_journal(root: &Path, j: &Value, m: &Value) -> Result<()> {
    if j["schema"] != 1 || j["version"] != VERSION || j["target"] != root.to_string_lossy().as_ref()
    {
        return error("Journal identity mismatch");
    }
    let profile = journal_profile(j, m)?;
    let expected = plan(root, &profile, m)?;
    fn normalized(mut value: Value) -> Value {
        if let Some(items) = value.as_array_mut() {
            for e in items {
                for key in ["path", "source"] {
                    if let Some(text) = e[key].as_str() {
                        e[key] = json!(text.to_ascii_lowercase());
                    }
                }
            }
        }
        value
    }
    if normalized(j["entries"].clone()) != normalized(expected) {
        return error("Journal plan differs from trusted package/catalog");
    }
    Ok(())
}
fn spelling(root: &Path, relative: &str) -> Result<String> {
    safe_name(relative)?;
    let mut current = root.to_path_buf();
    let mut parts = Vec::new();
    for part in relative.split('/') {
        let mut name = part.to_owned();
        if current.is_dir() {
            for entry in io(fs::read_dir(&current))? {
                let entry = io(entry)?;
                if windows::compare_paths(&entry.file_name().to_string_lossy(), part)
                    == Ordering::Equal
                {
                    name = entry.file_name().to_string_lossy().into_owned();
                    break;
                }
            }
        }
        current.push(&name);
        parts.push(name);
    }
    Ok(parts.join("/"))
}
fn plan(root: &Path, p: &Value, m: &Value) -> Result<Value> {
    let engine = spelling(root, p["engine_path"].as_str().unwrap_or("Generals.exe"))?;
    let proxy = spelling(root, p["proxy_path"].as_str().unwrap_or("d3d8.dll"))?;
    if !engine.eq_ignore_ascii_case("generals.exe") || !proxy.eq_ignore_ascii_case("d3d8.dll") {
        return error("Invalid managed engine/proxy path");
    }
    let mut result = vec![
        json!({"path":engine,"before":p["files"]["generals.exe"],"after":m["payload"]["engine.exe"],"source":"engine.exe"}),
    ];
    if !p["files"]["d3d8.dll"].is_null() {
        result
            .push(json!({"path":proxy,"before":p["files"]["d3d8.dll"],"after":null,"source":null}))
    }
    for mapping in p["materialize"]
        .as_array()
        .ok_or("Invalid materialization map")?
    {
        let from_name = spelling(root, string(mapping, "from")?)?;
        let to_name = spelling(root, string(mapping, "to")?)?;
        let from = from_name.as_str();
        let to = to_name.as_str();
        let archive = !from.contains('/')
            && !to.contains('/')
            && from.ends_with(".gib")
            && to.ends_with(".big");
        let script = [
            "data/scripts/multiplayerscripts.scb",
            "data/scripts/scripts.ini",
            "data/scripts/skirmishscripts.scb",
        ]
        .contains(&from.to_lowercase().as_str())
            && to.to_ascii_lowercase()
                == format!(
                    "{}.bcs",
                    from.to_ascii_lowercase()
                        .rsplit_once('.')
                        .ok_or("Invalid script path")?
                        .0
                );
        let remove_source = mapping["remove_source"].as_bool().unwrap_or(false);
        if !(archive && !remove_source || script && remove_source) {
            return error("Unsupported materialization path");
        }
        result.push(
            json!({"path":to,"before":p["files"][to.to_lowercase()],"after":p["files"][from.to_lowercase()],"source":from}),
        );
        if remove_source {
            result.push(json!({"path":from,"before":p["files"][from.to_lowercase()],"after":null,"source":null}));
        }
    }
    if result
        .iter()
        .any(|e| e["after"].is_null() && e["before"].is_null())
    {
        return error("Empty mutation");
    }
    Ok(json!(result))
}
fn backup_path(root: &Path, i: usize) -> PathBuf {
    root.join(STATE).join(format!("original-{i}.bin"))
}
fn managed_backup_name(name: &str) -> bool {
    name.strip_prefix("original-")
        .and_then(|s| s.strip_suffix(".bin"))
        .and_then(|s| s.parse::<usize>().ok())
        .is_some()
}
fn finish_migration(state: &Path) -> Result<()> {
    let marker = state.join("migration.json");
    let m = load(&marker)?;
    let archive = string(&m, "archive")?;
    if archive.is_empty() || !archive.bytes().all(|b| b.is_ascii_digit()) {
        return error("Invalid state archive");
    }
    let directory = state.join("history").join(archive);
    let files = m["files"]
        .as_array()
        .ok_or("Invalid state archive inventory")?;
    // Verify the entire archived snapshot before removing any obsolete current metadata.
    for item in files {
        let name = string(item, "name")?;
        if name != "journal.json" && !managed_backup_name(name) {
            return error("Invalid archived metadata path");
        }
        let expected = string(item, "sha256")?;
        if windows::hash(&directory.join(name))? != expected {
            return error("Archived state checksum mismatch");
        }
        let current = state.join(name);
        if current.exists() && windows::hash(&current)? != expected {
            return error("Current metadata changed during archive; preserved");
        }
    }
    checkpoint(1000);
    for (i, item) in files.iter().enumerate() {
        let current = state.join(string(item, "name")?);
        if current.exists() {
            io(fs::remove_file(current))?;
        }
        checkpoint(1001 + i);
    }
    io(fs::remove_file(marker))?;
    Ok(())
}
fn archive_uninstalled(state: &Path) -> Result<()> {
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_nanos()
        .to_string();
    let history = state.join("history");
    if !history.exists() {
        io(fs::create_dir(&history))?;
    }
    let directory = history.join(&stamp);
    io(fs::create_dir(&directory))?;
    let mut files = Vec::new();
    for item in io(fs::read_dir(state))? {
        let path = io(item)?.path();
        let name = path
            .file_name()
            .ok_or("Invalid metadata name")?
            .to_string_lossy()
            .into_owned();
        if name != "journal.json" && !managed_backup_name(&name) {
            continue;
        }
        let bytes = io(fs::read(&path))?;
        atomic_bytes(&directory.join(&name), &bytes)?;
        let digest = windows::hash(&path)?;
        if windows::hash(&directory.join(&name))? != digest {
            return error("Metadata archive copy failed");
        }
        files.push(json!({"name":name,"sha256":digest}));
    }
    let migration = json!({"archive":stamp,"files":files});
    save(&directory.join("inventory.json"), &migration)?;
    save(&state.join("migration.json"), &migration)?;
    finish_migration(state)
}
fn verify_backups(root: &Path, j: &Value) -> Result<()> {
    for (i, e) in entries(j)?.iter().enumerate() {
        if !e["before"].is_null() && digest(&backup_path(root, i))? != e["before"] {
            return error(format!(
                "Missing/corrupt original backup {i}; no restoration attempted"
            ));
        }
    }
    Ok(())
}
fn conflicts(root: &Path, j: &Value) -> Result<()> {
    for e in entries(j)? {
        let p = root.join(string(e, "path")?);
        let h = digest(&p)?;
        if h != e["before"] && h != e["after"] {
            return error(format!(
                "Changed file preserved: {}. Resolve manually; no force overwrite supported.",
                p.display()
            ));
        }
    }
    Ok(())
}
fn checkpoint(count: usize) {
    // Test hook deliberately hard-exits after a durable operation; no unwinding/cleanup.
    #[cfg(debug_assertions)]
    if std::env::var("ZHPATCH_TEST_INTERRUPT")
        .ok()
        .and_then(|s| s.parse().ok())
        == Some(count)
    {
        std::process::exit(86)
    }
    #[cfg(not(debug_assertions))]
    let _ = count;
}
fn quarantine_scratch(root: &Path, j: Option<&Value>) -> Result<()> {
    let state = root.join(STATE);
    let mut paths = vec![
        state.join("journal.json.zhpatch-tmp"),
        state.join("migration.json.zhpatch-tmp"),
    ];
    for f in io(fs::read_dir(&state))? {
        let p = io(f)?.path();
        let n = p.file_name().unwrap().to_string_lossy();
        if n.starts_with("original-") && n.ends_with(".bin.zhpatch-tmp") {
            paths.push(p)
        }
    }
    if let Some(j) = j {
        for e in entries(j)? {
            paths.push(root.join(format!("{}.zhpatch-tmp", string(e, "path")?)))
        }
    }
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_nanos();
    for (i, p) in paths.iter().enumerate() {
        if p.exists() {
            unlinked(p)?;
            let destination = state.join(format!("recovered-{stamp}-{i}.bin"));
            io(fs::rename(p, destination))?;
        }
    }
    Ok(())
}
fn restore(root: &Path, j: &mut Value, journal: &Path, progress: Progress) -> Result<()> {
    progress.show(format_args!("Checking backups and current files..."));
    verify_backups(root, j)?;
    conflicts(root, j)?;
    j["status"] = json!("removing");
    save(journal, j)?;
    let list = entries(j)?.clone();
    progress.show(format_args!("Restoring and verifying original files..."));
    let mut last_report = Instant::now();
    for (i, e) in list.iter().enumerate() {
        let path = root.join(string(e, "path")?);
        let current = digest(&path)?;
        if current != e["before"] && current != e["after"] {
            return error("Target changed during restoration; preserved");
        }
        if current != e["before"] {
            if !e["before"].is_null() && digest(&backup_path(root, i))? != e["before"] {
                return error("Backup changed during restoration");
            }
            if e["before"].is_null() {
                io(fs::remove_file(&path))?
            } else {
                atomic_bytes(&path, &io(fs::read(backup_path(root, i)))?)?
            }
        }
        if digest(&path)? != e["before"] {
            return error("Restoration verification failed");
        }
        progress.count("Paths checked", i + 1, Some(list.len()), &mut last_report);
        checkpoint(i + 1);
    }
    j["status"] = json!("uninstalled");
    save(journal, j)?;
    Ok(())
}
fn installed(root: &Path, j: &Value, m: &Value, progress: Progress) -> Result<()> {
    if j["status"] != "installed" {
        return error("Not completely installed; use recover");
    }
    progress.show(format_args!("Verifying installed files and backups..."));
    verify_backups(root, j)?;
    for e in entries(j)? {
        if digest(&root.join(string(e, "path")?))? != e["after"] {
            return error("Installed file changed or missing");
        }
    }
    check_base_inventory(j, m, scan(root, &BTreeSet::new(), progress)?)
}
fn check_base_inventory(j: &Value, m: &Value, actual: BTreeMap<String, String>) -> Result<()> {
    let profile = journal_profile(j, m)?;
    let mut expected = profile["files"]
        .as_object()
        .ok_or("Invalid catalog")?
        .clone();
    for e in entries(j)? {
        let key = string(e, "path")?.to_lowercase();
        if e["after"].is_null() {
            expected.remove(&key);
        } else {
            expected.insert(key, e["after"].clone());
        }
    }
    if serde_json::to_value(actual).map_err(|e| e.to_string())? != Value::Object(expected) {
        return error("Runtime assets changed since installation");
    }
    Ok(())
}

// ------------------------------------------------------------------------------------------------
// Community mod library and transactional overlay (T-082 / ADR-0019).
//
// Mods stay under .zhpatch-alpha/mods/<id>/files. Activation links/copies the selected data
// files into the game root, preserves displaced originals, and records everything in a
// separate mod journal. The exact base installation remains the compatibility boundary.
// ------------------------------------------------------------------------------------------------
fn mods_root(root: &Path) -> PathBuf {
    root.join(STATE).join(MODS)
}
fn mod_dir(root: &Path, id: &str) -> PathBuf {
    mods_root(root).join(id)
}
fn mod_files_dir(root: &Path, id: &str) -> PathBuf {
    mod_dir(root, id).join("files")
}
fn mod_manifest_path(root: &Path, id: &str) -> PathBuf {
    mod_dir(root, id).join("manifest.json")
}
fn mod_active_path(root: &Path) -> PathBuf {
    mods_root(root).join("active.json")
}
fn mod_journal_path(root: &Path) -> PathBuf {
    root.join(STATE).join(MOD_JOURNAL)
}
fn mod_journal_scratch(root: &Path) -> PathBuf {
    root.join(STATE).join(format!("{MOD_JOURNAL}.zhpatch-tmp"))
}
fn mod_backups_dir(root: &Path) -> PathBuf {
    root.join(STATE).join(MOD_BACKUPS)
}
fn mod_backup_path(root: &Path, i: usize) -> PathBuf {
    mod_backups_dir(root).join(format!("{i:04}.bin"))
}
fn stamp() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos().to_string())
        .unwrap_or_else(|_| "0".into())
}
fn mod_valid_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 64
        && !id.starts_with('.')
        && id
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'))
}
fn mod_id_from(raw: &str) -> Result<String> {
    let mut out = String::new();
    for c in raw.chars() {
        if c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.') {
            out.push(c);
        } else {
            out.push('-');
        }
    }
    while out.starts_with(['.', '-']) {
        out.remove(0);
    }
    while out.ends_with(['.', '-', ' ']) {
        out.pop();
    }
    if out.is_empty() {
        out.push_str("mod");
    }
    if out.len() > 64 {
        out.truncate(64);
    }
    if !mod_valid_id(&out) {
        return error("Cannot derive a safe mod id; use --id");
    }
    Ok(out)
}
fn mod_input(source: &Path) -> Result<PathBuf> {
    let meta = io(fs::symlink_metadata(source))?;
    if meta.file_attributes() & 0x400 != 0 {
        return error("Linked mod source refused");
    }
    let path = io(fs::canonicalize(source))?;
    if !path.exists() {
        return error("Mod source missing");
    }
    Ok(path)
}
fn copy_file_atomic(src: &Path, dst: &Path) -> Result<()> {
    if let Some(parent) = dst.parent() {
        io(fs::create_dir_all(parent))?;
    }
    let name = dst
        .file_name()
        .ok_or("Invalid mod destination")?
        .to_string_lossy();
    let temp = dst.with_file_name(format!("{name}.zhpatch-tmp"));
    if temp.exists() {
        return error(format!("Reserved temporary file exists: {}", temp.display()));
    }
    io(fs::copy(src, &temp))?;
    let f = io(OpenOptions::new().read(true).write(true).open(&temp))?;
    io(f.sync_all())?;
    drop(f);
    io(windows::replace(&temp, dst))?;
    if windows::hash(dst)? != windows::hash(src)? {
        let _ = fs::remove_file(dst);
        return error("Mod copy hash mismatch");
    }
    Ok(())
}
fn mod_skip(rel: &str) -> bool {
    let ext = Path::new(rel)
        .extension()
        .unwrap_or_default()
        .to_string_lossy()
        .to_lowercase();
    ["exe", "dll", "asi", "bat", "cmd", "ps1", "msi", "lnk"].contains(&ext.as_str())
}
fn mod_target_rel(rel: &str) -> Result<String> {
    safe_name(rel)?;
    let path = Path::new(rel);
    let ext = path
        .extension()
        .unwrap_or_default()
        .to_string_lossy()
        .to_lowercase();
    let target = if matches!(ext.as_str(), "gib" | "zbig") {
        path.with_extension("big")
            .to_string_lossy()
            .replace('\\', "/")
    } else {
        rel.replace('\\', "/")
    };
    safe_name(&target)?;
    if target
        .split('/')
        .next()
        .is_some_and(|part| part.eq_ignore_ascii_case(STATE))
    {
        return error("Mod may not write patcher state");
    }
    if mod_skip(&target) {
        return error("Mod may not activate executables, DLLs or scripts");
    }
    Ok(target)
}
fn mod_manifest(root: &Path, id: &str) -> Result<Value> {
    if !mod_valid_id(id) {
        return error("Invalid mod id");
    }
    let m = load(&mod_manifest_path(root, id))?;
    if m["schema"] != 1 || !m["files"].is_object() {
        return error("Invalid mod manifest");
    }
    Ok(m)
}
fn mod_load_active(root: &Path) -> Result<Vec<String>> {
    let path = mod_active_path(root);
    if !path.exists() {
        return Ok(Vec::new());
    }
    let j = load(&path)?;
    let list = j["mods"].as_array().ok_or("Invalid active mod list")?;
    let mut result = Vec::new();
    for id in list {
        let id = id.as_str().ok_or("Invalid active mod id")?;
        if !mod_valid_id(id) {
            return error("Invalid active mod id");
        }
        result.push(id.to_owned());
    }
    Ok(result)
}
fn mod_save_active(root: &Path, ids: &[String]) -> Result<()> {
    if ids.iter().any(|id| !mod_valid_id(id)) {
        return error("Invalid mod id");
    }
    save(
        &mod_active_path(root),
        &json!({"schema":1,"version":VERSION,"mods":ids}),
    )
}
fn mod_journal(root: &Path) -> Result<Option<Value>> {
    let path = mod_journal_path(root);
    if !path.exists() {
        return Ok(None);
    }
    Ok(Some(load(&path)?))
}
fn mod_journal_active(root: &Path) -> Result<bool> {
    if metadata(&mod_journal_scratch(root))?.is_some() {
        return Ok(true);
    }
    match mod_journal(root)? {
        None => Ok(false),
        Some(j) => match string(&j, "status")? {
            "restored" => Ok(false),
            "prepared" | "preparing" | "active" | "restoring" => Ok(true),
            _ => error("Invalid mod overlay state"),
        },
    }
}
fn mod_require_base(root: &Path, package: &Value) -> Result<()> {
    let path = root.join(STATE).join("journal.json");
    if !path.exists() {
        return error("Install the base alpha first");
    }
    let j = load(&path)?;
    validate_journal(root, &j, package)?;
    installed(root, &j, package, Progress::default())
}
fn mod_walk_source(source: &Path, visit: &mut dyn FnMut(&str, &Path) -> Result<()>) -> Result<()> {
    if source.is_file() {
        unlinked(source)?;
        let name = source
            .file_name()
            .ok_or("Invalid mod file")?
            .to_string_lossy()
            .into_owned();
        safe_name(&name)?;
        return visit(&name, source);
    }
    if !source.is_dir() {
        return error("Mod source must be a folder, archive or .big/.gib/.zbig file");
    }
    fn walk(
        dir: &Path,
        prefix: &str,
        visit: &mut dyn FnMut(&str, &Path) -> Result<()>,
    ) -> Result<()> {
        for item in io(fs::read_dir(dir))? {
            let path = io(item)?.path();
            unlinked(&path)?;
            let name = path
                .file_name()
                .ok_or("Invalid mod filename")?
                .to_string_lossy();
            let rel = if prefix.is_empty() {
                name.into_owned()
            } else {
                format!("{prefix}/{name}")
            };
            safe_name(&rel)?;
            if path.is_dir() {
                walk(&path, &rel, visit)?;
            } else if path.is_file() {
                visit(&rel, &path)?;
            }
        }
        Ok(())
    }
    walk(source, "", visit)
}
fn mod_source(input: &Path) -> Result<PathBuf> {
    let source = mod_input(input)?;
    if source.is_dir() {
        return Ok(source);
    }
    let ext = source
        .extension()
        .unwrap_or_default()
        .to_string_lossy()
        .to_ascii_lowercase();
    match ext.as_str() {
        "big" | "gib" | "zbig" if source.is_file() => Ok(source),
        "zip" | "7z" | "rar" => error("Compressed archives must be extracted separately. Pass the prepared folder as --source."),
        "exe" | "msi" | "bat" | "cmd" | "ps1" => error("Installer/script packages are not executed. Pass a prepared mod folder as --source."),
        _ => error("Unsupported mod package. Use a prepared folder or a .big/.gib/.zbig file."),
    }
}

fn mod_add(root: &Path, source: &Path, requested: Option<&str>) -> Result<()> {
    let source = mod_source(source)?;
    if source.starts_with(root) {
        return error("Point at the mod folder/archive outside the game copy");
    }
    let state = root.join(STATE);
    if !state.is_dir() {
        return error("Install the base alpha first");
    }
    let raw_id = requested.map(str::to_owned).or_else(|| {
        source
            .file_stem()
            .or_else(|| source.file_name())
            .map(|s| s.to_string_lossy().into_owned())
    });
    let id = match requested {
        Some(value) if !mod_valid_id(value) => return error("Invalid --id"),
        Some(value) => value.to_owned(),
        None => mod_id_from(raw_id.as_deref().ok_or("Cannot name mod")?)?,
    };
    if mod_dir(root, &id).exists() {
        return error(format!("Mod already exists: {id}"));
    }
    let files_root = mod_files_dir(root, &id);
    io(fs::create_dir_all(&files_root))?;
    let mut files = BTreeMap::new();
    let mut skipped: Vec<Value> = Vec::new();
    let mut usable = 0usize;
    let result = mod_walk_source(&source, &mut |rel, path| {
        if mod_skip(rel) {
            skipped.push(json!({"path":rel,"reason":"executable/dll/script skipped"}));
            return Ok(());
        }
        let target = files_root.join(rel);
        copy_file_atomic(path, &target)?;
        files.insert(rel.replace('\\', "/"), windows::hash(&target)?);
        usable += 1;
        Ok(())
    });
    if let Err(e) = result {
        let _ = fs::remove_dir_all(mod_dir(root, &id));
        return Err(e);
    }
    if files.is_empty() {
        let _ = fs::remove_dir_all(mod_dir(root, &id));
        return error("Mod has no usable data files");
    }
    let manifest = json!({
        "schema":1,
        "version":VERSION,
        "id":id,
        "source":source.to_string_lossy(),
        "imported_at":stamp(),
        "files":files,
        "skipped":skipped,
    });
    save(&mod_manifest_path(root, &id), &manifest)?;
    println!(
        "Imported mod {id}: {usable} usable file(s), {} skipped",
        manifest["skipped"].as_array().map(|v| v.len()).unwrap_or(0)
    );
    Ok(())
}
fn mod_inspect(source: &Path) -> Result<()> {
    let source = mod_source(source)?;
    let mut usable = 0usize;
    let mut skipped = 0usize;
    let mut bytes = 0u64;
    mod_walk_source(&source, &mut |rel, path| {
        if mod_skip(rel) {
            println!("SKIP {rel} (executable/dll/script)");
            skipped += 1;
            return Ok(());
        }
        let target = mod_target_rel(rel)?;
        let size = io(fs::metadata(path))?.len();
        bytes += size;
        usable += 1;
        println!("{rel} -> {target} ({size} bytes)");
        Ok(())
    })?;
    println!("Package: {usable} usable file(s), {skipped} skipped, {bytes} bytes");
    Ok(())
}
fn mod_list(root: &Path) -> Result<()> {
    let active = mod_load_active(root)?;
    let dir = mods_root(root);
    if !dir.is_dir() {
        println!("No mod library at {}", dir.display());
        return Ok(());
    }
    let mut ids = Vec::new();
    for item in io(fs::read_dir(&dir))? {
        let path = io(item)?.path();
        if path.is_dir() {
            if let Some(name) = path.file_name() {
                let name = name.to_string_lossy().into_owned();
                if mod_manifest_path(root, &name).is_file() {
                    ids.push(name);
                }
            }
        }
    }
    ids.sort();
    if ids.is_empty() {
        println!("No mods imported");
        return Ok(());
    }
    for id in ids {
        if let Ok(m) = mod_manifest(root, &id) {
            let count = m["files"].as_object().map(|v| v.len()).unwrap_or(0);
            let order = active
                .iter()
                .position(|v| v == &id)
                .map(|v| format!("active #{}", v + 1))
                .unwrap_or_else(|| "-".into());
            println!("{id}\t{count} file(s)\t{order}");
        }
    }
    if active.is_empty() {
        println!("No active mods");
    } else {
        println!("Active order: {}", active.join(", "));
    }
    Ok(())
}
fn mod_set_active(root: &Path, ids: &[String]) -> Result<()> {
    if mod_journal_active(root)? {
        return error("Restore the active mod overlay first");
    }
    if windows::game_running()? {
        return error("Close the game before changing the active mod list");
    }
    for id in ids {
        mod_manifest(root, id)?;
    }
    mod_save_active(root, ids)?;
    println!("Active mods: {}", if ids.is_empty() { "(none)".into() } else { ids.join(", ") });
    Ok(())
}
fn mod_remove(root: &Path, id: &str) -> Result<()> {
    if !mod_valid_id(id) {
        return error("Invalid mod id");
    }
    if mod_journal_active(root)? {
        return error("Restore the active mod overlay first");
    }
    let dir = mod_dir(root, id);
    if !dir.is_dir() || !mod_manifest_path(root, id).is_file() {
        return error("Unknown mod");
    }
    unlinked_tree(&dir)?;
    io(fs::remove_dir_all(&dir))?;
    let mut active = mod_load_active(root)?;
    if active.iter().any(|v| v == id) {
        active.retain(|v| v != id);
        mod_save_active(root, &active)?;
    }
    println!("Removed mod {id}");
    Ok(())
}
fn mod_entry_path(e: &Value) -> Result<&str> {
    let path = string(e, "path")?;
    safe_name(path)?;
    if !mod_valid_id(string(e, "mod")?) {
        return error("Invalid mod id in journal");
    }
    let target = mod_target_rel(string(e, "source")?)?;
    if windows::compare_paths(path, &target) != Ordering::Equal {
        return error("Mod journal target does not match its source path");
    }
    Ok(path)
}

fn metadata(path: &Path) -> Result<Option<fs::Metadata>> {
    match fs::symlink_metadata(path) {
        Ok(meta) => Ok(Some(meta)),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

// Check parents before reading, deleting, or restoring any overlay target.
fn mod_parents(root: &Path, target: &Path) -> Result<()> {
    for parent in target.ancestors().skip(1).take_while(|p| *p != root) {
        if let Some(meta) = metadata(parent)? {
            unlinked(parent)?;
            if !meta.is_dir() {
                return error(format!("Mod parent is a file: {}", parent.display()));
            }
        }
    }
    Ok(())
}

fn mod_plan(root: &Path, ids: &[String]) -> Result<Value> {
    let mut targets = BTreeMap::new();
    for id in ids {
        let m = mod_manifest(root, id)?;
        let files = m["files"].as_object().ok_or("Invalid mod files")?;
        let mut seen = BTreeSet::new();
        for (rel, hash) in files {
            let hash = hash.as_str().ok_or("Invalid mod hash")?;
            let target = mod_target_rel(rel)?;
            if !seen.insert(WindowsPath(target.clone())) {
                return error(format!("Duplicate target in mod {id}: {target}"));
            }
            targets.insert(
                WindowsPath(target.clone()),
                (target, id, rel.clone(), hash.to_owned()),
            );
        }
    }
    if targets.is_empty() {
        return error("Active mods contain no activatable files");
    }
    let mut result = Vec::new();
    let mut directories = BTreeSet::new();
    for (target, id, rel, after) in targets.values() {
        let target = spelling(root, target)?;
        let path = root.join(&target);
        mod_parents(root, &path)?;
        let before = digest(&path)?;
        if path.is_dir() {
            return error(format!("Mod target is a directory: {}", path.display()));
        }
        let source = mod_files_dir(root, id).join(rel);
        if digest(&source)? != *after {
            return error(format!("Mod source changed: {id}/{rel}"));
        }
        for parent in Path::new(&target)
            .ancestors()
            .skip(1)
            .filter(|p| !p.as_os_str().is_empty())
        {
            let key = WindowsPath(parent.to_string_lossy().replace('\\', "/"));
            if targets.contains_key(&key) {
                return error(format!(
                    "Mod target is also a parent directory: {}",
                    parent.display()
                ));
            }
            if !root.join(parent).exists() {
                directories.insert(key);
            }
        }
        result.push(json!({"path":target,"before":before,"after":after,"mod":id,"source":rel}));
    }
    Ok(json!({
        "schema":1,
        "version":VERSION,
        "target":root.to_string_lossy(),
        "status":"prepared",
        "mods":ids,
        "entries":result,
        "directories":directories.into_iter().map(|p| p.0).collect::<Vec<_>>(),
    }))
}

fn validate_mod_journal(root: &Path, j: &Value) -> Result<()> {
    if j["schema"] != 1 || j["version"] != VERSION || j["target"] != root.to_string_lossy().as_ref()
    {
        return error("Mod journal identity mismatch");
    }
    let mut targets = BTreeSet::new();
    let mut parents = BTreeSet::new();
    for e in entries(j)? {
        let path = mod_entry_path(e)?;
        if !targets.insert(WindowsPath(path.to_owned())) {
            return error("Duplicate Windows target in mod journal; originals were left in place");
        }
        string(e, "after")?;
        if !e["before"].is_null() {
            string(e, "before")?;
        }
        mod_parents(root, &root.join(path))?;
        for parent in Path::new(path)
            .ancestors()
            .skip(1)
            .filter(|p| !p.as_os_str().is_empty())
        {
            parents.insert(WindowsPath(parent.to_string_lossy().replace('\\', "/")));
        }
    }
    if targets.is_empty() || targets.iter().any(|p| parents.contains(p)) {
        return error("Invalid mod journal target set");
    }
    let dirs = j["directories"]
        .as_array()
        .ok_or("Invalid mod directories")?;
    for dir in dirs {
        let dir = dir.as_str().ok_or("Invalid mod directory")?;
        safe_name(dir)?;
        if !parents.contains(&WindowsPath(dir.to_owned())) {
            return error("Mod journal directory is outside the target set");
        }
    }
    Ok(())
}

// A symlink is owned only if it still points at the recorded library file.
fn mod_target_hash(root: &Path, target: &Path, e: &Value) -> Result<Option<String>> {
    let Some(meta) = metadata(target)? else {
        return Ok(None);
    };
    if meta.is_dir() {
        return error(format!(
            "Mod target became a directory: {}",
            target.display()
        ));
    }
    if meta.file_attributes() & 0x400 != 0 {
        let source = mod_files_dir(root, string(e, "mod")?).join(string(e, "source")?);
        let link = io(fs::read_link(target))?;
        if windows::compare_paths(&link.to_string_lossy(), &source.to_string_lossy())
            != Ordering::Equal
        {
            return error(format!(
                "Mod target became an unexpected link: {}",
                target.display()
            ));
        }
        return Ok(Some(windows::hash(target).unwrap_or_default()));
    }
    unlinked(target)?;
    Ok(Some(windows::hash(target)?))
}

fn mod_restore_locked(root: &Path) -> Result<()> {
    let path = mod_journal_path(root);
    let scratch = mod_journal_scratch(root);
    let preserve_scratch = || -> Result<()> {
        if metadata(&scratch)?.is_some() {
            let recovered = root.join(STATE).join(format!("recovered-mod-journal-{}.json", stamp()));
            io(windows::move_new(&scratch, &recovered))?;
        }
        Ok(())
    };
    let Some(mut j) = mod_journal(root)? else {
        if mod_backups_dir(root).exists() && io(fs::read_dir(mod_backups_dir(root)))?.next().is_some() {
            return error("Mod journal missing while backups exist; backups were preserved");
        }
        preserve_scratch()?;
        println!("No mod overlay journal");
        return Ok(());
    };
    let status = string(&j, "status")?;
    if status == "restored" {
        preserve_scratch()?;
        println!("Mod overlay already restored");
        return Ok(());
    }
    if !["prepared", "preparing", "active", "restoring"].contains(&status) {
        return error("Invalid mod overlay state");
    }
    if windows::game_running()? {
        return error("Close the game before restoring the mod overlay");
    }
    validate_mod_journal(root, &j)?;
    let mut changes = Vec::new();
    // Preflight the whole transaction before touching any live file. A matching original in
    // place with no backup belongs to an unstarted backup or a completed restore.
    for (i, e) in entries(&j)?.iter().enumerate() {
        let target = root.join(mod_entry_path(e)?);
        let backup = mod_backup_path(root, i);
        let backed_up = metadata(&backup)?.is_some();
        let before = e["before"].as_str();
        if status == "prepared" && before.is_none() && !backed_up {
            continue;
        }
        let current = mod_target_hash(root, &target, e)?;
        if backed_up {
            if digest(&backup)?.as_str() != before || before.is_none() {
                return error(format!(
                    "Unexpected or corrupt mod backup {i}; originals were left in place"
                ));
            }
        } else if let Some(before) = before {
            if current.as_deref() != Some(before)
                || io(fs::symlink_metadata(&target))?.file_attributes() & 0x400 != 0
            {
                return error(format!(
                    "Missing mod backup {i}; originals were left in place"
                ));
            }
            continue;
        }
        changes.push((
            i,
            target,
            backup,
            current,
            string(e, "after")?.to_owned(),
            backed_up,
        ));
    }

    preserve_scratch()?;
    j["status"] = json!("restoring");
    save(&path, &j)?;
    for (i, target, backup, current, after, backed_up) in changes {
        if let Some(current) = current {
            let meta = io(fs::symlink_metadata(&target))?;
            if meta.file_attributes() & 0x400 != 0 || current == after {
                // Copied overlay files are writable; original permissions stay with the backup.
                io(fs::remove_file(&target))?;
            } else {
                let recovered = root
                    .join(STATE)
                    .join(format!("recovered-mod-{}-{i}.bin", stamp()));
                io(windows::move_new(&target, &recovered))?;
                eprintln!(
                    "warning: changed mod target preserved at {}",
                    recovered.display()
                );
            }
        }
        if backed_up {
            let before = windows::hash(&backup)?;
            io(windows::move_new(&backup, &target))?;
            if windows::hash(&target)? != before {
                return error("Mod restoration verification failed");
            }
        }
        checkpoint(4000 + i);
    }
    let stage = root.join(STATE).join(MOD_STAGE);
    if metadata(&stage)?.is_some() {
        io(fs::remove_file(stage))?;
    }
    let mut dirs: Vec<_> = j["directories"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(Value::as_str)
        .collect();
    dirs.sort_by_key(|d| std::cmp::Reverse(d.matches('/').count()));
    for dir in dirs {
        let _ = fs::remove_dir(root.join(dir));
    }
    j["status"] = json!("restored");
    save(&path, &j)?;
    println!("Mod overlay removed and original files restored");
    Ok(())
}

fn mod_activate_locked(root: &Path, package: &Value, requested: Option<&[String]>) -> Result<()> {
    if mod_journal_active(root)? {
        return error("A mod overlay is already active; restore/recover it first");
    }
    let ids = match requested {
        Some(ids) => ids.to_vec(),
        None => mod_load_active(root)?,
    };
    if ids.is_empty() {
        return error("No active mods; use mods enable");
    }
    if windows::game_running()? {
        return error("Close the game before activating mods");
    }
    let mut j = mod_plan(root, &ids)?;
    mod_require_base(root, package)?;
    let stage = root.join(STATE).join(MOD_STAGE);
    let backups = mod_backups_dir(root);
    io(fs::create_dir_all(&backups))?;
    if metadata(&stage)?.is_some() || io(fs::read_dir(&backups))?.next().is_some() {
        return error("Previous mod transaction files exist; preserved for recovery");
    }
    println!(
        "Activating {} file(s) from mods {}...",
        entries(&j)?.len(),
        ids.join(", ")
    );
    save(&mod_journal_path(root), &j)?;
    let result = (|| {
        checkpoint(2000);
        for (i, e) in entries(&j)?.iter().enumerate() {
            let target = root.join(mod_entry_path(e)?);
            if digest(&target)? != e["before"] {
                return error("Base file changed during activation");
            }
            if let Some(before) = e["before"].as_str() {
                let backup = mod_backup_path(root, i);
                io(windows::move_new(&target, &backup))?;
                if windows::hash(&backup)? != before {
                    return error("Mod backup verification failed");
                }
            }
            checkpoint(2001 + i);
        }
        j["status"] = json!("preparing");
        save(&mod_journal_path(root), &j)?;
        for (i, e) in entries(&j)?.iter().enumerate() {
            let target = root.join(mod_entry_path(e)?);
            let source = mod_files_dir(root, string(e, "mod")?).join(string(e, "source")?);
            if digest(&source)? != e["after"] {
                return error("Mod source changed during activation");
            }
            if let Some(parent) = target.parent() {
                io(fs::create_dir_all(parent))?;
            }
            if symlink_file(&source, &target).is_err() {
                let mut input = io(fs::File::open(&source))?;
                let mut output = io(OpenOptions::new().write(true).create_new(true).open(&stage))?;
                io(std::io::copy(&mut input, &mut output))?;
                io(output.sync_all())?;
                drop(output);
                io(windows::move_new(&stage, &target))?;
            }
            if windows::hash(&target)? != string(e, "after")? {
                return error("Mod activation hash mismatch");
            }
            checkpoint(3000 + i);
        }
        j["status"] = json!("active");
        save(&mod_journal_path(root), &j)
    })();
    if let Err(e) = result {
        let restore = mod_restore_locked(root);
        return error(format!("Mod activation failed: {e}; rollback: {restore:?}"));
    }
    println!("Activated mods: {}", ids.join(", "));
    Ok(())
}

fn mod_verify(root: &Path, package: &Value) -> Result<()> {
    let Some(j) = mod_journal(root)? else {
        println!("No active mod overlay");
        return Ok(());
    };
    match string(&j, "status")? {
        "restored" => {
            println!("No active mod overlay");
            return Ok(());
        }
        "active" => {}
        _ => return error("Mod overlay interrupted; restore it before verifying"),
    }
    validate_mod_journal(root, &j)?;
    let base = load(&root.join(STATE).join("journal.json"))?;
    validate_journal(root, &base, package)?;
    if base["status"] != "installed" {
        return error("Base installation is not complete");
    }
    verify_backups(root, &base)?;
    let mut overlay = BTreeSet::new();
    let mut displaced = BTreeMap::new();
    for (i, e) in entries(&j)?.iter().enumerate() {
        let relative = mod_entry_path(e)?;
        let target = root.join(relative);
        if mod_target_hash(root, &target, e)?.as_deref() != e["after"].as_str() {
            return error(format!("Active mod target changed: {}", target.display()));
        }
        let source = mod_files_dir(root, string(e, "mod")?).join(string(e, "source")?);
        if digest(&source)? != e["after"] {
            return error(format!("Active mod source changed: {}", source.display()));
        }
        let original = digest(&mod_backup_path(root, i))?;
        if original != e["before"] {
            return error(format!("Missing or corrupt mod backup {i}"));
        }
        let key = relative.to_lowercase();
        let ext = Path::new(&key)
            .extension()
            .and_then(|s| s.to_str())
            .unwrap_or_default();
        if catalog_file(&key, ext) {
            if let Some(hash) = original.as_str() {
                displaced.insert(key, hash.to_owned());
            }
        }
        overlay.insert(WindowsPath(relative.to_owned()));
    }
    let mut inventory = scan(root, &overlay, Progress::default())?;
    inventory.extend(displaced);
    check_base_inventory(&base, package, inventory)?;
    println!(
        "Verified active overlay and base: {} target(s)",
        entries(&j)?.len()
    );
    Ok(())
}

fn parse_mod_list(value: &str) -> Result<Vec<String>> {
    let mut ids = Vec::new();
    for id in value.split(',').map(str::trim).filter(|v| !v.is_empty()) {
        if !mod_valid_id(id) {
            return error("Invalid mod id");
        }
        if ids.iter().any(|v| v == id) {
            return error("Duplicate mod id");
        }
        ids.push(id.to_owned());
    }
    if ids.is_empty() {
        return error("Empty mod list");
    }
    Ok(ids)
}
fn package_dir(options: &BTreeMap<String, String>) -> Result<PathBuf> {
    let exe = io(std::env::current_exe())?;
    let default = exe.parent().ok_or("No executable directory")?;
    Ok(options
        .get("--package")
        .map(PathBuf::from)
        .unwrap_or_else(|| default.to_path_buf()))
}

fn run_mods(args: &[String]) -> Result<()> {
    let action = args
        .get(2)
        .ok_or("Use: mods <list|inspect|add|enable|disable|remove|activate|restore|verify>")?;
    let mut options = BTreeMap::new();
    let mut i = 3;
    while i < args.len() {
        if !["--game-dir", "--source", "--id", "--mod", "--package"].contains(&args[i].as_str())
            || i + 1 >= args.len()
        {
            return error("Invalid mod arguments");
        }
        if options
            .insert(args[i].clone(), args[i + 1].clone())
            .is_some()
        {
            return error("Duplicate option");
        }
        i += 2;
    }
    if action == "inspect" {
        return mod_inspect(Path::new(
            options.get("--source").ok_or("--source required")?,
        ));
    }
    let root = target(Path::new(
        options.get("--game-dir").ok_or("--game-dir required")?,
    ))?;
    let state = root.join(STATE);
    if !state.exists() {
        if action == "list" {
            println!("No mod library; install the base first");
            return Ok(());
        }
        return error("Install the base alpha first");
    }
    unlinked(&state)?;
    unlinked_tree(&state)?;
    let _lock = io(windows::lock(&state.join("lock")))?;
    match action.as_str() {
        "list" => mod_list(&root),
        "add" => mod_add(
            &root,
            Path::new(options.get("--source").ok_or("--source required")?),
            options.get("--id").map(String::as_str),
        ),
        "enable" => {
            let ids = parse_mod_list(options.get("--mod").ok_or("--mod required")?)?;
            mod_set_active(&root, &ids)
        }
        "disable" => mod_set_active(&root, &[]),
        "remove" => mod_remove(&root, options.get("--mod").ok_or("--mod required")?),
        "activate" => {
            let ids = options
                .get("--mod")
                .map(|v| parse_mod_list(v))
                .transpose()?;
            mod_activate_locked(&root, &package(&package_dir(&options)?)?, ids.as_deref())
        }
        "restore" => mod_restore_locked(&root),
        "verify" => mod_verify(&root, &package(&package_dir(&options)?)?),
        _ => error("Use: mods <list|inspect|add|enable|disable|remove|activate|restore|verify>"),
    }
}
fn play_mods(root: &Path, m: &Value, ids: Vec<String>) -> Result<()> {
    if ids.is_empty() {
        return error("No active mods");
    }
    mod_activate_locked(root, m, Some(&ids))?;
    let mut c = Command::new(root.join("Generals.exe"));
    c.current_dir(root)
        .args(["-win", "-xres", "1920", "-yres", "1080"]);
    for (k, _) in std::env::vars_os() {
        if k.to_string_lossy().to_uppercase().starts_with("ZH_") {
            c.env_remove(k);
        }
    }
    c.env("ZH_EXPERIMENTAL_SINGLEPLAYER", "0");
    let spawn = c.spawn();
    let mut child = match spawn {
        Ok(child) => child,
        Err(e) => {
            let restore = mod_restore_locked(root);
            return error(format!(
                "Mod launch failed: {e}; overlay restore: {restore:?}"
            ));
        }
    };
    let borderless = windows::borderless(child.id());
    if let Err(e) = borderless {
        let _ = child.kill();
        let _ = child.wait();
        let restore = mod_restore_locked(root);
        return error(format!("{e}; overlay restore: {restore:?}"));
    }
    println!(
        "Started singleplayer alpha with mods {}; keep this window open until the game exits",
        ids.join(", ")
    );
    let status = child.wait();
    let restore = mod_restore_locked(root);
    let status =
        status.map_err(|e| format!("Game wait failed: {e}; overlay restore: {restore:?}"))?;
    restore?;
    if !status.success() {
        return error(format!("Game exited with {status}; overlay removed"));
    }
    let j = load(&root.join(STATE).join("journal.json"))?;
    installed(root, &j, m, Progress::default())?;
    println!("Game exited; mod overlay removed and base verified");
    Ok(())
}

fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() == 2 && ["--help", "--version"].contains(&args[1].as_str()) {
        println!("Zero Hour Patcher {VERSION} (singleplayer alpha)\nUsage: zh-patcher <inspect|install|verify|uninstall|recover|play|mods> --game-dir <directory> [--package <directory>] [--mod id[,id]]\nMods: zh-patcher mods <list|inspect|add|enable|disable|remove|activate|restore|verify> --game-dir <directory> [--source <folder|archive|.big>] [--id <id>] [--mod <id[,id]>]\nInstall inspects first and records originals. Install and uninstall accept --progress for status and --recover-interrupted for automatic recovery. Unknown builds/mods refused. No elevation requested.\nMods are separate; activation links/copies data files into the game folder and restores originals after the game exits.\nArchive inspection/extraction supports .zip/.7z/.rar through the system tar; otherwise extract manually.\nUninstall/recover preserve changed files and retain backups. Multiplayer is uncertified.\nPlay uses 1920x1080 borderless and clears inherited ZH_ test settings.");
        return Ok(());
    }
    if args.len() >= 3 && args[1] == "mods" {
        return run_mods(&args);
    }
    if args.len() < 4 {
        return error("Use --help for usage");
    }
    let action = &args[1];
    if ![
        "inspect",
        "install",
        "verify",
        "uninstall",
        "recover",
        "play",
    ]
    .contains(&action.as_str())
    {
        return error("Unknown action");
    }
    let mut options = BTreeMap::new();
    let mut recover_interrupted = false;
    let mut progress = Progress::default();
    let mut i = 2;
    while i < args.len() {
        if args[i] == "--recover-interrupted" {
            if recover_interrupted || !matches!(action.as_str(), "install" | "uninstall") {
                return error("--recover-interrupted is accepted once with install or uninstall");
            }
            recover_interrupted = true;
            i += 1;
            continue;
        }
        if args[i] == "--progress" {
            if progress.0 || !matches!(action.as_str(), "install" | "uninstall") {
                return error("--progress is accepted once with install or uninstall");
            }
            progress = Progress(true);
            i += 1;
            continue;
        }
        if !["--game-dir", "--package", "--mod"].contains(&args[i].as_str()) || i + 1 >= args.len()
        {
            return error("Invalid arguments");
        }
        if options
            .insert(args[i].clone(), args[i + 1].clone())
            .is_some()
        {
            return error("Duplicate option");
        };
        i += 2;
    }
    progress.show(format_args!("Checking the package and selected folder..."));
    let root = target(Path::new(
        options.get("--game-dir").ok_or("--game-dir required")?,
    ))?;
    let package_dir = package_dir(&options)?;
    let m = package(&package_dir)?;
    let state = root.join(STATE);
    let existing_lock = if metadata(&state)?.is_some() {
        unlinked_tree(&state)?;
        Some(io(windows::lock(&state.join("lock")))?)
    } else {
        None
    };
    let overlay_active = mod_journal_active(&root)?;
    if overlay_active {
        match action.as_str() {
            "inspect" | "verify" => return mod_verify(&root, &m),
            "recover" => {
                mod_restore_locked(&root)?;
                let base = state.join("journal.json");
                if base.exists() && load(&base)?["status"] == "installed" {
                    mod_require_base(&root, &m)?;
                    println!("Mod overlay recovered; base installation remains installed");
                    return Ok(());
                }
            }
            "install" | "uninstall" if recover_interrupted => {
                progress.show(format_args!("Restoring the previous mod overlay..."));
                mod_restore_locked(&root)?;
            }
            _ => return error(
                "Restore the active mod overlay before changing or launching the base installation",
            ),
        }
    }
    if action == "play" {
        let ids = match options.get("--mod") {
            Some(value) => parse_mod_list(value)?,
            None => mod_load_active(&root)?,
        };
        if !ids.is_empty() {
            return play_mods(&root, &m, ids);
        }
    }
    if action == "inspect" {
        let journal = root.join(STATE).join("journal.json");
        if journal.exists() {
            unlinked(&root.join(STATE))?;
            unlinked(&journal)?;
            let j = load(&journal)?;
            validate_journal(&root, &j, &m)?;
            println!(
                "Recorded snapshot: {}\nStatus: {}",
                string(&j, "profile")?,
                string(&j, "status")?
            );
            return Ok(());
        }
        let p = identify(&root, &m, progress)?;
        println!(
            "Supported snapshot: {}\nProposed changes: {}",
            string(&p, "id")?,
            plan(&root, &p, &m)?
        );
        return Ok(());
    }
    if windows::game_running()? {
        return error(
            "Close all Generals/Zero Hour and ShockWave launcher processes before continuing",
        );
    }
    if !state.join("journal.json").exists() && action == "install" {
        progress.show(format_args!("Checking game compatibility..."));
        identify(&root, &m, progress)?;
    }
    if !state.exists() {
        if action != "install" {
            if recover_interrupted {
                progress.show(format_args!("Checking the unpatched game files..."));
                identify(&root, &m, progress)?;
                println!("Patch is already uninstalled");
                return Ok(());
            }
            return error("No patcher installation journal found");
        };
        io(fs::create_dir(&state))?;
    }
    let _lock = match existing_lock {
        Some(lock) => lock,
        None => {
            unlinked_tree(&state)?;
            io(windows::lock(&state.join("lock")))?
        }
    };
    let journal = state.join("journal.json");
    if state.join("migration.json").exists() {
        if action != "install" && action != "recover" && !recover_interrupted {
            return error("Interrupted metadata archive: use recover");
        }
        progress.show(format_args!("Checking interrupted setup records..."));
        identify(&root, &m, progress)?;
        finish_migration(&state)?;
    }
    if journal.exists() && action == "install" {
        let previous = load(&journal)?;
        if previous["status"] == "uninstalled" && validate_journal(&root, &previous, &m).is_err() {
            // The current trusted catalog proves game files are original. Never use old paths for restoration.
            progress.show(format_args!("Checking files before archiving the previous setup..."));
            identify(&root, &m, progress)?;
            archive_uninstalled(&state)?;
        }
    }
    if journal.exists() {
        let mut j = load(&journal)?;
        validate_journal(&root, &j, &m)?;
        if action == "recover" || recover_interrupted {
            quarantine_scratch(&root, Some(&j))?
        }
        match action.as_str() {
            "verify" => {
                installed(&root, &j, &m, progress)?;
                println!("Verified {VERSION}: {}", string(&j, "profile")?);
                return Ok(());
            }
            "uninstall" | "recover" => {
                restore(&root, &mut j, &journal, progress)?;
                println!(
                    "Original managed files restored and verified; backups retained in {}",
                    state.display()
                );
                return Ok(());
            }
            "play" => {
                installed(&root, &j, &m, progress)?;
                let mut c = Command::new(root.join("Generals.exe"));
                c.current_dir(&root)
                    .args(["-win", "-xres", "1920", "-yres", "1080"]);
                for (k, _) in std::env::vars_os() {
                    if k.to_string_lossy().to_uppercase().starts_with("ZH_") {
                        c.env_remove(k);
                    }
                }
                c.env("ZH_EXPERIMENTAL_SINGLEPLAYER", "0");
                let child = io(c.spawn())?;
                windows::borderless(child.id())?;
                println!(
                    "Started singleplayer alpha at 1920x1080 borderless; multiplayer unsupported"
                );
                return Ok(());
            }
            "install" => {
                if j["status"] == "installed" {
                    installed(&root, &j, &m, progress)?;
                    println!("Already installed and verified");
                    return Ok(());
                }
                if j["status"] != "uninstalled" {
                    if !recover_interrupted || !matches!(string(&j, "status")?, "prepared" | "removing") {
                        return error("Interrupted operation: use recover before reinstalling");
                    }
                    progress.show(format_args!("Recovering an interrupted patch operation..."));
                    restore(&root, &mut j, &journal, progress)?;
                    println!("Recovered the interrupted patch operation");
                }
            }
            _ => return error("Invalid state"),
        }
    } else if action == "recover" || recover_interrupted {
        progress.show(format_args!("Checking the existing game before resuming setup..."));
        identify(&root, &m, progress)?;
        quarantine_scratch(&root, None)?;
        if action != "install" {
            println!("No patch is installed. Any interrupted preparation files were preserved.");
            return Ok(());
        }
    } else if action != "install" {
        return error("No installation journal found");
    }
    progress.show(format_args!("Confirming the game files before install..."));
    let p = identify(&root, &m, progress)?;
    let mut j = json!({"schema":1,"version":VERSION,"target":root.to_string_lossy(),"profile":p["id"],"status":"prepared","entries":plan(&root,&p,&m)?});
    if p["id"] == COMPATIBLE_PROFILE {
        j["local_inventory"] = p["files"].clone();
    }
    progress.show(format_args!("Saving and checking original backups..."));
    for (i, e) in entries(&j)?.iter().enumerate() {
        if !e["before"].is_null() {
            let backup = backup_path(&root, i);
            if backup.exists() {
                if digest(&backup)? != e["before"] {
                    return error("Existing backup differs; preserved");
                }
            } else {
                let bytes = io(fs::read(root.join(string(e, "path")?)))?;
                atomic_bytes(&backup, &bytes)?;
            }
        }
    }
    verify_backups(&root, &j)?;
    save(&journal, &j)?;
    checkpoint(0);
    let result = (|| {
        let files = entries(&j)?;
        progress.show(format_args!("Applying the patch..."));
        let mut last_report = Instant::now();
        for (i, e) in files.iter().enumerate() {
            let path = root.join(string(e, "path")?);
            if digest(&path)? != e["before"] {
                return error("Target changed during installation");
            }
            if e["after"].is_null() {
                io(fs::remove_file(&path))?
            } else {
                let source = string(e, "source")?;
                let source = if source == "engine.exe" {
                    package_dir.join(source)
                } else {
                    root.join(source)
                };
                if digest(&source)? != e["after"] {
                    return error("Source changed during installation");
                }
                atomic_bytes(&path, &io(fs::read(&source))?)?;
            }
            if digest(&path)? != e["after"] {
                return error("Installed hash mismatch");
            };
            progress.count("Paths checked", i + 1, Some(files.len()), &mut last_report);
            checkpoint(i + 1);
        }
        Ok(())
    })();
    if let Err(e) = result {
        progress.show(format_args!("The patch failed. Restoring the originals..."));
        let recovery = restore(&root, &mut j, &journal, progress);
        return error(format!("Install failed: {e}; rollback: {recovery:?}"));
    }
    j["status"] = json!("installed");
    save(&journal, &j)?;
    installed(&root, &j, &m, progress)?;
    println!("Installed and verified {VERSION}: {}. Singleplayer only. Use uninstall to restore originals.",string(&p,"id")?);
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("ERROR: {e}");
        std::process::exit(1)
    }
}
