---
description: Use when building the menu bar icon, its popover, the proposal panel, the recording notices and the recording surfaces.
---
# Menu bar and recording

## recorder
- **Menu bar icon**: the coloured LARP mark outside a recording; during a recording a red `#FF5A40` dot followed by the elapsed time in digits of equal width.
- **Popover**, 340 px wide, ink `#121310` background, radius 18, 14 px padding, dark appearance:
  - header: the LARP mark 30 px and "LARP" in Bricolage Grotesque 20 px bold, and on the right the state in 13 px `#A3A69B` ("Pronto quando vuoi" when idle, "Call rilevata" when proposing, "In registrazione" when recording);
  - the card of the state, `#1D1F1A`, radius 14, 16 px padding: idle, the eyebrow "Registrazione manuale", the line "Nessuna call in corso" and a full-width lime button "Registra"; proposing, the proposal card below; recording, the eyebrow with a red dot "In registrazione", the title of the call in Bricolage Grotesque 22 px semibold, the elapsed time in JetBrains Mono, and a white button "Ferma registrazione" with an ink square;
  - a divider `#2A2C26`, then the footer rows in 13 px `#E9EAE3`: "Apri archivio" on the left, "Impostazioni" and "Esci" on the right.
- **Proposal card**, the same wherever it appears (panel, popover, banner of the library): the eyebrow with a red `#FF5A40` dot "In onda ora · <call app>", in JetBrains Mono `#A3A69B`; the title "Call rilevata" in Bricolage Grotesque 22 px semibold white; a full-width lime button 52 px high, radius 12, with an ink dot and "Registra questa call".
- **Proposal panel**: the proposal card alone on ink, radius 18, 320 px wide, under the menu bar icon, with a soft shadow.
- **Notices** under the menu bar icon (echo not removed, system audio not available, microphone lost, system audio lost): ink cards, radius 14, 300 px wide, white 13 px text with an icon in `#FF5A40` for losses and `#D4F24A` for information; a button that opens System Settings is an outline button on dark.
- **Alerts** of a missing permission or of a recording that could not start stay system alerts.
