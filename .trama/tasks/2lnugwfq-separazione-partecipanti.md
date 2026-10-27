---
column: done
technical: false
refs:
  - call/Separating participants
  - call/Awaiting separation retry
  - call.PARTICIPANTS_SEPARATED
  - call.SEPARATION_FAILED
  - macos.NETWORK_AVAILABLE
  - requirements/tech#call/Separating participants
drift: null
proposal: dlpwzchv
agent: false
created: 2026-10-27T10:07:36.916Z
finished: 2026-10-27T10:27:28.801Z
---
# Separazione partecipanti

Realizzare gli stati **Separating participants** e **Awaiting separation retry** della macchina `call`: distinguere per voce i singoli partecipanti nell'audio degli altri. Apple non offre la separazione per voce; la decisione dello sviluppatore è FluidAudio on-device (impronte vocali + raggruppamento su Core ML), dopo la call, senza LLM di correzione per ora.

Comportamento, come lo dice il Model:
- **Separating participants**: la trascrizione si può già leggere con "Io" e "Altri". L'audio di sistema viene analizzato per voce. Se riesce si emette `PARTICIPANTS_SEPARATED` → **Ready**: ogni riga "Altri" viene assegnata a "Partecipante 1", "Partecipante 2" e così via; le righe "Io" (microfono) non cambiano. Se non riesce (per esempio i modelli non si possono scaricare senza rete) si emette `SEPARATION_FAILED` → **Awaiting separation retry** e la trascrizione resta con "Io" e "Altri". Se l'app si chiude durante la separazione, al riavvio (`macos.APP_LAUNCHED`) la separazione riparte.
- **Awaiting separation retry**: la trascrizione si legge con "Io" e "Altri"; al ritorno della rete (`macos.NETWORK_AVAILABLE`) o al riavvio dell'app → **Separating participants**, nuovo tentativo automatico.
- Rinomina ed eliminazione in questi stati seguono il Model e sono realizzate dal Task "Gestione call"; questo Task garantisce che una separazione in corso si fermi pulita quando la call viene eliminata.

Come costruirlo:
- Diarizzazione offline di FluidAudio (`DiarizerManager` o il suo successore nella versione fissata) sulla traccia `system.caf` ricampionata a 16 kHz mono; numero di partecipanti rilevato automaticamente.
- Ogni riga "Altri" va al partecipante i cui segmenti si sovrappongono di più nel tempo alla riga; una riga senza sovrapposizioni va al partecipante del segmento più vicino. I partecipanti sono numerati 1, 2, … nell'ordine in cui parlano per la prima volta e appartengono solo a questa call.
- I modelli FluidAudio si scaricano al primo uso nella cartella Application Support dell'app e poi si riusano.
- Ritorno della rete rilevato con `NWPathMonitor`.
- Test con Swift Testing dell'assegnazione delle righe ai partecipanti (segmenti di diarizzazione finti) e delle transizioni.
