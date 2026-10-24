use std::path::PathBuf;

use crate::{
    io::{fs::ReadOnlyFileSystem, localfs::LocalFileSystem, zipfs::ZipFileSystem},
    projectinfo::{ProjectInfo, get_project_info},
};

/// Layout of an executable with an appended bundle: `[executable][bundle][bundle size: u64 little endian][APPENDED_BUNDLE_MAGIC]`
pub const APPENDED_BUNDLE_MAGIC: &[u8; 8] = b"VECTAPAK";

pub fn append_bundle(executable: &mut Vec<u8>, bundle: &[u8]) {
    executable.extend_from_slice(bundle);
    executable.extend_from_slice(&(bundle.len() as u64).to_le_bytes());
    executable.extend_from_slice(APPENDED_BUNDLE_MAGIC);
}

#[cfg(not(target_os = "emscripten"))]
fn read_appended_bundle(executable: &std::path::Path) -> Option<Vec<u8>> {
    use std::io::{Read, Seek, SeekFrom};

    let mut file = std::fs::File::open(executable).ok()?;
    let mut trailer = [0u8; 8 + APPENDED_BUNDLE_MAGIC.len()];
    let trailer_len = trailer.len() as u64;
    let file_len = file.metadata().ok()?.len();
    if file_len < trailer_len {
        return None;
    }
    file.seek(SeekFrom::End(-(trailer_len as i64))).ok()?;
    file.read_exact(&mut trailer).ok()?;
    let (bundle_len, magic) = trailer.split_at(8);
    if magic != APPENDED_BUNDLE_MAGIC {
        return None;
    }
    let bundle_len = u64::from_le_bytes(bundle_len.try_into().ok()?);
    let bundle_start = file_len.checked_sub(trailer_len + bundle_len)?;
    file.seek(SeekFrom::Start(bundle_start)).ok()?;
    let mut bundle = vec![0; usize::try_from(bundle_len).ok()?];
    file.read_exact(&mut bundle).ok()?;
    Some(bundle)
}

/// Inside a macOS application, the game is in `Contents/Resources`, but the working directory is not.
#[cfg(target_os = "macos")]
fn enter_app_resources() {
    let Ok(executable) = std::env::current_exe() else {
        return;
    };
    let Some(contents) = executable
        .parent()
        .filter(|dir| dir.ends_with("Contents/MacOS"))
        .and_then(|dir| dir.parent())
    else {
        return;
    };
    let _ = std::env::set_current_dir(contents.join("Resources"));
}

fn load_bundle<F>(data: Vec<u8>, callback: F)
where
    F: FnOnce((PathBuf, ProjectInfo, Box<dyn ReadOnlyFileSystem>)) + 'static,
{
    let fs = ZipFileSystem::new(data);
    let Ok(fs) = fs else {
        // Not a valid zip file, we won't be able to load the game.
        println!("The game bundle is not valid");
        return;
    };
    let meta = fs.read_file_sync("gamedata/game.vecta");
    let Some(meta) = meta else {
        println!("The bundle is missing a game.vecta file inside gamedata.");
        // Missing game manifest.
        return;
    };
    let project_info = get_project_info(String::from_utf8_lossy(&meta).as_ref());
    let Ok(project_info) = project_info else {
        println!("Malformed game.vecta file");
        return;
    };
    callback((
        PathBuf::from("gamedata/game.vecta"),
        project_info,
        Box::new(fs),
    ));
}

/// Analyze the environment to detect the path where the game is located and the file system used to access it.
pub fn loader<F>(callback: F)
where
    F: FnOnce((PathBuf, ProjectInfo, Box<dyn ReadOnlyFileSystem>)) + 'static,
{
    #[cfg(target_os = "macos")]
    enter_app_resources();

    #[cfg(not(target_os = "emscripten"))]
    if let Some(bundle) = std::env::current_exe()
        .ok()
        .and_then(|executable| read_appended_bundle(&executable))
    {
        load_bundle(bundle, callback);
        return;
    }

    LocalFileSystem.read_file(
        "bundle.vecta",
        Box::new(move |result| {
            match result {
                Some(data) => load_bundle(data, callback),
                None => {
                    // Local filesystem.
                    let path = PathBuf::from("gamedata/game.vecta");
                    LocalFileSystem.read_file(
                        "gamedata/game.vecta",
                        Box::new(move |result| {
                            let Some(data) = result else {
                                println!("game.vecta not found in local filesystem");
                                return;
                            };
                            let project_info =
                                get_project_info(String::from_utf8_lossy(&data).as_ref());
                            let Ok(project_info) = project_info else {
                                println!("Malformed game.vecta file");
                                return;
                            };
                            callback((path, project_info, Box::new(LocalFileSystem)));
                        }),
                    );
                }
            }
        }),
    );
}

#[cfg(test)]
mod tests {
    use super::{append_bundle, read_appended_bundle};

    #[test]
    fn appended_bundle_is_read_back() {
        let path = std::env::temp_dir().join("vectarine-appended-bundle-test");
        let mut executable = b"executable content".to_vec();
        append_bundle(&mut executable, b"bundle content");
        std::fs::write(&path, &executable).expect("the test file should be written");

        let bundle = read_appended_bundle(&path);
        let _ = std::fs::remove_file(&path);
        assert_eq!(bundle.as_deref(), Some(&b"bundle content"[..]));
    }

    #[test]
    fn executable_without_bundle_has_none() {
        let path = std::env::temp_dir().join("vectarine-no-bundle-test");
        std::fs::write(&path, b"executable content").expect("the test file should be written");

        let bundle = read_appended_bundle(&path);
        let _ = std::fs::remove_file(&path);
        assert_eq!(bundle, None);
    }
}
