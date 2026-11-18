// Development-only native-resolution launcher, reusing the shipping borderless implementation.
#[path = "../patcher/src/windows.rs"]
#[allow(dead_code)]
mod windows;
use std::{path::PathBuf,process::Command,time::Duration,io::Write};
fn main(){
    let args:Vec<String>=std::env::args().collect();assert_eq!(args.len(),3,"game directory and CSV required");
    assert!(!windows::game_running().expect("process enumeration failed"),"Close other Generals processes first");
    let root=std::fs::canonicalize(PathBuf::from(&args[1])).expect("game copy missing");
    let mut command=Command::new(root.join("Generals.exe"));
    command.current_dir(&root).args(["-win","-quickstart","-xres","1920","-yres","1080"]);
    for(k,_) in std::env::vars_os(){if k.to_string_lossy().to_uppercase().starts_with("ZH_"){command.env_remove(k);}}
    command.env("ZH_MAP","maps\\barrenbadlands\\barrenbadlands.map").env("ZH_FPS","30").env("ZH_GUARD_FIXTURE_CSV",&args[2]);
    let mut child=command.spawn().expect("fixture launch failed");
    if let Err(e)=windows::borderless(child.id()){let _=child.kill();let _=child.wait();panic!("{e}")}
    println!("Started guard fixture PID {} at native 1920x1080 borderless",child.id());std::io::stdout().flush().unwrap();
    for _ in 0..80 {if let Some(code)=child.try_wait().unwrap(){panic!("fixture exited early: {code}")};std::thread::sleep(Duration::from_secs(1));}
    child.kill().unwrap();let _=child.wait();
}
