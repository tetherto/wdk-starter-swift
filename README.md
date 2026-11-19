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
- `WDK_REFRESH=1 xcodegen generate` rebuilds everything even if nothing changed. If `project.yml` names a branch instead of a version, it also moves the wdk-core-swift clone to the newest commit of that branch; a plain run keeps the commit it already has.
- `git clean -fdx` is the full reset. It removes every generated file, including the Xcode project and the clone, so the next `xcodegen generate` starts from scratch.
- A failed run never writes a new or incomplete Xcode project. Fix the reported error and run it again.
- To move to another wdk-core-swift release, change `exactVersion` in `project.yml` and run `xcodegen generate` again. The clone switches to that tag and Xcode resolves the same version.

## Networks

`wdk.config.js` lists the wallet packages that go into the worklet bundle. Its network names are the names the app passes to `WdkCore`, see `wdkConfig` in `WdkStarterApp/ContentView.swift`: `sepolia` (Ethereum Sepolia) and `bitcoin` (Bitcoin testnet4). To add or change a network, edit both places and run `xcodegen generate` again.

## Client lifecycle

The app keeps one `WdkCore` client for the whole process, see `WalletViewModel` in `WdkStarterApp/ContentView.swift`.

- **Changing wallet.** "Delete wallet" calls `dispose()` and keeps the client. The next create or import calls `initializeWDK` on that same client. If that `dispose()` fails, delete falls back to the reset below.
- **Resetting a stuck client.** A client is stuck when a call never returns, or when it throws on every call. `resetClient()` then drops it without awaiting anything on it, because its `dispose()` could hang too, and the next action makes a new client. It still sends a `dispose()` to the dropped client, which wipes the old wallet if that client is only slow. If the client is truly stuck, that `dispose()` never runs and the old wallet stays loaded until the app is restarted. "Reset" appears on the loading overlay after 10 seconds, and "Reset WDK client" appears on the welcome screen after a create, import or delete has failed.

Reset is a recovery path, not part of the normal flow. The worklet of the dropped client is never torn down: it stays in memory until the app is restarted, about 35 MB on iOS. Under JavaScriptCore on iOS 26.3.1, a second live worklet has also coincided with crashes.

## JavaScript engine

The app runs the worklet on BareKit 2.x with the V8 engine, the default and the combination wdk-core-swift is tested with. JavaScriptCore is available but discouraged because of a known intermittent crash on iOS 26; see the [engine notes of wdk-core-swift](https://github.com/tetherto/wdk-core-swift/blob/v0.9.0/js/README.md#javascriptcore). To use it, change `--engine v8` to `--engine javascriptcore` in the `preGenCommand` of `project.yml` and run `xcodegen generate` again.

## Known limitations

The app is pinned to wdk-core-swift 0.9.0 and shares its [known limitations](https://github.com/tetherto/wdk-core-swift/blob/v0.9.0/README.md#known-limitations). The one that shapes this app: a `WdkCore` instance is never torn down, which is why the app keeps one client for the whole process, see "Client lifecycle" above.

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
