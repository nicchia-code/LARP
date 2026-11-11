---
description: Use when building the settings page of the main window, its sections and its rows.
---
# Settings page

## settings
- The settings page shares the main window and its sidebar: the sidebar shows "‹ Archivio" at the top and the names of the sections; the selected one is drawn like the selected item of the library.
- The page has the eyebrow "Impostazioni" and the title "Fallo tuo." in Bricolage Grotesque 44 px, then the sections as white cards in two columns (one column when the page is narrower than 900 px), 16 px apart.
- A card has its heading in Bricolage Grotesque 20 px semibold and rows separated by `#E4E4DC` dividers; a row has its label in 13 px semibold, an optional explanation under it in 12 px `#5A5D55`, and its control on the right: a switch, a choice box, an outline button or a segmented choice.
- Sections and their rows:
  - **Trascrizione**: "Motore" with the single fixed value "Sul Mac" shown as a selected ink segment and the explanation "L'audio non lascia il computer"; "Lingua" with the choice Italiano / English and, under it, the state of the speech model ("Verifica in corso…", "Download in corso…", "Non disponibile, nuovo tentativo appena possibile", "Pronta") with "Vale per le registrazioni che iniziano dopo la scelta."; "Rifinisci il testo con omp" with a switch and, while it is on, the state of omp under it.
  - **Sintesi**: "Sintetizza quando la call finisce" with a switch, the explanation "Sintesi, decisioni e prossimi passi scritti da omp" and, while it is on, the state of omp under it.
  - **Scorciatoie**: "Apri LARP all'accesso" with a switch, the explanation "Resta discreto nella barra dei menu", the approval hint "Approva LARP in Impostazioni di Sistema › Generali › Elementi login." while it waits for approval, and the error in `#B42A18` when there is one.
- The state of omp reads "Verifica in corso…", "omp pronto" or "omp non trovato" (the last in `#B42A18`).
