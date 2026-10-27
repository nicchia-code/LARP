---
status: discarded
base:
  transcription/call.md: 460a28dfd384b5a3fe4dfa64c96094bc1b362286c3b48b8281f7eaf0634bd40e
delete: []
created: 2026-10-27T11:13:17.419Z
label: Fallimenti di cattura
---
# Fallimenti cattura e trascrizione

# Fallimenti cattura e trascrizione

Il Model descrive i due fallimenti che oggi non prevede, adottando il comportamento attuale del codice: se la cattura audio non parte dopo l'avvio della registrazione, la call appena nata viene eliminata senza avviso; se la trascrizione dall'audio salvato fallisce, la call resta in Transcribing e si riprova al lancio successivo dell'app, senza avviso.
