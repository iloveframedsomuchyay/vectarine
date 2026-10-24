use regex::Regex;
use runtime::graphics::VECTARINE_LOGO_PNG;
use runtime::image::{self, DynamicImage, imageops::FilterType};
use runtime::loader::append_bundle;
use runtime::mlua;
use runtime::projectinfo::ProjectInfo;
use std::fs;
use std::io::{self, Seek, Write};
use std::path::{Path, PathBuf};

use runtime::egui::TextBuffer;
use zip::write::SimpleFileOptions;

use crate::project::geteditorpaths::{
    get_runtime_file_for_linux, get_runtime_file_for_macos, get_runtime_file_for_windows,
    get_runtime_file_paths_for_web,
};

#[derive(Debug, Hash, Eq, PartialEq, Clone, Copy)]
pub enum ExportPlatform {
    Windows,
    Linux,
    MacOS,
    Web,
}

impl ExportPlatform {
    pub fn all() -> impl Iterator<Item = Self> {
        [
            ExportPlatform::Windows,
            ExportPlatform::Linux,
            ExportPlatform::MacOS,
            ExportPlatform::Web,
        ]
        .into_iter()
    }
}

impl std::fmt::Display for ExportPlatform {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ExportPlatform::Windows => write!(f, "Windows"),
            ExportPlatform::Linux => write!(f, "Linux"),
            ExportPlatform::MacOS => write!(f, "macOS"),
            ExportPlatform::Web => write!(f, "Web"),
        }
    }
}

pub fn export_project(
    project_path: &Path,
    project_info: &ProjectInfo,
    obfuscate: bool,
    platform: ExportPlatform,
) -> Result<PathBuf, String> {
    let game_data_folder = project_path
        .parent()
        .expect("Failed to get game data folder");

    let exported_filename = get_export_filename(project_info, platform);
    let output_path = game_data_folder.join(exported_filename);
    if output_path.exists() {
        let _ = fs::remove_file(&output_path);
    }

    let output_file = fs::File::create(&output_path).map_err(|e| e.to_string())?;
    let mut zip = zip::ZipWriter::new(output_file);

    let runtime_path = match platform {
        ExportPlatform::Web => {
            add_web_runtime(&mut zip, project_info)?;
            add_game_data(&mut zip, project_path, obfuscate, "")?;
            zip.finish().map_err(|e| e.to_string())?;
            return Ok(output_path);
        }
        ExportPlatform::Windows => get_runtime_file_for_windows(),
        ExportPlatform::Linux => get_runtime_file_for_linux(),
        ExportPlatform::MacOS => get_runtime_file_for_macos(),
    };
    let Some(runtime_path) = runtime_path else {
        return Err(format!("Failed to locate the runtime for {}", platform));
    };
    let mut runtime = fs::read(&runtime_path).map_err(|e| e.to_string())?;
    let icon = load_icon(game_data_folder, project_info);
    if platform == ExportPlatform::Windows {
        match with_windows_icon(&runtime, icon.clone()) {
            Ok(runtime_with_icon) => runtime = runtime_with_icon,
            Err(e) => println!("Failed to set the icon of the executable: {}", e),
        }
    }

    let name = project_info.get_file_name();
    let executable_options = SimpleFileOptions::default().unix_permissions(0o755);
    match platform {
        ExportPlatform::MacOS => {
            let contents = format!("{name}.app/Contents");
            add_file_content_to_zip(
                &mut zip,
                get_info_plist(&name).as_bytes(),
                &format!("{contents}/Info.plist"),
                SimpleFileOptions::default(),
            )
            .map_err(|e| e.to_string())?;
            add_file_content_to_zip(
                &mut zip,
                &make_icns(&icon).map_err(|e| e.to_string())?,
                &format!("{contents}/Resources/icon.icns"),
                SimpleFileOptions::default(),
            )
            .map_err(|e| e.to_string())?;
            add_file_content_to_zip(
                &mut zip,
                &runtime,
                &format!("{contents}/MacOS/{name}"),
                executable_options,
            )
            .map_err(|e| e.to_string())?;
            add_game_data(
                &mut zip,
                project_path,
                obfuscate,
                &format!("{contents}/Resources/"),
            )?;
        }
        _ => {
            let executable_name = if platform == ExportPlatform::Windows {
                format!("{name}.exe")
            } else {
                name
            };
            if obfuscate {
                append_bundle(&mut runtime, &make_bundle(project_path)?);
            }
            add_file_content_to_zip(&mut zip, &runtime, &executable_name, executable_options)
                .map_err(|e| e.to_string())?;
            if !obfuscate {
                add_game_data(&mut zip, project_path, false, "")?;
            }
        }
    }

    zip.finish().map_err(|e| e.to_string())?;
    Ok(output_path)
}

