import SwiftUI
import SetaMacCore

struct ScannerSetupSheet: View {
    @ObservedObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SetaSheetLayout(
            title: "Set up library analysis",
            subtitle: "One-time setup so SetaMac can scan BPM, key, and energy from your folders.",
            width: 560
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if store.scannerSetupCompleted {
                    completedContent
                } else if store.scannerSetupFailed {
                    failedContent
                } else if store.isRunningScannerSetup {
                    runningContent
                } else {
                    welcomeContent
                }
            }
        } footer: {
            footerBar
        }
    }

    private var welcomeContent: some View {
        SetaSheetSectionCard(
            icon: "arrow.down.circle",
            title: "What happens next",
            subtitle: "SetaMac installs a local scanner into Application Support. Your music stays on disk; nothing is uploaded."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                setupStep("Copy scanner files into SetaMac's app data folder")
                setupStep("Create a local Python environment")
                setupStep("Install analysis dependencies")
                Text("Internet is required once. This usually takes a few minutes.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var runningContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text(store.scannerSetupMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SetaTheme.text)
            }
            Text("Keep SetaMac open until setup finishes.")
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var completedContent: some View {
        SetaSheetSectionCard(
            icon: "checkmark.circle.fill",
            title: "Scanner ready",
            subtitle: "Next, add your music folders and rescan the library."
        ) {
            Text("SetaMac can now analyze tracks from folders you choose.")
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var failedContent: some View {
        SetaSheetSectionCard(
            icon: "exclamationmark.triangle.fill",
            title: "Setup did not finish",
            subtitle: store.scannerSetupMessage
        ) {
            if !store.scannerSetupDetail.isEmpty {
                Text(store.scannerSetupDetail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SetaTheme.muted)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var footerBar: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            if store.scannerSetupFailed {
                SetaSecondaryButton(title: "Try again") {
                    store.runScannerSetup()
                }
            } else if store.scannerSetupCompleted {
                Button("Continue") {
                    store.finishScannerSetup()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(SetaTheme.accent)
                .keyboardShortcut(.defaultAction)
            } else if !store.isRunningScannerSetup {
                Button("Start setup") {
                    store.runScannerSetup()
                }
                .buttonStyle(.borderedProminent)
                .tint(SetaTheme.accent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func setupStep(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(SetaTheme.accent)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
