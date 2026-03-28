import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Welcome Screen

struct WelcomeScreen: View {
    @ObservedObject var vm: WalletViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Image("WDKLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .padding(.bottom, 16)

                Text("WDK Wallet")
                    .font(.system(size: 22, weight: .bold))

                Text("Self custodial. Multi chain. Open source.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                TestnetBadge()
                    .padding(.top, 6)
            }
            .padding(.bottom, 40)

            VStack(spacing: 12) {
                PrimaryButton(title: "Create new wallet", disabled: vm.isLoading) {
                    vm.createWallet()
                }
                OutlineButton(title: "Import existing wallet") {
                    vm.importWords = Array(repeating: "", count: 12)
                    vm.importError = false
                    vm.navigate(to: .importWallet)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            Text("Powered by Tether WDK")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.bottom, 28)
        }
        .padding(.horizontal)
    }
}

// MARK: - Create Wallet Screen

struct CreateWalletScreen: View {
    @ObservedObject var vm: WalletViewModel

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Create wallet") {
                vm.navigate(to: .welcome)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Write down these 12 words in order. This is the only way to recover your wallet.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("Never share your seed phrase with anyone")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(vm.seedPhrase.enumerated()), id: \.offset) { index, word in
                    SeedWordCell(index: index + 1, word: word)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 10) {
                Button("Copy to clipboard") {
                    UIPasteboard.general.string = vm.seedPhrase.joined(separator: " ")
                    vm.showToast("Seed phrase copied")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 1)
                )

                PrimaryButton(title: "I have saved my seed phrase", disabled: vm.isLoading) {
                    vm.confirmSeedAndInitialize()
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Import Wallet Screen

struct ImportWalletScreen: View {
    @ObservedObject var vm: WalletViewModel

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Import wallet") {
                vm.navigate(to: .welcome)
            }

            Text("Enter your 12 word seed phrase to restore your wallet.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<12, id: \.self) { index in
                    SeedInputCell(index: index + 1, word: $vm.importWords[index])
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                if vm.importError {
                    Text("Please enter all 12 words to continue.")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                } else {
                    Text("Type each word or paste from clipboard.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Paste") {
                    if let clip = UIPasteboard.general.string {
                        let words = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            .split(separator: " ")
                            .map(String.init)
                        for i in 0..<min(words.count, 12) {
                            vm.importWords[i] = words[i].lowercased()
                        }
                        vm.importError = false
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            Spacer()

            PrimaryButton(title: "Import wallet") {
                vm.doImport()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Home Screen

struct HomeScreen: View {
    @ObservedObject var vm: WalletViewModel
    let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image("WDKLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                Text("WDK Wallet")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(0.3)
                Spacer()
                TestnetBadge()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Balance hero
            VStack(spacing: 8) {
                Text("Balances")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(vm.formattedEthBalance)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-1)
                Text(vm.formattedBtcBalance)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-1)
                VStack(spacing: 2) {
                    if !vm.ethAddress.isEmpty {
                        Text("ETH " + String(vm.ethAddress.prefix(6)) + "..." + String(vm.ethAddress.suffix(4)))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if !vm.btcAddress.isEmpty {
                        Text("BTC " + String(vm.btcAddress.prefix(6)) + "..." + String(vm.btcAddress.suffix(4)))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 24)
            .onTapGesture { vm.refreshBalance() }

            // Action buttons
            HStack(spacing: 12) {
                ActionCard(icon: "arrow.up", label: "Send") {
                    vm.sendAddress = ""
                    vm.sendAmount = ""
                    vm.sendNetwork = .eth
                    vm.fetchFeeQuotes()
                    vm.navigate(to: .send)
                }
                ActionCard(icon: "arrow.down", label: "Receive") {
                    vm.receiveNetwork = .eth
                    vm.navigate(to: .receive)
                }
                ActionCard(icon: "pencil", label: "Sign") {
                    vm.signNetwork = .eth
                    vm.signMessage = "Login to MyDApp\nTimestamp: 1711036800\nNonce: a3f8c2"
                    vm.signResult = nil
                    vm.verifyResult = nil
                    vm.navigate(to: .sign)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Assets list
            VStack(alignment: .leading, spacing: 0) {
                Text("ASSETS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 0) {
                        AssetRow(icon: "bitcoinsign.circle.fill", iconColor: Color(hex: 0xF7931A),
                                 name: "Bitcoin", network: "BTC Testnet",
                                 amount: vm.formattedBtcBalance, usd: "$0.00")
                        AssetRow(icon: "diamond.fill", iconColor: Color(hex: 0x627EEA),
                                 name: "Ethereum", network: "Sepolia",
                                 amount: vm.formattedEthBalance, usd: "$0.00")
                        AssetRow(icon: "dollarsign.circle.fill", iconColor: Color(hex: 0x26A17B),
                                 name: "Tether USD", network: "ERC20 Sepolia",
                                 amount: "0.00 USDT", usd: "$0.00")
                        AssetRow(icon: "circle.fill", iconColor: Color(hex: 0xC9A033),
                                 name: "Tether Gold", network: "ERC20 Sepolia",
                                 amount: "0.0000 XAUT", usd: "$0.00",
                                 customIcon: "Au")
                    }
                }
            }
            .padding(.top, 4)

            Spacer()

            Button(action: { vm.deleteWallet() }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Delete wallet")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.bottom, 12)

            // Tab bar
            HStack {
                Spacer()
                VStack(spacing: 3) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 14))
                        .frame(width: 22, height: 22)
                        .foregroundColor(.accentColor)
                    Text("Wallet")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) { Divider() }
        }
        .onAppear { vm.refreshBalance() }
        .onReceive(refreshTimer) { _ in vm.refreshBalance() }
    }
}

struct ActionCard: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
    }
}

struct AssetRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let network: String
    let amount: String
    let usd: String
    var customIcon: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconColor).frame(width: 42, height: 42)
                if let custom = customIcon {
                    Text(custom)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .semibold))
                Text(network).font(.system(size: 12)).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amount).font(.system(size: 14, weight: .semibold))
                Text(usd).font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 74)
        }
    }
}

