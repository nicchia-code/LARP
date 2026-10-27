---
technical: true
refs:
  - requirements/tech#General
  - specs#notes
---
# README per la rifinitura con omp

Quando il lavoro è finito, il README (in inglese) non dice più che non esiste nessun cloud. Dice invece che:
- l'audio resta sempre sul Mac;
- l'app non ha cloud, account o telemetria propri;
- la rifinitura del testo, spenta di default, manda il testo della trascrizione (mai l'audio) attraverso omp al fornitore del modello configurato in omp.

Il README spiega anche che la rifinitura richiede omp installato e configurato dall'utente e trovabile nel `PATH` della sua shell di login. L'interruttore "Rifinisci il testo con omp" nelle impostazioni accende la rifinitura e mostra se omp è pronto.

La frase iniziale del README e la sezione Dependencies ricordano che omp non è incluso nell'app: è un programma esterno opzionale.
