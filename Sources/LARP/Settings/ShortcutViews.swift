import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The keys of a shortcut next to the button that does the same: JetBrains Mono 11 px, lime
/// text in a small ink box. Shows nothing while the shortcut has no combination.
struct ShortcutHint: View {
    let shortcut: Shortcut
    private let controller: ShortcutsController

    init(_ shortcut: Shortcut, controller: ShortcutsController = .shared) {
        self.shortcut = shortcut
        self.controller = controller
    }

    var body: some View {
        if let keys = controller.display(for: shortcut) {
            Text(verbatim: keys)
                .font(LARPFont.mono(11))
                .foregroundStyle(LARPColor.lime)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 5))
        }
    }
}

/// A row of the **Scorciatoie** section: the title of the shortcut, its combination in a box
/// (ink with lime text, or "Nessuna" in an outline box) and, under the row, why the last
/// combination was refused. A click on the box waits for the new combination ("Premi i
/// tasti…"): Esc cancels, Delete removes the shortcut.
struct ShortcutRow: View {
    let shortcut: Shortcut
    let title: LocalizedStringKey
    private let controller: ShortcutsController

    @State private var isListening = false
    @State private var monitor: Any?

    init(_ shortcut: Shortcut, title: LocalizedStringKey, controller: ShortcutsController = .shared) {
        self.shortcut = shortcut
        self.title = title
        self.controller = controller
    }

    var body: some View {
        SettingsRow(title) {
            Button(action: toggleListening) { keyBox }
                .buttonStyle(.larpPlain)
                .accessibilityLabel(title)
        } below: {
            if let rejection = controller.rejections[shortcut] {
                SettingsStatusLine(text: L10n.string(rejection.message), isFailure: true)
            }
        }
        .onDisappear { stopListening() }
    }

    @ViewBuilder
    private var keyBox: some View {
        if isListening {
            outlineBox("Premi i tasti…")
        } else if let keys = controller.display(for: shortcut) {
            Text(verbatim: keys)
                .font(LARPFont.mono(11))
                .foregroundStyle(LARPColor.lime)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 8))
        } else {
            outlineBox("Nessuna")
        }
    }

    private func outlineBox(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(LARPFont.inter(12))
            .foregroundStyle(LARPColor.textSecondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(LARPColor.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LARPColor.chipBorder, lineWidth: 1))
    }

    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        controller.dismissRejection(of: shortcut)
        // A shortcut pressed while the new combination is recorded must not run.
        controller.suspend()
        isListening = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let combination = KeyCombination(event: event)
            let hasModifiers = combination.map { $0.modifiers != 0 } ?? false
            let keyCode = Int(event.keyCode)
            MainActor.assumeIsolated {
                handle(keyCode: keyCode, hasModifiers: hasModifiers, combination: combination)
            }
            return nil
        }
    }

    private func handle(keyCode: Int, hasModifiers: Bool, combination: KeyCombination?) {
        if !hasModifiers, keyCode == kVK_Escape {
            // Esc: the shortcut stays as it was.
        } else if !hasModifiers, keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
            controller.clear(shortcut)
        } else if let combination {
            controller.change(shortcut, to: combination)
        }
        stopListening()
    }

    private func stopListening() {
        guard isListening else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isListening = false
        controller.resume()
    }
}
