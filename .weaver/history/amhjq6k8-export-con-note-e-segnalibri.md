---
created: 2026-11-11T17:54:01.807Z
updated: 2026-11-11T17:54:01.807Z
summary: L'esportazione Markdown include le note e i segnalibri della call e scrive sempre il titolo della trascrizione.
tasks:
- vglhu2ph
cleared:
  vglhu2ph:
    title: 'Fix the code: Export senza note e segnalibri'
    refs:
    - requirements/rules#main-window
    technical: true
    finished: 2026-11-11T17:53:48.090Z
    body: |-
      ## What happens

      L'esportazione Markdown scrive il titolo, la riga con data e durata e la trascrizione. Le **note** e i **segnalibri** della call non compaiono mai nel file. Il titolo `## Trascrizione` compare solo quando la call ha una sintesi: senza sintesi le righe della trascrizione seguono la riga con data e durata senza titolo.

      ## What should happen

      I Requirements definiscono l'esportazione in sei parti: la parte 4 `## Note` con una riga `- [<orologio>] <testo>` per nota (o `- <testo>` senza ora), solo se la call ha note; la parte 5 `## Segnalibri` con una riga per segnalibro, solo se ce ne sono; la parte 6 `## Trascrizione` sempre, seguita dai paragrafi delle righe.

      ## Chosen option

      ### Estendere l'esportazione esistente

      L'esportazione scrive le parti 4 e 5 quando ci sono note o segnalibri e il titolo `## Trascrizione` sempre. Cambia il contenuto dei file esportati e della cartella Markdown; costo: aggiornare i test che oggi non si aspettano il titolo senza sintesi.

      ## Where in the code

      Sources/LARP/Archive/TranscriptExport.swift (`markdown(for:)`); Tests/LARPTests/TranscriptExportTests.swift
---
# Export con note e segnalibri

L'esportazione Markdown scrive ora la parte 4 (Note) e la parte 5 (Segnalibri) quando la call ha note o segnalibri, e il titolo della trascrizione anche senza sintesi. Cambia il contenuto dei file esportati e della cartella Markdown.
