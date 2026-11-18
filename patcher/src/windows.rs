use std::{
    cmp::Ordering,
    ffi::c_void,
    fs::File,
    io::Read,
    os::windows::{ffi::OsStrExt, fs::OpenOptionsExt},
    path::Path,
};
type Handle = *mut c_void;
#[link(name = "bcrypt")]
extern "system" {
    fn BCryptOpenAlgorithmProvider(
        h: *mut Handle,
        id: *const u16,
        implementation: *const u16,
        flags: u32,
    ) -> i32;
    fn BCryptCreateHash(
        a: Handle,
        h: *mut Handle,
        object: *mut u8,
        len: u32,
        secret: *const u8,
        slen: u32,
        flags: u32,
    ) -> i32;
    fn BCryptHashData(h: Handle, data: *const u8, len: u32, flags: u32) -> i32;
    fn BCryptFinishHash(h: Handle, out: *mut u8, len: u32, flags: u32) -> i32;
    fn BCryptDestroyHash(h: Handle) -> i32;
    fn BCryptCloseAlgorithmProvider(h: Handle, flags: u32) -> i32;
}
#[repr(C)]
struct StandardInfo {
    allocation: i64,
    end: i64,
    links: u32,
    delete_pending: u8,
    directory: u8,
}
#[repr(C)]
struct ProcessEntry {
    size: u32,
    usage: u32,
    pid: u32,
    heap: usize,
    module: u32,
    threads: u32,
    parent: u32,
    priority: i32,
    flags: u32,
    name: [u16; 260],
}
#[link(name = "kernel32")]
extern "system" {
    fn CompareStringOrdinal(
        a: *const u16,
        a_len: i32,
        b: *const u16,
        b_len: i32,
        ignore_case: i32,
    ) -> i32;
    fn MoveFileExW(from: *const u16, to: *const u16, flags: u32) -> i32;
    fn GetFileInformationByHandleEx(h: Handle, class: i32, data: *mut c_void, size: u32) -> i32;
    fn CreateToolhelp32Snapshot(flags: u32, pid: u32) -> Handle;
    fn Process32FirstW(h: Handle, p: *mut ProcessEntry) -> i32;
    fn Process32NextW(h: Handle, p: *mut ProcessEntry) -> i32;
    fn CloseHandle(h: Handle) -> i32;
}
pub fn compare_paths(a: &str, b: &str) -> Ordering {
    let a: Vec<_> = a.encode_utf16().collect();
    let b: Vec<_> = b.encode_utf16().collect();
    match unsafe { CompareStringOrdinal(a.as_ptr(), a.len() as i32, b.as_ptr(), b.len() as i32, 1) }
    {
        1 => Ordering::Less,
        2 => Ordering::Equal,
        3 => Ordering::Greater,
        _ => a.cmp(&b),
    }
}
pub fn move_new(from: &Path, to: &Path) -> std::io::Result<()> {
    if unsafe { MoveFileExW(wide(from).as_ptr(), wide(to).as_ptr(), 8) } == 0 {
        Err(std::io::Error::last_os_error())
    } else {
        Ok(())
    }
}
fn wide(p: &Path) -> Vec<u16> {
    p.as_os_str().encode_wide().chain(Some(0)).collect()
}
pub fn replace(from: &Path, to: &Path) -> std::io::Result<()> {
    if unsafe { MoveFileExW(wide(from).as_ptr(), wide(to).as_ptr(), 1 | 8) } == 0 {
        Err(std::io::Error::last_os_error())
    } else {
        Ok(())
    }
}
pub fn lock(path: &Path) -> std::io::Result<File> {
    std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .share_mode(0)
        .open(path)
}
pub fn single_link(path: &Path) -> std::io::Result<bool> {
    use std::os::windows::io::AsRawHandle;
    let file = File::open(path)?;
    let mut info = StandardInfo {
        allocation: 0,
        end: 0,
        links: 0,
        delete_pending: 0,
        directory: 0,
    };
    if unsafe {
        GetFileInformationByHandleEx(
            file.as_raw_handle(),
            1,
            &mut info as *mut _ as Handle,
            std::mem::size_of::<StandardInfo>() as u32,
        )
    } == 0
    {
        return Err(std::io::Error::last_os_error());
    }
    Ok(info.links == 1)
}
pub fn game_running() -> Result<bool, String> {
    unsafe {
        let snap = CreateToolhelp32Snapshot(2, 0);
        if snap as isize == -1 {
            return Err("Cannot enumerate processes".into());
        }
        let mut p: ProcessEntry = std::mem::zeroed();
        p.size = std::mem::size_of::<ProcessEntry>() as u32;
        let mut found = false;
        let mut valid = Process32FirstW(snap, &mut p);
        if valid == 0 {
            CloseHandle(snap);
            return Err("Cannot read process list".into());
        }
        while valid != 0 {
            let end = p.name.iter().position(|v| *v == 0).unwrap_or(260);
            let name = String::from_utf16_lossy(&p.name[..end]).to_lowercase();
            if [
                "generals.exe",
                "generalszh.exe",
                "game.dat",
                "shockwavelauncher.exe",
                "swr.net_shw.exe",
            ]
            .contains(&name.as_str())
            {
                found = true;
                break;
            }
            valid = Process32NextW(snap, &mut p);
        }
        CloseHandle(snap);
        Ok(found)
    }
}
pub fn hash(path: &Path) -> Result<String, String> {
    let mut file = File::open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    unsafe {
        let mut algorithm: Handle = std::ptr::null_mut();
        let mut h: Handle = std::ptr::null_mut();
        let id: Vec<u16> = "SHA256\0".encode_utf16().collect();
        if BCryptOpenAlgorithmProvider(&mut algorithm, id.as_ptr(), std::ptr::null(), 0) < 0 {
            return Err("SHA256 provider failed".into());
        }
        if BCryptCreateHash(
            algorithm,
            &mut h,
            std::ptr::null_mut(),
            0,
            std::ptr::null(),
            0,
            0,
        ) < 0
        {
            BCryptCloseAlgorithmProvider(algorithm, 0);
            return Err("SHA256 initialization failed".into());
        }
        let result = (|| {
            let mut buffer = vec![0u8; 1024 * 1024];
            loop {
                let n = file.read(&mut buffer).map_err(|e| e.to_string())?;
                if n == 0 {
                    break;
                }
                if BCryptHashData(h, buffer.as_ptr(), n as u32, 0) < 0 {
                    return Err("SHA256 read failed".into());
                }
            }
            let mut digest = [0u8; 32];
            if BCryptFinishHash(h, digest.as_mut_ptr(), 32, 0) < 0 {
                return Err("SHA256 finalization failed".into());
            }
            Ok(digest.iter().map(|b| format!("{b:02x}")).collect())
        })();
        BCryptDestroyHash(h);
        BCryptCloseAlgorithmProvider(algorithm, 0);
        result
    }
}