fn add_web_runtime<W: Write + Seek>(
    zip: &mut zip::ZipWriter<W>,
    project_info: &ProjectInfo,
) -> Result<(), String> {
    let Some((runtime_js_path, runtime_wasm_path, index_html_path)) =
        get_runtime_file_paths_for_web()
    else {
        return Err(
            "Failed to locate runtime files (runtime.js, runtime.wasm, index.html). \
            Make sure they are located next to the executable."
                .into(),
        );
    };

    let index_html_content = fs::read_to_string(&index_html_path).map_err(|e| e.to_string())?;
    let re = Regex::new(r"target/[a-zA-Z0-9\-/]+/runtime.js").map_err(|e| e.to_string())?;
    let index_html_content = re.replace_all(&index_html_content, "runtime.js");
    let index_html_content = index_html_content.replace("Vectarine Web Build", &project_info.title);
    add_file_content_to_zip(
        zip,
        index_html_content.as_bytes(),
        "index.html",
        SimpleFileOptions::default(),
    )
    .map_err(|e| e.to_string())?;

    add_file_to_zip_from_path(zip, &runtime_js_path, "runtime.js", false, false)
        .map_err(|e| e.to_string())?;
    add_file_to_zip_from_path(zip, &runtime_wasm_path, "runtime.wasm", false, false)
        .map_err(|e| e.to_string())
}

fn add_game_data<W: Write + Seek>(
    zip: &mut zip::ZipWriter<W>,
    project_path: &Path,
    obfuscate: bool,
    prefix: &str,
) -> Result<(), String> {
    if obfuscate {
        let bundle = make_bundle(project_path)?;
        add_file_content_to_zip(
            zip,
            &bundle,
            &format!("{prefix}bundle.vecta"),
            SimpleFileOptions::default(),
        )
        .map_err(|e| e.to_string())
    } else {
        for (file_path, zip_path) in get_project_files(project_path) {
            add_file_to_zip_from_path(
                zip,
                &file_path,
                &format!("{prefix}{zip_path}"),
                false,
                false,
            )
            .map_err(|e| e.to_string())?;
        }
        Ok(())
    }
}

fn make_bundle(project_path: &Path) -> Result<Vec<u8>, String> {
    let mut bundle = zip::ZipWriter::new(io::Cursor::new(Vec::new()));
    for (file_path, zip_path) in get_project_files(project_path) {
        if file_path.extension() == Some(std::ffi::OsStr::new("luau")) {
            // Compile into bytecode
            let script_content = fs::read_to_string(&file_path).map_err(|e| e.to_string())?;
            let compiler = mlua::chunk::Compiler::new()
                .set_optimization_level(2)
                .set_debug_level(0)
                .set_type_info_level(1);
            let result = compiler.compile(script_content);
            match result {
                Ok(bytecode) => {
                    add_file_content_to_zip(
                        &mut bundle,
                        &bytecode,
                        &zip_path,
                        SimpleFileOptions::default(),
                    )
                    .map_err(|e| e.to_string())?;
                }
                Err(err) => {
                    println!("Failed to compile {}: {}", file_path.display(), err);
                    add_file_to_zip_from_path(&mut bundle, &file_path, &zip_path, false, false)
                        .map_err(|e| e.to_string())?;
                }
            }
        } else {
            add_file_to_zip_from_path(&mut bundle, &file_path, &zip_path, false, false)
                .map_err(|e| e.to_string())?;
        }
    }
    let bundle = bundle.finish().map_err(|e| e.to_string())?;
    Ok(bundle.into_inner())
}

fn load_icon(game_data_folder: &Path, project_info: &ProjectInfo) -> DynamicImage {
    if !project_info.logo_path.is_empty() {
        let logo_path = game_data_folder.join(&project_info.logo_path);
        match image::open(&logo_path) {
            Ok(logo) => return logo,
            Err(e) => println!(
                "The Vectarine logo is used as icon, as {} could not be opened: {}",
                logo_path.display(),
                e
            ),
        }
    }
    image::load_from_memory(VECTARINE_LOGO_PNG).expect("The Vectarine logo should be valid")
}

fn with_windows_icon(
    runtime: &[u8],
    icon: DynamicImage,
) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let mut image = editpe::Image::parse(runtime)?;
    let mut resources = image.resource_directory().cloned().unwrap_or_default();
    resources.set_main_icon(icon)?;
    image.set_resource_directory(resources)?;
    Ok(image.data().to_vec())
}

