---
status: approved
kind: change
requires:
- 974kl54q
base:
  model/actors/user.md: 7a03a82e621ab7075784419a35b1879a1eff23be469c627ffb564c77a5c406b2
  model/library/feature.md: 8a98d471acecd43c2f257fb522c61543ad9fe092985a9b309920481b7a7efe61
  model/library/folder.md: new
  model/library/main-window.md: d3b8c9db8c6fc98872185e1e58d6fb494f2418327043e58cf26686266ac6dc07
  model/library/playback-options.md: new
  model/library/playback.md: bbea79670df959f91cc0534490bf2a74da456778c7a935e189f3dedcff4e2c61
  model/system.md: 1ffcc8319554dc61a8397002b848bf3362bfa48a53c264c1bd12e446dc617b93
  model/transcription/call.md: 25dea745d983fdae8fc4c2e47b7a9355ecf1aaeac2698063fe520f1d41b09416
  requirements/data/general.md: 3ae266e31b63539fc4ca4584707feecd1450d43e37de536956ef6898c2139f28
  requirements/data/settings.md: 3204fee43790b9ec7e5e86aade1337ff7d81a0119b5852041d0555b6e41979ac
  requirements/data/transcription.md: d803c72e63cb217aecae8a6118f794564be117ac1dd2d9e64957c61f0a29987a
  requirements/rules/library.md: f0df9243fe53e1038b98fe8ee10c4aaad1aef1e1464257926bf735a19fab7009
  requirements/tech/library.md: 40b6e0828c58f1970765bb181f38fc7c6d91eedb7462d793aef75d1433f4b30b
  requirements/ui/library.md: 5cfa11f7b239c5423958e1a15b7a93c1d9cfe8fd32ee32a38137ac34c2209def
created: 2026-11-11T14:50:04.744Z
label: 'Redesign: archivio'
job: oeg9sbc8
---
# Archivio arricchito

Quarta Proposal del redesign: aggiunge all'Archivio e alla pagina della call le funzioni della Style Guide che non usano omp.

## Decisioni

- Card con la forma d'onda colorata per voce, calcolata una volta dai file audio quando la trascrizione è pronta; le call già in archivio la ricevono in sottofondo.
- Filtri per app sopra le card: "Tutte", una chip per ogni app presente, "Manuali" e "Importate".
- Importazione di un file audio come call: trascritta e separata come le altre, tutte le voci diventano partecipanti (nessun "Io"); titolo dal nome del file, data dall'ultima modifica del file.
- Cartelle create dall'utente, rinominabili ed eliminabili; una call in al più una cartella; eliminando una cartella le call restano senza cartella; "Sposta in cartella" dalla pagina della call.
- "Trova una parola" nella trascrizione della call.
- "Copia sintesi" e "Copia trascrizione" con lo stesso testo dell'esportazione Markdown.
- Chip dei partecipanti con la percentuale di tempo di parola, da cui si rinominano.
- Velocità di riproduzione (1×, 1,25×, 1,5×, 2×, 0,75×) e "Salta i silenzi" (tratti senza righe oltre 2 secondi); entrambe si ricordano tra le call e gli avvii.
- Correzione a mano del testo delle righe: la correzione diventa il testo originale, quindi una nuova rifinitura parte da lì e "Ripristina originale" torna al testo corretto.
- Non sviluppati: "Elimina tutte le registrazioni".

## Assunzioni dell'agente

- Il testo si corregge solo quando la call è pronta, come la rinomina dei partecipanti.
- Un file audio importato viene convertito nel formato delle tracce come traccia dell'audio di sistema; se non si può leggere, un avviso lo dice e non nasce nessuna call.
- Valori scelti dall'agente: forma d'onda di 44 barre su scala da −50 a 0 dBFS; il salto dei silenzi riparte 0,3 secondi prima della riga successiva; nomi delle cartelle lunghi al massimo 60 caratteri e unici.
- La chip "Manuali" compare solo quando c'è una call registrata a mano, "Importate" solo quando c'è una call importata.
