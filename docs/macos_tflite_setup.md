# macOS Setup — TFLite Native Library

`tflite_flutter` on macOS requires `libtensorflowlite_c-mac.dylib` to be
manually placed in the app bundle. This is a known limitation of the plugin.

## One-time setup

1. Download the prebuilt dylib:
   - Go to https://github.com/tphakala/tflite_c/releases
   - Download the macOS arm64 build (e.g. `libtensorflowlite_c.2.17.1.dylib`)
   - Or from https://github.com/feranick/TFlite-builds/releases

2. After every `flutter run` or `flutter build macos`, copy it:

```bash
cp ~/Downloads/libtensorflowlite_c.2.17.1.dylib \
  build/macos/Build/Products/Debug/cancer_detection_app.app/Contents/Resources/libtensorflowlite_c-mac.dylib
```

3. Then re-run `flutter run -d macos` (no clean needed).

## Automate it (add to your shell)

Add this function to your `~/.zshrc`:

```bash
run_cancer_app() {
  cd ~/cancer-detection-app
  flutter run -d macos &
  sleep 15
  cp ~/Downloads/libtensorflowlite_c.2.17.1.dylib \
    build/macos/Build/Products/Debug/cancer_detection_app.app/Contents/Resources/libtensorflowlite_c-mac.dylib
}
```

## Better: add a build script to Xcode

Open `macos/Runner.xcworkspace` in Xcode, go to
Runner → Build Phases → + → New Run Script Phase, and add:

```bash
cp "$HOME/Downloads/libtensorflowlite_c.2.17.1.dylib" \
  "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Resources/libtensorflowlite_c-mac.dylib"
```

This runs automatically on every build.
