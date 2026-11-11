---
status: approved
kind: change
requires:
- sbjz6djo
base:
  model/actors/teams.md: new
  model/actors/time.md: 9c7085c388ed7c2d5680a2504df9edd028881ba4e3b5e8116d528a7d181cb334
  model/actors/user.md: 59482a96e8734f5920844571aa9e55177447a7cd0a2eab24c4b310c6f683e1b5
  model/capture/recorder.md: cfc42dfad9102ceab3300d3be4dd78bec22b0b5f6238e2f252c01a517f175a4a
  model/capture/recording-view.md: f31ba0957935fb7c960884afc850a8aead50e71c96cb1cacbe5995bb558a8c21
  model/library/main-window.md: e578a4c7d6cc24a9a890f71125541e8eb9aec7a4f94ffbae842f4a1782caf8d0
  model/meeting-info/calendar-access.md: new
  model/meeting-info/feature.md: new
  model/meeting-info/teams-access.md: new
  model/meeting-info/teams-meeting.md: new
  model/settings/feature.md: 67ab07fd74792865882d0461aa504c6ae156f39423d2fd7ddee4387d439fd2ec
  model/settings/onboarding.md: 0ca154ce2dd1fe7f510138f4e9bd0ff5ad095ab2abe8b5a00feeb02c7cff20db
  model/settings/speaker-identification.md: new
  model/system.md: 524c1d3cd77682a9bc61daf1e3a27af02803e77f338b1f7628126170048c17c8
  model/transcription/call.md: 3179b8757af64ac91928cf24621d8a884ad4455c4d1c6ace06dd7db089624166
  requirements/data/settings.md: 6b408602b80529c6acc8b595fb15e68007d94dcc7de620435cfe7eef49a75ad5
  requirements/data/transcription.md: 7d7c271aeaf17fda55b872d9caa28e3760ea094f6dd5d9aae8333abbb46a5af7
  requirements/quality/privacy.md: new
  requirements/rules/meeting-info.md: new
  requirements/rules/transcription.md: d9a74910e7c3a1a29f7b53118324c99a4fec243c35198a6b3e408c5ef8f473d7
  requirements/tech/meeting-info.md: new
  requirements/ui/capture.md: 4795d7b21c93905c9146c5c0bb3e21123353c313a4324a026b229775029463ae
  requirements/ui/library.md: 8d411e39aa171ec568b6c5bb5dcc8ff75a6d2a126d7582546c1fdd366513dae6
  requirements/ui/settings.md: 37f9f3c09661e27c86e054f87c85d8e11bb1978831f5d55cdc84c9b2a74a7b5d
  specs.yaml: d69be213d259b75cee40122cae91458e3a2fc4ceadfa694957a34855d7ce8a67
created: 2026-11-11T14:39:43.753Z
label: 'Redesign: Teams e calendario'
job: oeg9sbc8
---
# Teams e calendario

Terza Proposal del redesign: dà alle call titoli, partecipanti e nomi leggendo Microsoft Teams tramite l'Accessibilità del Mac e il calendario del Mac, come chiesto dal designer e dallo sviluppatore (obiettivo principale: Teams).

## Decisioni

- Calendario completo: titolo della call dall'evento in corso, numero di persone nella proposta, elenco "Prossime" nella finestra a comparsa, nomi degli invitati proposti nella rinomina dei partecipanti.
- Microsoft Teams letto tramite l'Accessibilità: titolo della riunione, partecipanti e, quando Teams lo espone, chi sta parlando; la lettura di chi parla è sperimentale.
- Dal vivo le righe degli "Altri" mostrano il nome che Teams indica come parlante; il riquadro "Nella call" mostra i partecipanti di Teams.
- Dopo la separazione per voce un partecipante riceve in automatico il nome che Teams indicava come parlante per almeno il 70% del tempo delle sue righe; altrimenti resta "Partecipante N"; un nome dato dall'utente non viene mai sostituito.
- Titolo della call: prima Teams, poi l'evento del calendario in corso (il più recente tra quelli in corso all'avvio), poi il titolo predefinito; un titolo dato dall'utente vince sempre.
- "Prossime": solo gli eventi di oggi non ancora iniziati con il link di un'app di call nota, con ora e nome dell'app, al massimo tre.
- Interruttore "Identifica i parlanti", acceso di default: spento, Teams e calendario non danno nomi automatici né suggerimenti (titoli e proposta restano).
- Firma ad-hoc invariata: dopo ogni aggiornamento di LARP il permesso Accessibilità va concesso di nuovo; l'app lo rileva e lo chiede.
- I permessi di Teams e del calendario sono facoltativi nella schermata di benvenuto e si gestiscono nella sezione "Esportazione e integrazioni" delle Impostazioni.
- Né i dati di Teams né quelli del calendario vengono mai inviati a omp.

## Assunzioni dell'agente

- Dopo "Consenti" per Teams, Weaver rilegge il permesso ogni 2 secondi per 2 minuti, perché macOS non avvisa quando viene concesso.
- Quando due partecipanti raggiungono il 70% con lo stesso nome, lo riceve quello con la quota più alta.
- "Scollega" il calendario smette solo di leggerlo: il permesso di macOS si toglie da Impostazioni di Sistema.
- Quando Teams non mostra chi parla, nessun nome automatico viene dato e le righe dal vivo restano "Altri".