// MARK: - Send Screen

struct SendScreen: View {
    @ObservedObject var vm: WalletViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Send") {
                vm.clearCompletedTransactions()
                vm.navigate(to: .home)
            }

            ScrollView {
                VStack(spacing: 0) {
                    Text("Select network and enter details.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    // Network pills
                    HStack(spacing: 8) {
                        NetworkPill(label: "Sepolia", icon: "\u{039E}", isSelected: vm.sendNetwork == .eth) {
                            vm.sendNetwork = .eth
                        }
                        NetworkPill(label: "BTC Testnet", icon: "\u{20BF}", isSelected: vm.sendNetwork == .btc) {
                            vm.sendNetwork = .btc
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Address field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recipient address")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("Enter wallet address...", text: $vm.sendAddress)
                            .font(.system(size: 14))
                            .padding(13)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                    // Amount input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $vm.sendAmount)
                            .font(.system(size: 28, weight: .bold))
                            .keyboardType(.decimalPad)
                        HStack {
                            Text(vm.sendTokenLabel)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                    Button("Max") {
                        vm.sendAmount = vm.maxSendAmount
                    }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.accentColor)
                        }
                        .padding(.top, 2)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Fee info
                    VStack(spacing: 0) {
                        HStack {
                            Text("Estimated fee").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer()
                            Text(vm.sendFee).font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.vertical, 8)
                        Divider()
                        HStack {
                            Text("Network").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer()
                            Text(vm.sendNetworkLabel).font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Send button
                    PrimaryButton(title: "Send") {
                        vm.doSend()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Pending / completed transactions
                    if !vm.pendingTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TRANSACTIONS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)

                            ForEach(vm.pendingTransactions.reversed()) { tx in
                                TxCard(tx: tx, vm: vm)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }

                    Spacer().frame(height: 24)
                }
            }
        }
    }
}

struct TxCard: View {
    let tx: PendingTx
    @ObservedObject var vm: WalletViewModel

    private var isPending: Bool {
        if case .pending = tx.status { return true }
        return false
    }

    private var txHash: String? {
        if case .completed(let hash) = tx.status { return hash }
        return nil
    }

    private var cardColor: Color {
        switch tx.status {
        case .pending: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusRow
            detailRow
            if let hash = txHash {
                hashSection(hash: hash)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor.opacity(0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var statusRow: some View {
        HStack {
            if isPending {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: txHash != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(cardColor)
                    .font(.system(size: 14))
            }
            Text(tx.statusLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(cardColor)
            Spacer()
            Text(tx.network == .eth ? "ETH" : "BTC")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
        }
    }

    private var detailRow: some View {
        HStack(spacing: 4) {
            Text(tx.amount)
                .font(.system(size: 12, weight: .semibold))
            Text("to")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(String(tx.toAddress.prefix(8)) + "..." + String(tx.toAddress.suffix(4)))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func hashSection(hash: String) -> some View {
        Text(hash)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)

        HStack(spacing: 12) {
            Button(action: {
                UIPasteboard.general.string = hash
                vm.showToast("Tx hash copied", success: true)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
            }

            if let url = tx.explorerURL {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Explorer")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Receive Screen

struct ReceiveScreen: View {
    @ObservedObject var vm: WalletViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Receive") {
                vm.navigate(to: .home)
            }

            // Network pills
            HStack(spacing: 8) {
                NetworkPill(label: "ETH", icon: "\u{039E}", isSelected: vm.receiveNetwork == .eth) {
                    vm.receiveNetwork = .eth
                }
                NetworkPill(label: "BTC", icon: "\u{20BF}", isSelected: vm.receiveNetwork == .btc) {
                    vm.receiveNetwork = .btc
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)

            QRCodeView(content: vm.receiveAddress)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.bottom, 20)

            // Address
            Text(vm.receiveLabel)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

            Text(vm.receiveAddress)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal, 20)

            Button("Copy address") {
                UIPasteboard.general.string = vm.receiveAddress
                vm.showToast("Address copied")
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .padding(.top, 12)

            Spacer()
        }
    }
}

// MARK: - Sign Message Screen

struct SignMessageScreen: View {
    @ObservedObject var vm: WalletViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Sign message") {
                vm.navigate(to: .home)
            }

            Text("Sign a message with your private key to prove wallet ownership for dApp authentication.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            // Network pills
            HStack(spacing: 8) {
                NetworkPill(label: "Ethereum", icon: "\u{039E}", isSelected: vm.signNetwork == .eth) {
                    vm.signNetwork = .eth
                }
                NetworkPill(label: "Bitcoin", icon: "\u{20BF}", isSelected: vm.signNetwork == .btc) {
                    vm.signNetwork = .btc
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Message box
            VStack(alignment: .leading, spacing: 8) {
                Text("Message to sign")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $vm.signMessage)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            if let signature = vm.signResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Signature")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = signature
                            vm.showToast("Signature copied", success: true)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    }
                    Text(signature)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .textSelection(.enabled)
                }
                .padding(14)
                .background(Color.green.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Button(action: { vm.doVerify() }) {
                    HStack(spacing: 6) {
                        Image(systemName: vm.verifyResult == nil ? "checkmark.shield" :
                                vm.verifyResult == true ? "checkmark.shield.fill" : "xmark.shield.fill")
                        Text(vm.verifyResult == nil ? "Verify signature" :
                                vm.verifyResult == true ? "Verified" : "Invalid")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.verifyResult == nil ? .accentColor :
                                        vm.verifyResult == true ? .green : .red)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(vm.verifyResult == nil ? Color.accentColor.opacity(0.08) :
                                    vm.verifyResult == true ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.verifyResult == nil ? Color.accentColor.opacity(0.3) :
                                        vm.verifyResult == true ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }

            Spacer()

            PrimaryButton(title: "Sign message") {
                vm.doSign()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - QR Code

struct QRCodeView: View {
    let content: String

    var body: some View {
        if let image = generateQR(from: content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .padding(30)
                .foregroundColor(.secondary)
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        guard !string.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = 200.0 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
