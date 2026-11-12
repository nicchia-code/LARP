---
status: approved
kind: change
base:
  model/capture/microphone.md: 60ee35d54f67e76608ddf503491526a0a65ff236646109e43217e6a8d2879b1c
  model/meeting-info/teams-meeting.md: 64b2278114dbb706403b7ba0bb4088ba3e30fda0d451757cdbddc54136540caa
  requirements/data/general.md: 7403fee222f6586a0fa23f6e7b9fb9acc189ff2f365f8b35832504d1859d9e20
  requirements/quality/privacy.md: c2458d3632b99e83f6a83f6894f0f09654e5655b2f9114188221165fa661dc59
  requirements/rules/capture.md: 9f222a81e27cdb6a148c5a0f7e159a39fcb949caf31398143fed32b885d47ead
  requirements/rules/meeting-info.md: d8ac9aa41f9db1eaee4ad88c7f31834dacab5db8dfe867680c322e3ea22adae2
  requirements/tech/capture.md: 2af9fd63a79cca45850c3db78e18dd54bbcaebe2ac9e6a5dba22da477785b4f3
  requirements/tech/general.md: e21cce3e9040b25ab9e57b94747320d6cc01109450f4a0ebbc801527d5521d76
  requirements/tech/meeting-info.md: 974edcafc9aeabf5aa32d7bb57bf368844940c0443ef85775ced952efc630b20
  specs.yaml: 4d62c0c6346010bd86fabf771d0ec2ed8fbfd09ca734aba112d9aa10c90114de
created: 2026-11-12T15:18:59.723Z
request: 2026-11-12T16-00-27
label: Teams e diagnostica
job: ejuod04e
---
# Lettura Teams leggera

Con il nuovo Microsoft Teams le chiamate cadono all'avvio o vanno in attesa, e per le chiamate Teams "Call rilevata" non compare. L'ipotesi principale è che la lettura di Teams tramite Accessibilità (letture continue fino a 25.000 elementi e richieste di esposizione ripetute) blocchi Teams; in alternativa il rilevamento non collega a Teams il processo che usa il microfono, o la cattura con gli AirPods riapre il microfono troppo spesso. Questa modifica rende leggera la lettura, rende robusto il rilevamento, riduce le riaperture del microfono, aggiunge un registro diagnostico per capire a posteriori cosa succede e uno script per verificare gli elementi di Teams.

## Decisioni

- Verifiche dello sviluppatore: prova senza Accessibilità non ancora fatta, script dei processi non ancora eseguito, rapporto di crash non cercato; il design procede sulle ipotesi.
- Teams è letto solo mentre Teams usa il microfono o mentre una registrazione è in corso, anche con "Rileva le call" spento o Teams non sorvegliato; quando smette di servire la riunione è dimenticata.
- Ritmo: una lettura ogni 2 secondi e solo alla nascita di una finestra o al cambio di un titolo (niente notifiche di layout ed elementi distrutti), con almeno 1 secondo di pausa tra la fine di una lettura e l'inizio della successiva.
- Nessuna lettura nei 3 secondi dopo che Teams apre una finestra.
- Trovata la finestra della riunione, le letture visitano solo quella; al più 5.000 elementi e 1 secondo per lettura, 0,25 secondi di attesa per richiesta.
- La richiesta di esporre l'interfaccia (i due attributi di oggi) è fatta al più una volta per processo di Teams.
- Una lettura che arriva al limite di elementi o di tempo raddoppia la pausa fino a 30 secondi; una lettura rapida la riporta normale. Dopo 3 letture di fila senza identificatori web, anche dopo la richiesta di esposizione, quel processo di Teams non è più letto fino al suo riavvio.
- Verifica degli elementi di Teams: uno script Swift nel repository, avviato dal Terminale durante una chiamata, scrive in un file ruoli, identificatori web e classi degli elementi, con i testi sostituiti dalla loro lunghezza. I valori corretti arriveranno con una richiesta di design successiva.
- Rilevamento: un processo che usa il microfono è attribuito prima di tutto all'app che macOS ritiene responsabile del processo, poi con le regole di oggi.
- Registro diagnostico: un file di LARP in `~/Library/Logs/LARP`, un file per giorno, eliminato dopo 30 giorni, testo leggibile una riga per evento, ogni riga subito su disco, sempre attivo, senza interruttore. Affianca il registro di macOS, che resta com'è. Il README spiega dove trovarlo.
- Il registro scrive: inizio e fine dell'uso del microfono di ogni processo con identificativo, catena dei genitori, processo responsabile e app di call riconosciuta o nessuna; per ogni lettura di Teams durata, elementi visitati, richiesta di esposizione e marcatore trovato; per la cattura quanto scritto oggi più il motivo di ogni riavvio, le perdite e i ripristini.
- Il microfono è catturato direttamente dal suo dispositivo con Core Audio, solo ingresso: un cambio della sola uscita audio non lo riapre più, ma fa ricominciare da capo l'eliminazione dell'eco.
- Durante una registrazione, il primo titolo letto da Teams sostituisce il titolo della riunione preso dall'evento del calendario; un titolo già preso da Teams o scritto dall'utente non viene sostituito.

## Assunzioni dell'agente

- La cattura solo ingresso usa un'unità audio HAL di Core Audio con l'uscita disattivata, legata al dispositivo del microfono da usare.
- Il processo responsabile si legge con la funzione non documentata `responsibility_get_pid_for_pid`, cercata a runtime; se manca, valgono le regole di oggi.
- Lo script di verifica sta in `scripts/` e il README spiega come avviarlo e quale permesso concedere al Terminale.
