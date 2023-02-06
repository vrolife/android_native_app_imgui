# Android Native Application with ImGui

# Build
```shell
ANDROID_NDK_HOME=/path/to/android/ndk/25.1.8937393/
cmake --preset dev-arm64 -B build -S .
cmake --build build --target sign_apk_debug
```
