import SwiftUI
import UniformTypeIdentifiers
import WdkCore

// MARK: - Navigation

enum Screen {
    case welcome, create, importWallet, home, send, receive, sign
}

enum Network: String {
    case btc, eth
}

// MARK: - Transaction Model

struct PendingTx: Identifiable {
    let id = UUID()
    let network: Network
    let toAddress: String
    let amount: String
    var status: TxStatus = .pending

    enum TxStatus {
        case pending
        case completed(hash: String)
        case failed(error: String)
    }

    var explorerURL: URL? {
        guard case .completed(let hash) = status else { return nil }
        if network == .eth {
            return URL(string: "https://sepolia.etherscan.io/tx/\(hash)")
        } else {
            return URL(string: "https://blockbook.tbtc-1.zelcore.io/tx/\(hash)")
        }
    }

    var statusLabel: String {
        switch status {
        case .pending: return "Pending..."
        case .completed: return "Confirmed"
        case .failed(let error): return "Failed: \(error)"
        }
    }
}

// MARK: - View Model

@MainActor
class WalletViewModel: ObservableObject {
    @Published var currentScreen: Screen = .welcome
    @Published var seedPhrase: [String] = []
    @Published var importWords: [String] = Array(repeating: "", count: 12)
    @Published var importError: Bool = false
    @Published var toastMessage: String?
    @Published var toastIsSuccess: Bool = false
    @Published var isLoading: Bool = false
    @Published var statusText: String = ""

    // Wallet state
    @Published var ethAddress: String = ""
    @Published var ethBalance: String = "0"
    @Published var btcAddress: String = ""
    @Published var btcBalance: String = "0"
    @Published var isWdkInitialized: Bool = false
    /// True once a create, import or delete has failed: the welcome screen then offers a reset.
    @Published var clientFailed: Bool = false

    // Send
    @Published var sendNetwork: Network = .eth
    @Published var sendAddress: String = ""
    @Published var sendAmount: String = ""
    @Published var pendingTransactions: [PendingTx] = []
    @Published var quotedFeeEth: String?
    @Published var quotedFeeBtc: String?

    // Receive
    @Published var receiveNetwork: Network = .eth

    // Sign
    @Published var signNetwork: Network = .eth {
        didSet { if signNetwork != oldValue { clearSignature() } }
    }
    @Published var signMessage: String = "Login to MyDApp\nTimestamp: 1711036800\nNonce: a3f8c2" {
        didSet { if signMessage != oldValue { clearSignature() } }
    }
    @Published var signResult: String?
    @Published var verifyResult: Bool?

    // WDK internals
    private var client: WdkCore?
    /// Identifies the wallet on screen. Delete and reset start a new session, and a result that
    /// arrives for an older one is dropped, see `isCurrent(_:)`.
    private var session = 0
    private var encryptionKey: String = ""
    private var encryptedSeed: String = ""

    private let wdkConfig = """
    {
      "networks": {
        "sepolia": {
            "blockchain": "sepolia",
            "config": {
            "chainId": 11155111,
              "provider": "https://ethereum-sepolia.publicnode.com"
            }
        },
        "bitcoin": {
          "blockchain": "bitcoin",
          "config": {
          "client": {
            "type": "blockbook-http",
            "clientConfig": {
              "url": "https://blockbook.tbtc-1.zelcore.io/api"
            }
          },
          "network": "testnet"
          }
        }
      }
    }
    """

    // MARK: - Navigation

