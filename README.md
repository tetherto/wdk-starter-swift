# WDK Starter Swift

A minimal iOS example demonstrating [WDK Swift Core](https://github.com/Tetherto/wdk-core-swift) integration.

## Prerequisites

- **macOS** 14.0+
- **Xcode** 15.0+
- **XcodeGen**: `brew install xcodegen`
- **Node.js** 18+ and npm (only needed to run the WDK Worklet Bundler)

## Quick Start

### 1. Generate the Worklet Bundle and Addons

The worklet bundle and the native addons are produced with the [WDK Worklet Bundler](https://github.com/tetherto/wdk-worklet-bundler):

```bash
npm install -g @tetherto/wdk-worklet-bundler
```

Create a `wdk.config.js` in the repository root:

```js
module.exports = {
  transport: "jsonrpc",
  networks: {
    ethereum: { package: "@tetherto/wdk-wallet-evm" },
    bitcoin: { package: "@tetherto/wdk-wallet-btc" },
  },
  output: {
    bundle: "./wdk-worklet.mobile.bundle",
    addons: { ios: "./addons" },
    addonsYml: "./addons/addons.yml",
  },
  options: {
    platforms: ["ios"],
    swiftTarget: "wdk-starter-swift",
  },
};
```

Generate the bundle and the native addons:

```bash
wdk-worklet-bundler generate --install
```

This writes `wdk-worklet.mobile.bundle` to the repository root and the addon xcframeworks plus `addons.yml` into `addons/`, which is where `project.yml` expects them. See the bundler's [Swift quick start](https://github.com/tetherto/wdk-worklet-bundler#quick-start--swift--kotlin-json-rpc) for the full configuration reference.

### 2. Add BareKit

Download `BareKit.xcframework` from the [bare-kit releases](https://github.com/holepunchto/bare-kit/releases) and place it in `frameworks/`.

### 3. Generate and Run

```bash
xcodegen generate
open wdk-starter-swift.xcodeproj
```

Select a simulator, press `Cmd+R`, tap "Create new wallet".

## License

Apache-2.0
