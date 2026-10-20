# Caroselli e consultazione — build 20

Formato 1:1 per nota e feed, paginazione orizzontale nativa con contatore. Link social, allegato principale, ulteriori file e testo sono pagine della stessa nota. La griglia conserva una copertina e segnala gli allegati multipli; il tap apre la nota quando contiene più pagine. I documenti restano accessibili anche da collegamenti diretti. I video locali usano AVPlayer soltanto nella pagina selezionata, senza autoplay; le risorse temporanee vengono rimosse all’uscita.

Il selettore foto/video accetta una selezione ordinata multipla. Il caricamento è atomico: se un elemento fallisce o supera i limiti, nessun elemento di quel gruppo viene aggiunto. Restano i limiti di 10 allegati e 25 MB complessivi per nota.

Categorie ordinate per attività manuale, con fallback alla data di creazione per i dati precedenti. Le modifiche ai tag aggiornano anche la categoria di origine. Recuperare una copertina online non modifica l’ordine. Date di modifica opzionali e compatibili con backup precedenti.

## Importare un post social completo

Verifica documentazione ufficiale del 20 ottobre 2026:

- [Instagram Media Children](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-media/children/) espone gli elementi di un album, ma richiede access token, login Business e permessi. Non è un downloader universale per qualunque URL salvato. Alcuni media_url video vengono omessi, ad esempio per audio protetto.
- [Instagram oEmbed](https://developers.facebook.com/docs/instagram-platform/oembed/) supporta post foto, caroselli e Reel come vista online. La documentazione vieta usare tale endpoint per estrarre o persistere il contenuto al di fuori dell’embed. Post privati, con restrizioni e con embed disabilitato non sono supportati.
- [TikTok Embed Videos](https://developers.tiktok.com/doc/embed-videos/) documenta l’incorporamento del player; non garantisce una copia locale dei contenuti di ogni post.

La build non aggiunge scraping, credenziali social né un servizio di download. I link social tentano l’apertura dell’app tramite universal link e ripiegano sul browser integrato se iOS non la apre. Il carosello locale funziona con i file che l’utente allega. Un futuro embed online va trattato come modalità distinta dall’archivio offline.
