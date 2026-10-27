import SwiftUI

/// Content of the Settings scene. The controls are added by the settings Tasks;
/// their values live in `UserDefaults` under the keys of `SettingsKey`.
struct SettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "Impostazioni",
            systemImage: "gearshape",
            description: Text("Le impostazioni compariranno qui.")
        )
        .frame(width: 420, height: 260)
    }
}

#Preview {
    SettingsView()
}
