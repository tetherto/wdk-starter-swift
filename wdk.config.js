// Worklet configuration of the starter app.
//
// `xcodegen generate` hands this file to the JavaScript workspace of wdk-core-swift, which
// builds the worklet bundle and the native addons from it (see README.md). There is no
// `output` section on purpose: that workspace places the results in this repository.
//
// The keys under `networks` are the network names the app passes to WdkCore
// (see `wdkConfig` in WdkStarterApp/ContentView.swift). Keep the two in sync.
module.exports = {
  transport: 'jsonrpc',
  networks: {
    sepolia: { package: '@tetherto/wdk-wallet-evm' },
    bitcoin: { package: '@tetherto/wdk-wallet-btc' }
  },
  options: {
    targets: ['ios-arm64', 'ios-arm64-simulator', 'ios-x64-simulator'],
    swiftTarget: 'wdk-starter-swift',
    convertEsmToCjs: true // keep true: harmless on V8, required by any CJS-only engine (JSC, QuickJS)
  }
}
