
#[cfg(test)]
mod integration {
    use std::path::Path;
    use std::process::Command;
    use assert_cmd::prelude::*;


    fn test_bundle(path: &str) {
        let output = Command::cargo_bin(env!("CARGO_PKG_NAME")).unwrap()
          .current_dir(format!("tests/{}", path))
          .arg("--preload")
          .output().unwrap();
        assert_eq!(
        String::from_utf8(Command::new("lua")
          .arg("-e").arg("loadfile = nil load = nil io = nil")
          .arg(format!("tests/{}/init.bundle.lua", path))
          .output().unwrap().stdout).unwrap(),
        String::from_utf8(Command::new("lua")
          .current_dir(format!("tests/{}", path))
          .arg("init.lua")
          .output().unwrap().stdout).unwrap());
        std::fs::remove_file(format!("tests/{}/init.bundle.lua", path));
    }
    #[test]
    fn external_txt() {
        test_bundle("external_txt")
    }
}