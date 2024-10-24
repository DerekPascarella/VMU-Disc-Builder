<img src="https://github.com/DerekPascarella/VMU-Disc-Builder/blob/main/logo.png?raw=true">

A utility for compiling a custom CDI containing Dreamcast VMU save files.

## Current Version
VMU Disc Builder is currently at version [1.0](xxxx).

## Changelog
- **Version 1.0 (2024-10-24)**
    - Initial release.
 
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

Place VMI/VMS file pairs in the `save_files` folder. Note that nested subfolders is fully supported, and in fact encouraged.

Once all desired save files have been copied, launch the `vmu_disc_builder.exe` application. It will process all valid VMI/VMS pairs in the `save_files` folder and produce status updates throughout the build process.

<img src="https://github.com/DerekPascarella/VMU-Disc-Builder/blob/main/screenshot_1.png?raw=true">

Once the CDI has been built, it is ready for use either via ODE or burned disc.

<img src="https://github.com/DerekPascarella/VMU-Disc-Builder/blob/main/screenshot_2.png?raw=true">
