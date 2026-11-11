import SwiftUI

/// The "Segnalibri" view of the library: one white card per call with bookmarks, with the eyebrow of
/// its day, time and call app, its title and one row per bookmark (its time in a chip and the text of the
/// transcript line at that time, at most two lines), highlighted under the pointer. A click on a row is
/// `user.SELECT_BOOKMARK`. Without bookmarks the view says "Nessun segnalibro".
struct BookmarksLibraryView: View {
    let groups: [BookmarkGroup]
    /// `user.SELECT_BOOKMARK`: the call of the bookmark and the bookmark.
    let select: (Call, Bookmark) -> Void

    var body: some View {
        if groups.isEmpty {
            Text("Nessun segnalibro")
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 48)
        } else {
            VStack(spacing: 16) {
                ForEach(groups) { group in
                    BookmarkGroupCard(group: group, select: select)
                }
            }
        }
    }
}

private struct BookmarkGroupCard: View {
    let group: BookmarkGroup
    let select: (Call, Bookmark) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .larpText(LARPTextStyle.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(LARPColor.textSecondary)
                Text(group.call.displayTitle)
                    .larpText(LARPTextStyle.cardTitle)
                    .foregroundStyle(LARPColor.ink)
                    .lineLimit(2)
            }
            VStack(spacing: 2) {
                ForEach(group.rows) { row in
                    BookmarkLibraryRow(row: row) { select(group.call, row.bookmark) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .larpCard(.light, padding: 20, radius: 18)
    }

    /// Day and time, then the call app ("Manuale" for a recording started by hand).
    private var eyebrow: String {
        let app = group.call.appLabel()
        return "\(ArchiveFormat.cardDayAndTime(group.call.startedAt)) · \(app)"
    }
}

private struct BookmarkLibraryRow: View {
    let row: BookmarkRow
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ClockChip(seconds: row.time)
                Text(row.lineText ?? "")
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHovering ? LARPColor.rowHover : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.larpPlain)
        .onHover { isHovering = $0 }
    }
}
