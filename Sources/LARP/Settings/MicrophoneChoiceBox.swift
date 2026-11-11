import SwiftUI

/// The choice box of the microphone, in the settings and in the popover: the current choice and,
/// in the menu, "Predefinito di sistema", the connected input devices and the chosen one when it
/// is not connected ("<name> (non collegato)").
struct MicrophoneChoiceBox: View {
    var minWidth: CGFloat?
    private let controller: MicrophoneChoiceController

    init(minWidth: CGFloat? = nil, controller: MicrophoneChoiceController = .shared) {
        self.minWidth = minWidth
        self.controller = controller
    }

    var body: some View {
        LARPChoiceBox(value: controller.currentTitle, minWidth: minWidth) {
            ForEach(controller.options) { option in
                Button {
                    controller.choose(option.choice)
                } label: {
                    if option.choice.uid == controller.choice.uid {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(verbatim: option.title)
                    }
                }
            }
        }
        .accessibilityLabel(Text("Microfono"))
        // The devices connected now, every time the box is shown.
        .onAppear { controller.refresh() }
    }
}
