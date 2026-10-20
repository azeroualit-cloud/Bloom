# Caroselli e consultazione — build 25

Formato 4:3 orizzontale nella nota e 3:4 verticale in Riscopri, paginazione orizzontale nativa con contatore. In Riscopri link social, allegato principale, ulteriori file e testo sono pagine dello stesso post. Il tap sulla copertina o sulla pagina apre sempre la nota. Nella nota titolo e corpo Markdown sono subito visibili sopra gli allegati; il corpo non viene duplicato nel carosello della nota. Il link si apre soltanto con un tap esplicito sul suo allegato. La griglia conserva una copertina e segnala gli allegati multipli; il tap apre sempre la nota, anche quando contiene un solo link o file. Il carosello è l’unico elenco visibile degli allegati: il tap sulla pagina del documento apre lettura e modifica. Le immagini vengono ritagliate solo nell’anteprima; il tap apre tutti i pixel dell’originale con zoom, anche se la copertina è stata inquadrata manualmente. I video locali usano AVPlayer soltanto nella pagina selezionata, senza autoplay; le risorse temporanee vengono rimosse all’uscita.

Il selettore foto/video accetta una selezione ordinata multipla. Il caricamento è atomico: se un elemento fallisce o supera i limiti, nessun elemento di quel gruppo viene aggiunto. Restano i limiti di 10 allegati e 25 MB complessivi per nota.

Tutti e Da specificare sono righe senza copertina. Le altre categorie conservano copertina e titolo in una griglia a due colonne. Categorie ordinate per attività manuale, con fallback alla data di creazione per i dati precedenti. Le modifiche ai tag aggiornano anche la categoria di origine. Recuperare una copertina online non modifica l’ordine. Date di modifica opzionali e compatibili con backup precedenti.

## Importare un post social completo

Verifica documentazione ufficiale del 20 ottobre 2026:

- [Instagram Media Children](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-media/children/) espone gli elementi di un album, ma richiede access token, login Business e permessi. Non è un downloader universale per qualunque URL salvato. Alcuni media_url video vengono omessi, ad esempio per audio protetto.
- [Instagram oEmbed](https://developers.facebook.com/docs/instagram-platform/oembed/) supporta post foto, caroselli e Reel come vista online. La documentazione vieta usare tale endpoint per estrarre o persistere il contenuto al di fuori dell’embed. Post privati, con restrizioni e con embed disabilitato non sono supportati.
- [TikTok Embed Videos](https://developers.tiktok.com/doc/embed-videos/) documenta l’incorporamento del player; non garantisce una copia locale dei contenuti di ogni post.

La build non aggiunge scraping, credenziali social né un servizio di download. I post Instagram con percorso /p/ si aprono dentro Bloom attraverso la vista incorporata online; il menu Visualizzazione permette di passare alla pagina originale, sempre nel browser interno, se l’embed non è disponibile o richiede accesso. I Reel e gli altri link social conservano l’apertura dell’app tramite universal link e il browser integrato come ripiego. Nessuna apertura esterna automatica dai post /p/. Il carosello locale funziona con i file che l’utente allega; non rappresenta una copia offline delle slide Instagram.

La disponibilità di una copertina non prova che siano disponibili tutti i media del post. oEmbed supporta il tipo carosello come contenuto incorporato, ma la possibilità di scorrere le slide nel rendering va verificata sul provider e sul post reale; dipende da Instagram e non è implementata come carosello nativo in Bloom. L’integrazione usa il rendering /p/{shortcode}/embed/ del provider, senza token o estrazione dei media. I test coprono URL canonici, instradamento interno e recupero; non certificano lo scorrimento di ogni post Instagram reale.

## Salvataggio dai Comandi Rapidi

L’azione Salva link in Bloom ha openAppWhenRun disattivato e salva in background senza caricare anteprime di rete. Solo dopo un errore usa la continuazione in primo piano di App Intents: iOS può chiedere il consenso a proseguire in Bloom. Gli errori e gli URL vengono accodati nello storage privato e presentati in Bloom per riprovare, senza risalvare automaticamente prima della scelta dell’utente. Eventuali ulteriori azioni Apri app/Apri URL aggiunte al comando dall’utente continuano naturalmente ad aprire l’app. La transizione dal foglio di condivisione dopo la firma Signulous richiede verifica sul dispositivo.
