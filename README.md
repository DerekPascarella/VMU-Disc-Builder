<img src="https://github.com/DerekPascarella/VMU-Disc-Builder/blob/main/logo.png?raw=true">

A utility for compiling a custom CDI containing Dreamcast VMU save files.

It supports VMI/VMS pairs representing either game save data, mini-games, or icons.

## Current Version
VMU Disc Builder is currently at version [1.0](xxxx).

## Changelog
- **Version 1.0 (2024-10-24)**
    - Initial release.
 
## Words of Caution
VMU Disc Builder leverages a custom English-language version of the <a href="https://www.dreamcast-talk.com/forum/viewtopic.php?f=52&t=14611#p151960">Dream Passport Web Browser</a> and as such is constrained to RAM limitations of both the browser software and the Dreamcast console itself. It's not recommended that users build a disc using hundreds or thousands of saves, as it will cause each indexed page to load very slowly.

Instead, it's suggested that users curate a list of only the save files, mini-games, and icons that they wish to use.

## A Note on Malformed VMI Files
During the development of VMU Disc Builder, certain malformed VMI files circulating on the internet were discovered. Oftentimes, these VMI files begin with a single lowercase letter (e.g., v7936.VMI).

If a user sees a "Download failed" message after booting their disc, they must repair the VMI/VMS pair using <a href="https://segaretro.org/VMU_Explorer">VMU Explorer</a>. The process is simple.

1. Launch VMU Explorer.
2. Click "File" -> "New VM".
3. Click "File" -> "Import fil"e.
4. Select the original VMI file.
5. Once imported, right-click the save file and select "Export".
6. Either use the default filename, or give the VMI/VMS pair a custom filename not exceeding eight characters, not including the extension (e.g., 12345678.VMI and 12345678.VMS).
 
## Usage
VMU Disc Builder is designed to be as easy to use as possible.

After downloading the release package, extract the ZIP file to any folder of your choosing. A folder and file structure as follows will be created.

```
.
├── assets
│   ├── ARIALUNI.TTF
│   ├── disc_image.zip
│   ├── html
│   │   ├── 1.html
│   │   ├── 2.html
│   │   ├── 3.html
│   │   └── 4.html
│   └── no_icon.gif
├── output
├── save_files
├── tools
│   ├── cdi4dc.exe
│   └── mkisofs.exe
└── vmu_disc_builder.exe
```

Place VMI/VMS file pairs in the `save_files` folder. Note that nested subfolders is fully supported, and in fact encouraged when dealing with a large collection of saves where duplicate file names may be used.

Once all desired save files have been copied, launch the `vmu_disc_builder.exe` application. It will process all valid VMI/VMS pairs in the `save_files` folder and produce status updates throughout the build process.

<img src="https://github.com/DerekPascarella/VMU-Disc-Builder/blob/main/screenshot_1.png?raw=true">

Once the CDI has been built, it is ready for use either via ODE or burned disc.

<img src="https://github.com/DerekPascarella/VMU-Disc-Builder/blob/main/screenshot_2.png?raw=true">
