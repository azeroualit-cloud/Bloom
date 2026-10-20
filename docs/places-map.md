# Mappa dei contenuti — build 22

Terza destinazione principale: Libreria, Mappa, Riscopri. Una nota può avere un luogo facoltativo con nome e coordinate. Le note nello stesso punto sono raggruppate: il pannello del segnaposto permette di aprirle tutte; l’elenco luoghi offre gli stessi collegamenti anche quando le tessere della mappa non sono disponibili. Le note nel cestino non compaiono e ricompaiono dopo il ripristino.

Il luogo si può scegliere durante la creazione o successivamente dalla nota, cercando nome e città con Apple Maps. La ricerca parte soltanto su Cerca/invio, cancella le richieste superate e gestisce errori e risultati vuoti. Non viene chiesto accesso alla posizione del dispositivo. La ricerca e le tessere della mappa richiedono rete; note e coordinate restano locali. La posizione si rimuove da Modifica nota.

I link Apple Maps e Google Maps con coordinate esplicite di un punto vengono riconosciuti nel salvataggio locale e nei Comandi Rapidi, senza richieste di rete. Non vengono interpretate come destinazione le coordinate del viewport Google (@lat,lon). I link brevi e le ricerche testuali senza coordinate richiedono la selezione del luogo. I link condivisi Instagram/TikTok non trasmettono il geotag del post: Bloom non inventa una posizione e offre la selezione facoltativa.

Le coordinate sono validate (numeri finiti, latitudine ±90, longitudine ±180), conservate nei backup e nelle bozze e compatibili con gli archivi precedenti grazie a campi opzionali. Le modifiche normali della nota conservano il luogo; la rimozione esplicita non lo ricrea automaticamente dal vecchio link. Nessun azzeramento dell’archivio.
