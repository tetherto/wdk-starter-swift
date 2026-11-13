# WDK Starter Swift

An iOS example for WDK (Wallet Development Kit) by Tether, demonstrating [WDK Swift Core](https://github.com/tetherto/wdk-core-swift) integration.

For the broader WDK ecosystem, see the [WDK documentation](https://docs.wdk.tether.io/).

## Prerequisites

- **macOS** 14.0+
- **Xcode** 15.3+
- **XcodeGen** on your `PATH`: `brew install xcodegen`
- **Node.js** 22.21+ or 24.9+ with npm, and **git**

## Quick Start

```bash
xcodegen generate
open wdk-starter-swift.xcodeproj
```

Select a simulator, press `Cmd+R`, tap "Create new wallet".

The project can also be built without the Xcode IDE, with `xcodebuild` for a simulator destination.

## What `xcodegen generate` does

Besides the Swift code, the app needs three things that are not in this repository. `xcodegen generate` builds them before it writes the Xcode project:

| Output | Location |
| --- | --- |
| The worklet bundle (the WDK JavaScript code) | `wdk-worklet.mobile.bundle` |
| The native addon frameworks and their XcodeGen list | `addons/` |
| The BareKit runtime, V8 engine | `frameworks/BareKit.xcframework` |

They are built by the JavaScript workspace of [wdk-core-swift](https://github.com/tetherto/wdk-core-swift), at the same revision as the `WdkCore` Swift package named in `project.yml`. For that, `xcodegen generate` keeps a clone of wdk-core-swift in `.wdk-core-swift/`. All of these paths are git-ignored.

The first run needs a network connection. It installs the pinned JavaScript packages and downloads the BareKit release archive (about 400 MB), which is cached in `~/Library/Caches/wdk-core-swift`. Later runs take well under a second and work offline, because nothing is rebuilt while `wdk.config.js` and the wdk-core-swift revision are unchanged.

Good to know:

- Run plain `xcodegen generate` from the repository root. It is the only supported invocation: the project is generated in two passes, and options such as `--spec`, `--project` or `--use-cache` do not reach the second pass.
- `WDK_REFRESH=1 xcodegen generate` rebuilds everything even if nothing changed. It also moves the wdk-core-swift clone to the newest commit of the branch named in `project.yml`; a plain run keeps the commit it already has.
- `git clean -fdx` is the full reset. It removes every generated file, including the Xcode project and the clone, so the next `xcodegen generate` starts from scratch.
- A failed run never writes a new or incomplete Xcode project. Fix the reported error and run it again.

## Networks

`wdk.config.js` lists the wallet packages that go into the worklet bundle. Its network names are the names the app passes to `WdkCore`, see `wdkConfig` in `WdkStarterApp/ContentView.swift`: `sepolia` (Ethereum Sepolia) and `bitcoin` (Bitcoin testnet). To add or change a network, edit both places and run `xcodegen generate` again.

## JavaScript engine

The app runs the worklet on BareKit 2.x with the V8 engine, the default and the combination wdk-core-swift is tested with. JavaScriptCore is available but discouraged because of a known intermittent crash on iOS 26; see the [engine notes of wdk-core-swift](https://github.com/tetherto/wdk-core-swift/blob/main/js/README.md#javascriptcore). To use it, change `--engine v8` to `--engine javascriptcore` in the `preGenCommand` of `project.yml` and run `xcodegen generate` again.

## Using a local wdk-core-swift checkout

To work on the app and on wdk-core-swift together, point the package in `project.yml` at your checkout instead of the repository URL:

```yaml
packages:
  WdkCore:
    path: ../wdk-core-swift
```

`xcodegen generate` then uses that checkout as it is, for the Swift package and for the worklet build, and does not create `.wdk-core-swift/`.

## License

Apache-2.0
