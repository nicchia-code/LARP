---
created: 2026-10-27T12:12:25.253Z
updated: 2026-10-27T12:12:25.253Z
summary: A ogni tag vX.Y.Z un workflow esegue i test e pubblica LARP come Release con un DMG semplice, firmato ad-hoc e senza notarizzazione.
tasks:
  - rcrl8gfj
---
# Rilascio su GitHub Releases

Il nuovo workflow di rilascio, separato dalla CI, parte al push di un tag vX.Y.Z su macOS 26. Esegue il test plan e si ferma se un test fallisce. Compila Release con firma ad-hoc, con versione presa dal tag e numero di build uguale al numero dell'esecuzione. Crea LARP-<versione>.dmg con hdiutil e lo allega a una GitHub Release con testo italiano di installazione e note generate. Il README documenta pubblicazione e installazione.
