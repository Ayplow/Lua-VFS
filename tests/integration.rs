use assert_cmd::prelude::*;
use failure::ResultExt;
use std::io::Write;
// use std::io::Read;
use std::path::Path;
use std::process::Command;
use tempfile::NamedTempFile;

fn test_bundle(path: &Path) -> Result<(), exitfailure::ExitFailure> {
    let mut bundle = NamedTempFile::new()?;
    bundle.write_all(
        &Command::cargo_bin(env!("CARGO_PKG_NAME"))?
            .current_dir(path)
            .arg("--preload")
            .output()?
            .stdout,
    )?;
    // TODO: Improve usability for alternative locations
    // let interpreter = std::env::var("LUA").unwrap_or("lua".into());
    which::which("lua").context("lua interpreter not present in PATH")?;
    // // Re-open it.
    // let mut file2 = bundle.reopen()?;
    // // Read the test data using the second handle.
    // let mut buf = String::new();
    // file2.read_to_string(&mut buf)?;
    // println!("{:?}", &Command::cargo_bin(env!("CARGO_PKG_NAME"))?
    //         .current_dir(path)
    //         .arg("--preload")
    //         .output());
    // println!("Contents of bundle: {}", buf);
    // println!("{:?}", Command::new(&interpreter)
    //         .arg("-e")
    //         .arg("loadfile = nil load = nil io = nil")
    //         .arg(bundle.path())
    //         .output()?);
    
    Ok(assert_eq!(
        Command::new("lua")
            .arg("-e")
            .arg("loadfile = nil load = nil io = nil")
            .arg(bundle.path())
            .output()?
            .stdout,
        Command::new("lua")
            .current_dir(path)
            .arg("init.lua")
            .output()?
            .stdout
    ))
}
#[test]
fn external_txt() -> Result<(), exitfailure::ExitFailure> {
    // TODO: Can we improve the way this folder is located?
    test_bundle(Path::new("tests/external_txt"))
}
