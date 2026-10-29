---
created: 2026-10-29T14:52:24.539Z
updated: 2026-10-29T14:52:24.539Z
summary: Con ogni cambio di uscita audio, microfono o frequenza durante la registrazione, entrambe le tracce restano alla velocità sentita; l'audio di sistema riparte da solo o risulta perso, con un pannello.
tasks:
  - 5j73c7hw
  - y4h2h4wu
---
# Registrazione alla velocità reale

La cattura dell'audio di sistema segue ogni cambio dell'uscita audio e della sua frequenza: si ferma, ricostruisce il dispositivo sull'uscita corrente e riparte, etichettando ogni buffer col formato in vigore. Se non riesce a ripartire, la registrazione prosegue col solo microfono, la traccia di sistema si riempie di silenzio, l'eco non viene più rimossa e un pannello avvisa che l'audio di sistema non è disponibile; ogni cambio successivo ritenta. Il microfono usa un engine nuovo a ogni avvio e riavvio, così legge la frequenza vera. Test automatici con dispositivi finti verificano frequenza e durata entro l'1%.