#[link(name = "user32")]
extern "system" {
    fn SetProcessDPIAware() -> i32;
    fn EnumWindows(callback: extern "system" fn(isize, isize) -> i32, data: isize) -> i32;
    fn GetWindowThreadProcessId(window: isize, pid: *mut u32) -> u32;
    fn IsWindowVisible(window: isize) -> i32;
    fn GetClassNameW(window: isize, buffer: *mut u16, len: i32) -> i32;
    fn GetWindowLongPtrW(window: isize, index: i32) -> isize;
    fn SetWindowLongPtrW(window: isize, index: i32, value: isize) -> isize;
    fn SetWindowPos(
        window: isize,
        after: isize,
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        flags: u32,
    ) -> i32;
    fn SetForegroundWindow(window: isize) -> i32;
}
struct Search {
    pid: u32,
    window: isize,
}
extern "system" fn find_window(window: isize, data: isize) -> i32 {
    unsafe {
        let s = &mut *(data as *mut Search);
        let mut pid = 0;
        GetWindowThreadProcessId(window, &mut pid);
        let mut class = [0u16; 64];
        let length = GetClassNameW(window, class.as_mut_ptr(), 64);
        if pid == s.pid
            && IsWindowVisible(window) != 0
            && length > 0
            && String::from_utf16_lossy(&class[..length as usize]) == "Game Window"
        {
            s.window = window;
            return 0;
        }
    }
    1
}
pub fn borderless(pid: u32) -> Result<(), String> {
    unsafe {
        SetProcessDPIAware();
    }
    let mut s = Search { pid, window: 0 };
    for _ in 0..100 {
        unsafe {
            EnumWindows(find_window, &mut s as *mut _ as isize);
        }
        if s.window != 0 {
            unsafe {
                let style = GetWindowLongPtrW(s.window, -16);
                SetWindowLongPtrW(
                    s.window,
                    -16,
                    (style & !(0x00c00000 | 0x00040000 | 0x00080000 | 0x00020000 | 0x00010000))
                        | 0x80000000,
                );
                if SetWindowPos(s.window, 0, 0, 0, 1920, 1080, 0x20 | 0x40) == 0 {
                    return Err("Game started, but borderless positioning failed".into());
                }
                SetForegroundWindow(s.window);
            }
            return Ok(());
        }
        std::thread::sleep(std::time::Duration::from_millis(200));
    }
    Err("Game started, but no visible window appeared within 20 seconds".into())
}
