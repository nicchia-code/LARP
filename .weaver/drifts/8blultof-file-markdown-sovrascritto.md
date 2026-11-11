---
status: fixed
refs:
- markdown-folder/On
origin: w06newey
task: jjtmw8ac
option: 3
job: e5ko6tv6
created: 2026-11-11T16:46:00.664Z
decided: 2026-11-11T17:24:34.505Z
---
# File Markdown sovrascritto

## What happens

Quando la cartella Markdown contiene già un file con lo stesso nome della call (per esempio un `Weekly.md` scritto dall'utente, o un file lasciato da una cartella spenta e riaccesa), la scrittura lo **sostituisce** senza avvisare. Il numero " (2)", " (3)" si aggiunge solo quando un'altra call della cartella usa già quel nome.

## What should happen

Il Model dice che un file non viene mai rimosso né rinominato se non è stato scritto da LARP per quella call, ma tace sul caso di un file estraneo con lo stesso nome: cosa fare cambia quali dati dell'utente restano.

## Fix options

### Cercare il primo nome libero

Se il file esiste e non è quello che LARP ha scritto per questa call, si usa " (2)", " (3)"… finché il nome è libero. Nessun file dell'utente viene toccato. Costo: spegnendo e riaccendendo la stessa cartella le call ottengono un secondo file (" (2)") accanto a quello vecchio.

### Non scrivere e segnalare

Il file estraneo resta intatto, la scrittura di quella call fallisce e le Impostazioni mostrano "Impossibile scrivere nella cartella" finché il nome non si libera. Costo: la call non ha file fino a un intervento dell'utente.

### Ricordare i file scritti da LARP

LARP conserva per ogni cartella i nomi che ha scritto e li sostituisce soltanto; un file con un nome non suo viene aggirato con " (2)". Riaccendendo la stessa cartella i vecchi file si riconoscono e si riscrivono. Costo: un elenco in più da salvare e tenere coerente.

## Where in the code

Sources/LARP/Call/MarkdownFolderSync.swift, scelta del nome (`fileName(for:language:)`) e scrittura atomica del file
