# WDK Starter Swift

A minimal iOS example demonstrating [WDK Swift Core](https://github.com/claudiovb/wdk-swift-core) integration.

## Prerequisites

- **macOS** 14.0+
- **Xcode** 15.0+
- **XcodeGen**: `brew install xcodegen`

No Node.js, npm, or build tooling required.

## Quick Start

### 1. Download Release Artifacts

Download `prebuilds.zip` and `addons.zip` from the [latest release](https://github.com/claudiovb/pear-wrk-wdk-jsonrpc/releases/latest).

### 2. Place Artifacts

```bash
# Unzip prebuilds
unzip prebuilds.zip -d prebuilds-tmp
cp -R prebuilds-tmp/BareKit.xcframework frameworks/
cp prebuilds-tmp/wdk-worklet.mobile.bundle .
rm -rf prebuilds-tmp

# Unzip addons
unzip addons.zip -d addons/
```

### 3. Generate and Run

```bash
xcodegen generate
open wdk-starter-swift.xcodeproj
```

Select a simulator, press `Cmd+R`, tap "Test WDK".

## License

Apache-2.0
