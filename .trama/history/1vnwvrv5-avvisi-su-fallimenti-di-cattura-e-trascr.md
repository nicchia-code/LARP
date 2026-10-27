---
created: 2026-10-27T11:21:43.449Z
updated: 2026-10-27T11:23:02.785Z
summary: Se la cattura non parte l'utente riceve un avviso con il motivo; se la trascrizione da file fallisce la call lo indica e riprova da sola dopo un'attesa.
tasks:
  - 43a6o9u3
---
# Avvisi su fallimenti di cattura e trascrizione

Quando la registrazione non riesce ad avviare la cattura, la call viene eliminata, il registratore torna a riposo (il menu non mostra più una registrazione in corso) e compare un avviso in italiano che spiega perché. Quando la trascrizione dall'audio salvato fallisce, la call resta in trascrizione, l'archivio mostra che non è riuscita e il sistema riprova automaticamente dopo un'attesa, senza un nuovo stato.
