import SwiftUI

struct PINEntryView: View {
    let heading: String
    let message: String
    let onComplete: (String) -> Void
    var onCancel: (() -> Void)? = nil

    @State private var pin = ""
    @FocusState private var focused: Bool
    private let length = 6

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                Text(heading)
                    .font(.title2.weight(.bold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 14) {
                ForEach(0..<length, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
                        .background(Circle().fill(i < pin.count ? Color.orange : Color.clear))
                        .frame(width: 18, height: 18)
                        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: pin.count)
                }
            }

            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .focused($focused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: pin) { _, new in
                    let filtered = String(new.filter(\.isNumber).prefix(length))
                    if filtered != new { pin = filtered }
                    if filtered.count == length {
                        let entered = filtered
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onComplete(entered)
                        }
                    }
                }

            Button { focused = true } label: {
                Label("PIN Klavyesini Aç", systemImage: "keyboard")
            }
            .buttonStyle(.bordered)

            if let onCancel {
                Button("İptal", role: .cancel, action: onCancel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focused = true
            }
        }
    }
}
