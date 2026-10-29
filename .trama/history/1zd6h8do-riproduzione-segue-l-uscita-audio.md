---
created: 2026-10-29T14:52:24.746Z
updated: 2026-10-29T14:52:24.746Z
summary: Se cambia l'uscita audio durante la riproduzione, l'audio prosegue dal punto raggiunto sulla nuova uscita alla velocità registrata; se l'engine non riparte, passa in pausa.
tasks:
  - jlnhjokl
---
# Riproduzione segue l'uscita audio

Il player osserva il cambio di configurazione dell'engine audio, ricollega i nodi con il formato dei file e riprogramma le tracce dalla posizione raggiunta, restando in riproduzione. Se l'engine non riparte, la riproduzione va in pausa a quella posizione senza avvisi e il play successivo usa l'uscita corrente. In pausa o fermo i nodi vengono ricollegati senza cambiare stato.
