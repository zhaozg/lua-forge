[![CI](https://github.com/zhaozg/lua-forge/actions/workflows/ci.yaml/badge.svg)](https://github.com/zhaozg/lua-forge/actions/workflows/ci.yaml)

## Build

### Android

1. For armv7

`make Android`

2. For arm64

`make Android64`

### iOS

1. For armv7

`make iOS`

2. For arm64

`make iOS  PLATFORM=OS64`

### OpenHarmony

1. For armeabi

`make OHOS PLATFORM=armeabi-v7a`

2. For arm64

`make OHOS PLATFORM=arm64-v8a`

3. Form x86_64

`make OHOS PLATFORM=x86_64`
