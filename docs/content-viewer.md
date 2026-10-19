# Consultazione contenuti — build 12

Obiettivo: aprire un contenuto personale senza lasciare Bloom e senza lavoro in
background durante lo scorrimento della Libreria.

Flussi:

1. Link → browser WebKit persistente. Al primo accesso Bloom richiede al sito una
   preview tramite LinkPresentation e la salva localmente solo se disponibile.
   Pinterest, TikTok e Reels restano contenuti web: la preview è migliorativa,
   mentre il browser interno, il player fornito dal sito e “Apri all’esterno”
   sono sempre il percorso di consultazione.
2. Immagine o screenshot locale → tela dedicata scura, immagine ridimensionata
   in modo sicuro, controlli minimi e Dettagli su richiesta. I byte originali
   non vengono ritagliati né modificati.
3. Testo catturato o Markdown importato → lettura Markdown selezionabile,
   passaggio a Sorgente e Modifica. Salva aggiorna il contenuto nell’archivio
   privato; Annulla conserva l’originale. Testo vuoto, oltre 25 MB o uguale a un
   altro contenuto viene rifiutato senza scritture parziali.

La preview di un sito può mancare per login, privacy, rete o policy del sito. In
quel caso Bloom mostra il browser e non inventa un’immagine. Le preview sono cache
locali incluse nel database dell’app e non introducono server o App Groups.
