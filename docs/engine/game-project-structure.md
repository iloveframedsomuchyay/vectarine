# Game structure

Projects can have 2 forms:

- The editable form is opened by the editor
- The runtime form is make to be ran by the runtime

You can turn the editable form into the runtime form but not the other way around

## Editable form

This can be either a folder or a ZIP file. It recommend working with a folder, but the editor can open and edit ZIPs.
Zips can be used to quickly share and open projects between developers.
The runtime is also able to run a project in folder or zip for quick testing.

Editable projects have the following file structure:

```
├── game.vecta
├── fonts
├── scripts/
│   └── game.luau
├── textures
└── shaders
```

`game.vecta` is a toml file containing metadata about the game like:

- The name of the game
- The logo to use for the splash screen
- Tags
- A description
- The default window size / fullscreen

## Runtime form

The runtime form is optimized for small size and fast loading: scripts are compiled to Luau bytecode and the game data is packed into a zip, the bundle.

An export is a zip containing:

| Platform | Content                                                       |
| -------- | ------------------------------------------------------------- |
| Windows  | `<title>.exe`, with the bundle appended                       |
| Linux    | `<title>`, with the bundle appended                           |
| macOS    | `<title>.app`, with the bundle in `Contents/Resources`        |
| Web      | `index.html`, `runtime.js`, `runtime.wasm` and `bundle.vecta` |

On Windows and macOS, the icon is the logo of the game, or the Vectarine logo if it has none.

An appended bundle is followed by its size (`u64`, little endian) and the magic string `VECTAPAK`.
Without obfuscation, the bundle is replaced by a `gamedata` folder.

The runtime looks for the game in this order:

1. The bundle appended to its executable
2. `bundle.vecta` in the working directory
3. `gamedata` in the working directory

Inside a macOS application, the working directory is first set to `Contents/Resources`.

On desktop, because plugins need to be stored as file to be loaded as dynamic libraries, `game.exe` will first extract the plugins to a `plugins` folder next to the game if such a folder does not exist.

## Pipeline

Feature ideas

- Custom pipeline plugins
- Interactions between the pipeline and modding support
- Process wav, mp3, etc... into one good format (probably a mix of lossy/lossless?)
- Process all images, tilemaps, etc... into pngs
- Process all xml/json style files (tmx, etc...) into binary blobs
