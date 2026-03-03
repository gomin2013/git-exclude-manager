import SwiftUI

/// The ✕ used to dismiss every sheet. Esc triggers it too.
struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.secondary.opacity(0.15)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .help(localized("btn.close"))
        .accessibilityLabel(localized("btn.close"))
    }
}
