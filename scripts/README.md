# App Icon Generation Scripts

This directory contains utility scripts to generate the application's icon assets from a source SVG.

## Files

- **`generate_icons.sh`**: The main orchestration script. It handles conversion, resizing, and placing the files into `Assets.xcassets`.
- **`svg2png.swift`**: A Swift helper script used by `generate_icons.sh` to properly render the SVG with a transparent background.

## Usage

To update the app icon:

1.  **Update the Source**: Modify the source SVG file located at:
    `Barista/app-icon.svg`
    *Note: The SVG should define `width="1024"` and `height="1024"`.*

2.  **Run the Generator**: Execute the shell script from the project root:
    ```bash
    ./scripts/generate_icons.sh
    ```

## Logic

1.  **Rasterization**: It uses `svg2png.swift` to render the SVG into a master 1024x1024 PNG with a transparent background.
    *   Unlike `qlmanage`, this approach ensures no white background artifacts.
2.  **Resizing**: It uses `sips` (Apple's Scriptable Image Processing System) to downscale the master PNG into all required sizes (16px to 1024px) for macOS and iOS.
3.  **Placement**: The generated files occupy `Barista/Assets.xcassets/AppIcon.appiconset/`, making them immediately available to Xcode.
