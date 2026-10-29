---
created: 2026-10-28T19:35:57.943Z
updated: 2026-10-28T19:35:57.943Z
summary: "Sintesi facoltativa delle call scritta da omp: interruttore «Sintesi con omp» nelle impostazioni, scheda «Sintesi» nella finestra archivio, sintesi salvata sulla call, ricerca ed esportazione in Markdown."
tasks:
  - 5oub9efm
  - 187krt1i
  - 5yhx26jj
  - gn0znb7w
  - cnm7cgmp
  - 829heyjy
---
# Sintesi delle call con omp

Nelle impostazioni compare l'interruttore «Sintesi con omp», spento di default e indipendente dalla rifinitura del testo. Con l'interruttore acceso, ogni call con almeno una riga di trascrizione viene sintetizzata da sola dopo la separazione dei partecipanti, e l'utente può chiedere la sintesi di qualsiasi call i cui partecipanti sono stati distinti. Rifinitura e sintesi usano ciascuna il proprio processo omp: se una fallisce, l'altra prosegue. A omp arriva solo il testo della trascrizione, mai l'audio.

Ogni call conserva al massimo una sintesi, con concetti chiave, decisioni e prossimi passi (ognuno con un responsabile facoltativo), il testo libero, la lingua e la data di scrittura. Ha anche uno stato della sintesi, separato dallo stato della call: nessuna, in scrittura, in attesa di nuovo tentativo, scritta. Nella sintesi salvata restano «Io» e «Partecipante <numero>»: i nomi scelti dall'utente si sostituiscono solo quando la sintesi viene mostrata, cercata o esportata.

Nella finestra archivio la call selezionata ha un controllo «Sintesi» / «Trascrizione». La call si apre sulla sintesi se ce l'ha, altrimenti sulla trascrizione. La ricerca confronta il testo digitato anche con il testo della sintesi, con i nomi attuali dei partecipanti e i titoli di sezione. L'esportazione in Markdown include la sintesi. Le sintesi già scritte restano leggibili, cercabili ed esportabili anche con l'interruttore spento. Il README (in inglese) dice che rifinitura e sintesi richiedono omp installato e configurato dall'utente e che a omp passa solo il testo.