fn make_icns(icon: &DynamicImage) -> io::Result<Vec<u8>> {
    let mut family = icns::IconFamily::new();
    for size in [16, 32, 64, 128, 256, 512, 1024] {
        let resized = icon
            .resize_exact(size, size, FilterType::Lanczos3)
            .into_rgba8();
        let image =
            icns::Image::from_data(icns::PixelFormat::RGBA, size, size, resized.into_raw())?;
        family.add_icon(&image)?;
    }
    let mut icns = Vec::new();
    family.write(&mut icns)?;
    Ok(icns)
}

fn get_info_plist(name: &str) -> String {
    let identifier: String = name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect();
    let name = name
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;");
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>{name}</string>
  <key>CFBundleIdentifier</key>
  <string>com.vectarine.{identifier}</string>
  <key>CFBundleName</key>
  <string>{name}</string>
  <key>CFBundleDisplayName</key>
  <string>{name}</string>
  <key>CFBundleIconFile</key>
  <string>icon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
"#
    )
}

fn add_file_to_zip_from_path<W: Write + Seek>(
    zip: &mut zip::ZipWriter<W>,
    file_path: &Path,
    zip_path: &str,
    as_executable: bool,
    as_zstd: bool,
) -> std::io::Result<()> {
    let options = SimpleFileOptions::default();
    let options = if as_executable {
        options.unix_permissions(0o755)
    } else {
        options
    };
    let options = if as_zstd {
        options.compression_method(zip::CompressionMethod::Zstd)
    } else {
        options
    };

    // Note: itch like tar files for web games, maybe this should be an option.
    // zip + zstd are smaller though.
    zip.start_file(zip_path, options)?;
    let mut f = fs::File::open(file_path)?;
    io::copy(&mut f, zip)?;
    Ok(())
}

fn add_file_content_to_zip<W: Write + Seek>(
    zip: &mut zip::ZipWriter<W>,
    content: &[u8],
    zip_path: &str,
    options: SimpleFileOptions,
) -> std::io::Result<()> {
    zip.start_file(zip_path, options)?;
    zip.write_all(content)?;
    Ok(())
}

fn get_export_filename(project_info: &ProjectInfo, platform: ExportPlatform) -> String {
    let project_name = &project_info.title.replace(" ", "_");
    // Example: my_snake_windows.zip
    format!(
        "{}_{}.zip",
        project_name,
        format!("{}", platform).to_lowercase()
    )
}

/// Lists files to be included in the export (recursively)
fn get_files_in_folder(folder_path: &Path, zip_base_path: &str) -> Vec<(PathBuf, String)> {
    let mut files = Vec::new();
    let Ok(entries) = fs::read_dir(folder_path) else {
        return files;
    };
    for entry in entries {
        let Ok(entry) = entry else {
            continue;
        };
        let path = entry.path();
        let file_name = entry.file_name();
        let file_name = file_name.to_string_lossy();
        if file_name.starts_with(".") {
            continue;
        }
        if path.is_file() {
            // Exports are zips. This prevents zip inside zips when exporting multiple times.
            if file_name.ends_with(".zip") {
                continue;
            }
            let zip_path = format!("{}/{}", zip_base_path, file_name);
            files.push((path, zip_path));
        } else if path.is_dir() {
            let new_zip_base_path = format!("{}/{}", zip_base_path, file_name);
            let mut sub_files = get_files_in_folder(&path, &new_zip_base_path);
            files.append(&mut sub_files);
        }
    }
    files
}

fn get_project_files(project_path: &Path) -> impl Iterator<Item = (PathBuf, String)> {
    let game_data_folder = project_path
        .parent()
        .expect("Failed to get game data folder");
    let unexported_folder_names = [
        "release", "private", "test", "output", "build", "debug", "export", "private", "luau-api",
    ];
    // Add game data folder
    // Adding .vecta file as executable as you can run it using a shebang.
    let mut iter = vec![(
        project_path.to_path_buf(),
        "gamedata/game.vecta".to_string(),
    )];

    let Ok(game_data_files) = fs::read_dir(game_data_folder) else {
        return iter.into_iter();
    };
    for entry in game_data_files {
        let Ok(entry) = entry else {
            continue;
        };
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let Some(folder_name) = path.file_name() else {
            unreachable!(
                "When listing files in a directory like {}, only entries which a filename should be returned.",
                game_data_folder.display()
            );
        };
        let folder_name = folder_name.to_string_lossy();
        let folder_name = folder_name.as_str();
        // Don't export hidden files and folder
        if folder_name.starts_with(".") {
            continue;
        }
        if unexported_folder_names.contains(&folder_name) {
            continue;
        }
        let sub_iter = get_files_in_folder(&path, &format!("gamedata/{}", folder_name));
        iter.extend(sub_iter);
    }
    iter.into_iter()
}
