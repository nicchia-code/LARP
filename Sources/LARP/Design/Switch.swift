import SwiftUI

/// A switch, 36 × 22 px, radius 11, with a 16 px knob: on, an ink track and a lime knob; off, a
/// `#8A8D82` track and a white knob.
struct LARPSwitch: View {
    @Binding var isOn: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? LARPColor.ink : LARPColor.switchOff)
                Circle()
                    .fill(isOn ? LARPColor.lime : LARPColor.white)
                    .frame(width: 16, height: 16)
                    .padding(3)
            }
            .frame(width: 36, height: 22)
            .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.larpPlain)
        .larpFocusOutline(cornerRadius: 11)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityValue(isOn ? Text("Acceso") : Text("Spento"))
        .accessibilityAddTraits(.isToggle)
    }
}
