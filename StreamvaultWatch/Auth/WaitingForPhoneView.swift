import SwiftUI

struct WaitingForPhoneView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Open Streamvault on your iPhone to connect.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