    func navigate(to screen: Screen) {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentScreen = screen
        }
    }

    // MARK: - Create Wallet

    func createWallet() {
        let session = self.session
        Task {
            isLoading = true
            statusText = "Generating seed phrase..."
            do {
                let wdk = getOrCreateClient()
                let entropy = try await wdk.generateEntropyAndEncrypt(wordCount: 12)
                let mnemonic = try await wdk.getMnemonicFromEntropy(
                    encryptedEntropy: entropy.encryptedEntropyBuffer,
                    encryptionKey: entropy.encryptionKey
                )
                guard isCurrent(session) else { return }
                encryptionKey = entropy.encryptionKey
                encryptedSeed = entropy.encryptedSeedBuffer
                seedPhrase = mnemonic.split(separator: " ").map(String.init)
                navigate(to: .create)
                clientFailed = false
                isLoading = false
                statusText = ""
            } catch {
                guard isCurrent(session) else { return }
                clientFailed = true
                isLoading = false
                statusText = ""
                showToast("Error: \(error.localizedDescription)")
            }
        }
    }

    func confirmSeedAndInitialize() {
        let session = self.session
        Task {
            isLoading = true
            statusText = "Initializing wallet..."

            do {
                try await openWallet(with: getOrCreateClient())
            } catch {
                guard isCurrent(session) else { return }
                clientFailed = true
                showToast("WDK init failed: \(error.localizedDescription)")
            }
            guard isCurrent(session) else { return }
            isLoading = false
            statusText = ""
            await fetchBalance()
            fetchFeeQuotes()
        }
    }

    /// Initializes the wallet from `encryptionKey` and `encryptedSeed` and opens Home. When
    /// anything fails it throws and leaves the current screen in place, so the user can retry.
    private func openWallet(with wdk: WdkCore) async throws {
        let session = self.session
        let eth: String, btc: String
        do {
            // The worklet loads the seed before it registers the networks, and does not unload
            // it when a registration fails, so initialization is covered too.
            try await wdk.initializeWDK(
                encryptionKey: encryptionKey,
                encryptedSeed: encryptedSeed,
                config: wdkConfig
            )
            eth = try await wdk.getAddress(network: "sepolia")
            btc = try await wdk.getAddress(network: "bitcoin")
        } catch {
            // Don't leave the seed loaded in the worklet while the app shows no wallet.
            try? await wdk.dispose()
            throw error
        }
        guard isCurrent(session) else { return }
        ethAddress = eth
        btcAddress = btc
        isWdkInitialized = true
        clientFailed = false
        // The wallet is open: the app no longer needs the seed words or the keys.
        seedPhrase = []
        importWords = Array(repeating: "", count: 12)
        encryptionKey = ""
        encryptedSeed = ""
        navigate(to: .home)
    }

    /// How long a copied seed phrase stays on the clipboard.
    private static let seedClipboardLifetime: TimeInterval = 60

    /// Copies the seed phrase to the clipboard of this device only, and lets it expire.
    func copySeedPhrase() {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: seedPhrase.joined(separator: " ")]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(Self.seedClipboardLifetime)
            ]
        )
        showToast("Seed phrase copied")
    }

    // MARK: - Import Wallet

    /// Fills the import form from pasted text. Anything but exactly 12 words leaves the form
    /// unchanged and shows the error.
    func pasteImportWords(_ text: String) {
        let words = text.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
        importError = words.count != 12
        if !importError { importWords = words }
    }

    func doImport() {
        let words = importWords.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let filled = words.filter { !$0.isEmpty }
        if filled.count < 12 {
            importError = true
            return
        }
        importError = false

        let mnemonic = words.joined(separator: " ")
        let session = self.session
        Task {
            isLoading = true
            statusText = "Importing wallet..."

            do {
                let wdk = getOrCreateClient()
                let result = try await wdk.getSeedAndEntropyFromMnemonic(mnemonic: mnemonic)
                guard isCurrent(session) else { return }
                encryptionKey = result.encryptionKey
                encryptedSeed = result.encryptedSeedBuffer
                try await openWallet(with: wdk)
            } catch {
                guard isCurrent(session) else { return }
                clientFailed = true
                showToast("Import failed: \(error.localizedDescription)")
            }
            guard isCurrent(session) else { return }
            isLoading = false
            statusText = ""
            await fetchBalance()
            fetchFeeQuotes()
        }
    }

    // MARK: - Balance

    private var isRefreshingBalance = false

    func fetchBalance() async {
        guard isWdkInitialized, let wdk = client, !isRefreshingBalance else { return }
        let session = self.session
        isRefreshingBalance = true
        defer { if isCurrent(session) { isRefreshingBalance = false } }

        do {
            let ethBal = try await wdk.getBalance(network: "sepolia")
            guard isCurrent(session) else { return }
            ethBalance = ethBal
        } catch {
            print("ETH balance fetch failed: \(error)")
        }
        do {
            let btcBal = try await wdk.getBalance(network: "bitcoin")
            guard isCurrent(session) else { return }
            btcBalance = btcBal
        } catch {
            print("BTC balance fetch failed: \(error)")
        }
    }

    func refreshBalance() {
        Task {
            await fetchBalance()
        }
    }

    // MARK: - Fee Quotes

    func fetchFeeQuotes() {
        guard isWdkInitialized, let wdk = client else { return }
        let session = self.session
        let zeroPadAddress = "0x0000000000000000000000000000000000000000"
        let btcAddr = btcAddress.isEmpty ? "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx" : btcAddress

        Task {
            do {
                let ethArgs = try JSONArguments.transaction(to: zeroPadAddress, value: "1000")
                let ethResult = try await wdk.callMethod(
                    methodName: "quoteSendTransaction",
                    network: "sepolia",
                    accountIndex: 0,
                    args: ethArgs,
                    options: nil
                )
                guard isCurrent(session) else { return }
                if let dict = ethResult as? [String: Any], let fee = dict["fee"] {
                    quotedFeeEth = "\(fee)"
                } else {
                    quotedFeeEth = "\(ethResult)"
                }
            } catch {
                print("ETH fee quote failed: \(error)")
            }
        }

        Task {
            do {
                let btcArgs = try JSONArguments.transaction(to: btcAddr, value: "1000", confirmationTarget: 1)
                let btcResult = try await wdk.callMethod(
                    methodName: "quoteSendTransaction",
                    network: "bitcoin",
                    accountIndex: 0,
                    args: btcArgs,
                    options: nil
                )
                guard isCurrent(session) else { return }
                if let dict = btcResult as? [String: Any], let fee = dict["fee"] {
                    quotedFeeBtc = "\(fee)"
                } else {
                    quotedFeeBtc = "\(btcResult)"
                }
            } catch {
                print("BTC fee quote failed: \(error)")
            }
        }
    }

    // MARK: - Send

    private func toSmallestUnit(_ amount: String, decimals: Int) -> String? {
        guard let decimal = Decimal(string: amount) else { return nil }
        var multiplier = Decimal(1)
        for _ in 0..<decimals { multiplier *= 10 }
        let result = decimal * multiplier
        return NSDecimalNumber(decimal: result).stringValue
    }

    private func extractTxHash(from result: Any) -> String {
        if let dict = result as? [String: Any], let hash = dict["hash"] as? String {
            return hash
        }
        let str = "\(result)"
        if str.hasPrefix("0x") { return str }
        if let data = str.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hash = json["hash"] as? String {
            return hash
        }
        return str
    }

    func doSend() {
        let address = sendAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = sendAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !amount.isEmpty else {
            showToast("Please fill in address and amount")
            return
        }
        guard isWdkInitialized, let wdk = client else {
            showToast("Wallet not initialized")
            return
        }

        let decimals = sendNetwork == .eth ? 18 : 8
        guard let valueInSmallestUnit = toSmallestUnit(amount, decimals: decimals) else {
            showToast("Invalid amount")
            return
        }

        let networkRpc = sendNetwork == .eth ? "sepolia" : "bitcoin"
        let session = self.session
        let tx = PendingTx(network: sendNetwork, toAddress: address, amount: amount)
        let txId = tx.id
        pendingTransactions.append(tx)

        sendAddress = ""
        sendAmount = ""
        showToast("Transaction submitted", success: true)

        Task {
            do {
                let argsJson = try JSONArguments.transaction(to: address, value: valueInSmallestUnit)
                let result = try await wdk.callMethod(
                    methodName: "sendTransaction",
                    network: networkRpc,
                    accountIndex: 0,
                    args: argsJson,
                    options: nil
                )
                // The transaction was sent either way: only its result is dropped with the old wallet.
                guard isCurrent(session) else { return }
                let hash = extractTxHash(from: result)
                updateTx(id: txId, status: .completed(hash: hash))
                showToast("Transaction confirmed!", success: true)
                await fetchBalance()
            } catch {
                guard isCurrent(session) else { return }
                updateTx(id: txId, status: .failed(error: error.localizedDescription))
                showToast("Send failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateTx(id: UUID, status: PendingTx.TxStatus) {
        if let index = pendingTransactions.firstIndex(where: { $0.id == id }) {
            pendingTransactions[index].status = status
        }
    }

    func clearCompletedTransactions() {
        pendingTransactions.removeAll { tx in
            if case .completed = tx.status { return true }
            if case .failed = tx.status { return true }
            return false
        }
    }

    // MARK: - Sign

    func doSign() {
        let message = signMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard isWdkInitialized, let wdk = client else {
            showToast("Wallet not initialized")
            return
        }
        verifyResult = nil

        let network = signNetwork == .eth ? "sepolia" : "bitcoin"
        let session = self.session
        Task {
            isLoading = true
            statusText = "Signing message..."
            do {
                let result = try await wdk.callMethod(
                    methodName: "sign",
                    network: network,
                    accountIndex: 0,
                    args: try JSONArguments.encode(message),
                    options: nil
                )
                guard isCurrent(session) else { return }
                // The message or network changed while signing, so this signature is for the old ones.
                guard signMessage.trimmingCharacters(in: .whitespacesAndNewlines) == message,
                      (signNetwork == .eth ? "sepolia" : "bitcoin") == network else {
                    isLoading = false
                    statusText = ""
                    return
                }
                signResult = "\(result)"
                navigate(to: .sign)
                isLoading = false
                statusText = ""
                showToast("Message signed successfully", success: true)
            } catch {
                guard isCurrent(session) else { return }
                isLoading = false
                statusText = ""
                showToast("Sign failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Verify

    func doVerify() {
        guard let signature = signResult else { return }
        let message = signMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard isWdkInitialized, let wdk = client else {
            showToast("Wallet not initialized")
            return
        }

        let network = signNetwork == .eth ? "sepolia" : "bitcoin"
        let session = self.session
        Task {
            isLoading = true
            statusText = "Verifying signature..."
            do {
                let argsJson = try JSONArguments.encode([message, signature])
                let result = try await wdk.callMethod(
                    methodName: "verify",
                    network: network,
                    accountIndex: 0,
                    args: argsJson,
                    options: nil
                )
                guard isCurrent(session) else { return }
                if let valid = result as? Bool {
                    verifyResult = valid
                } else {
                    verifyResult = "\(result)" == "true" || "\(result)" == "1"
                }
                isLoading = false
                statusText = ""
                showToast(verifyResult == true ? "Signature is valid" : "Signature is invalid",
                          success: verifyResult == true)
            } catch {
                guard isCurrent(session) else { return }
                verifyResult = false
                isLoading = false
                statusText = ""
                showToast("Verify failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Delete Wallet

    func deleteWallet() {
        let session = self.session
        Task {
            // The client is kept: one WdkCore per process, reused by the next create or import.
            if let wdk = client {
                isLoading = true
                statusText = "Deleting wallet..."
                do {
                    try await wdk.dispose()
                    if isCurrent(session) { clientFailed = false }
                } catch {
                    // A client that cannot dispose may still hold the wallet: drop it, as a reset does.
                    if isCurrent(session) { resetClient() }
                    return
                }
                // resetClient() already cleared everything while dispose() was pending.
                guard isCurrent(session) else { return }
                isLoading = false
                statusText = ""
            }
            clearWalletState()
            navigate(to: .welcome)
            showToast("Wallet deleted", success: false)
        }
    }

    // MARK: - Reset Client

    /// Recovery for a stuck client: a call that never returns, or a client that throws on every
    /// call. Nothing is awaited on the old client, because its `dispose()` could hang too. Its
    /// worklet stays in memory until the app restarts, so the normal flow never calls this.
    func resetClient() {
        if let old = client {
            // Not awaited: wipes the old wallet if the client is only slow.
            Task { try? await old.dispose() }
        }
        client = nil
        clientFailed = false
        clearWalletState()
        isLoading = false
        statusText = ""
        navigate(to: .welcome)
        showToast("WDK client reset")
    }

    // MARK: - Helpers

    /// False once a delete or reset has replaced the wallet that was on screen when `session` was
    /// read. Every async call checks this before it writes its result.
    private func isCurrent(_ session: Int) -> Bool {
        session == self.session
    }

    /// A signature and its verification are only valid for the message and network they were made with.
    private func clearSignature() {
        signResult = nil
        verifyResult = nil
    }

    private func clearWalletState() {
        session += 1
        isRefreshingBalance = false
        isWdkInitialized = false
        encryptionKey = ""
        encryptedSeed = ""
        ethAddress = ""
        ethBalance = "0"
        btcAddress = ""
        btcBalance = "0"
        seedPhrase = []
        importWords = Array(repeating: "", count: 12)
        importError = false
        signResult = nil
        pendingTransactions.removeAll()
        quotedFeeEth = nil
        quotedFeeBtc = nil
    }

    func showToast(_ message: String, success: Bool = false) {
        toastMessage = message
        toastIsSuccess = success
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }

    private func getOrCreateClient() -> WdkCore {
        if let existing = client { return existing }
        let wdk = WdkCore()
        client = wdk
        return wdk
    }

    var receiveAddress: String {
        receiveNetwork == .eth ? ethAddress : btcAddress
    }

    var receiveLabel: String {
        receiveNetwork == .eth ? "Your Ethereum Sepolia address" : "Your Bitcoin Testnet address"
    }

    var sendFee: String {
        if sendNetwork == .eth {
            guard let feeWei = quotedFeeEth, let wei = Decimal(string: feeWei) else {
                return "Estimating..."
            }
            let eth = wei / 1_000_000_000_000_000_000
            return "~\(NSDecimalNumber(decimal: eth)) ETH"
        } else {
            guard let feeSats = quotedFeeBtc, let sats = Decimal(string: feeSats) else {
                return "Estimating..."
            }
            let btc = sats / 100_000_000
            return "~\(NSDecimalNumber(decimal: btc)) BTC"
        }
    }

    var sendNetworkLabel: String {
        sendNetwork == .eth ? "Ethereum Sepolia" : "Bitcoin Testnet"
    }

    var sendTokenLabel: String {
        sendNetwork == .eth ? "ETH" : "BTC"
    }

    var maxSendAmount: String {
        if sendNetwork == .eth {
            guard let balance = Decimal(string: ethBalance),
                  let feeStr = quotedFeeEth, let fee = Decimal(string: feeStr) else { return "0" }
            let feeWithMargin = fee * Decimal(string: "1.2")!
            let maxWei = balance - feeWithMargin
            if maxWei <= 0 { return "0" }
            let maxEth = maxWei / 1_000_000_000_000_000_000
            return "\(NSDecimalNumber(decimal: maxEth))"
        } else {
            guard let balance = Decimal(string: btcBalance),
                  let feeStr = quotedFeeBtc, let fee = Decimal(string: feeStr) else { return "0" }
            let feeWithMargin = fee * Decimal(string: "1.2")!
            let maxSats = balance - feeWithMargin
            if maxSats <= 0 { return "0" }
            let maxBtc = maxSats / 100_000_000
            return "\(NSDecimalNumber(decimal: maxBtc))"
        }
    }

    var formattedEthBalance: String {
        formatBalance(ethBalance, decimals: 18, symbol: "ETH")
    }

    var formattedBtcBalance: String {
        formatBalance(btcBalance, decimals: 8, symbol: "BTC")
    }

    /// Formats a balance given in the smallest unit with four decimals, rounded down so that it
    /// never shows more than is held.
    private func formatBalance(_ smallestUnit: String, decimals: Int, symbol: String) -> String {
        guard let amount = Decimal(string: smallestUnit) else { return "\(smallestUnit) \(symbol)" }
        let style = Decimal.FormatStyle.number
            .precision(.fractionLength(4))
            .rounded(rule: .towardZero)
            .grouping(.never)
            .locale(Locale(identifier: "en_US_POSIX"))
        return "\((amount / pow(10, decimals)).formatted(style)) \(symbol)"
    }
}

// MARK: - Root View

struct ContentView: View {
    /// A call still pending after this long is treated as stuck, and the overlay offers a reset.
    private static let stuckCallDelay: Duration = .seconds(10)

    @StateObject private var vm = WalletViewModel()
    @State private var showReset = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                switch vm.currentScreen {
                case .welcome:      WelcomeScreen(vm: vm)
                case .create:       CreateWalletScreen(vm: vm)
                case .importWallet: ImportWalletScreen(vm: vm)
                case .home:         HomeScreen(vm: vm)
                case .send:         SendScreen(vm: vm)
                case .receive:      ReceiveScreen(vm: vm)
                case .sign:         SignMessageScreen(vm: vm)
                }
            }

            // Loading overlay
            if vm.isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    if !vm.statusText.isEmpty {
                        Text(vm.statusText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    if showReset {
                        Button("Reset") { vm.resetClient() }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .task {
                    try? await Task.sleep(for: Self.stuckCallDelay)
                    showReset = !Task.isCancelled
                }
                .onDisappear { showReset = false }
            }

            // Toast overlay
            if let msg = vm.toastMessage {
                VStack {
                    Text(msg)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(vm.toastIsSuccess ? Color.green : Color.accentColor)
                        )
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 8)
                .animation(.easeOut(duration: 0.3), value: vm.toastMessage != nil)
            }

            // Keeps the seed phrase out of the App Switcher snapshot.
            if scenePhase != .active, vm.currentScreen == .create || vm.currentScreen == .importWallet {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
    }
}

// MARK: - Reusable Components

struct ScreenHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().stroke(Color(.separator), lineWidth: 1))
            }
            Text(title)
                .font(.system(size: 16, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

struct NetworkPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(icon)
                Text(label)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: 1)
            )
            .foregroundColor(isSelected ? .accentColor : .secondary)
        }
    }
}

struct TestnetBadge: View {
    var body: some View {
        Text("Testnet")
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .cornerRadius(6)
    }
}

struct PrimaryButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 12).fill(disabled ? Color.gray : Color.accentColor))
        }
        .disabled(disabled)
    }
}

struct OutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
        }
    }
}

struct SeedWordCell: View {
    let index: Int
    let word: String

    var body: some View {
        HStack(spacing: 6) {
            Text("\(index)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(minWidth: 18, alignment: .leading)
            Text(word)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

struct SeedInputCell: View {
    let index: Int
    @Binding var word: String

    var body: some View {
        HStack(spacing: 6) {
            Text("\(index)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(minWidth: 18, alignment: .leading)
            TextField("word", text: $word)
                .font(.system(size: 13))
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
