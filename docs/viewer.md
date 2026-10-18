# Unified Viewer — incremento 7

Obiettivo: consultare un link senza uscire da Bloom. La Library instrada i link
al browser interno; testi e allegati conservano i viewer locali già presenti.
I dettagli (titolo, note, raccolta, archivio) restano raggiungibili dal browser.

Wireframe iPhone:

    [< Bloom]         Titolo              [Dettagli] [⋯]
    indirizzo del sito corrente
    ─ progresso caricamento ─
    [errore o richiesta di aprire app, con azioni recuperabili]
    pagina web / player fornito dal sito
    [Indietro] [Avanti] [Ricarica/Stop]   [Condividi] [Esterno]

Browser WebKit con websiteDataStore.default, sessioni separate da Safari,
inline media abilitati e avvio della riproduzione richiesto all'utente. Nessuno
scraping, download dei video o bypass delle restrizioni dei siti. Instagram,
TikTok, Pinterest e YouTube restano pagine web e possono richiedere login o
limitare la riproduzione. La presenza di WebKit non garantisce un player
funzionante per ogni contenuto. Il pulsante Esterno è sempre disponibile.

Un'istanza WKWebView per apertura del contenuto; gli update SwiftUI non
ricaricano la pagina. I dati web persistono secondo le regole dei siti e di
WebKit, senza promettere che ogni login sopravviva a ogni riavvio. URL corrente
sempre visibile, back/forward reali, retry su errore/offline o processo terminato.
Le aperture target=_blank HTTP(S) usano lo stesso browser. Navigazioni a schemi
esterni sono bloccate, con messaggio e possibilità di aprire l'URL web corrente
all'esterno su azione esplicita. Nessuna modifica alle verifiche TLS.
Download non visualizzabili: messaggio e fallback esterno, senza finto successo.

Menu privacy: Cancella dati di navigazione → conferma → rimozione dati WebKit →
ricarica. È un'azione separata dai contenuti SwiftData: nessuna cancellazione di
link, testi, allegati o raccolte. Nessuna nuova autorizzazione di firma.

Gate: unit test policy URL e configurazione persistente; smoke WebKit con HTML
locale senza Internet; test precedenti e build. Sul dispositivo firmato: aprire
un link per ogni fonte, back/forward, login quando necessario, riapertura,
offline/retry, fallback esterno e dettagli/modifica; controllare i viewer locali.
La compatibilità dei siti e la persistenza effettiva dei login richiedono queste
prove sul dispositivo. Nessun cambiamento alla cattura YouTube verificata.
