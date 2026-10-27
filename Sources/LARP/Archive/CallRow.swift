import SwiftUI

/// A call in the list of the archive: title, date, duration and, when it is not ready, its state.
struct CallRow: View {
    let call: Call
    @Environment(CallLifecycle.self) private var lifecycle

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(call.displayTitle)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(ArchiveFormat.dayAndTime(call.startedAt))
                if call.state != .recording {
                    Text("·")
                    Text(ArchiveFormat.duration(call.duration))
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let status = lifecycle.statusLabel(of: call) {
                Label(status, systemImage: call.state == .recording ? "record.circle" : "hourglass")
                    .font(.caption)
                    .foregroundStyle(call.state == .recording ? Color.red : Color.orange)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
