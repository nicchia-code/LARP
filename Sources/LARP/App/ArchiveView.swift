import SwiftUI

/// Content of the archive window. The list of calls is added by the archive Tasks.
struct ArchiveView: View {
    var body: some View {
        ContentUnavailableView(
            "Nessuna registrazione",
            systemImage: "waveform",
            description: Text("Le call registrate compariranno qui.")
        )
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    ArchiveView()
}
