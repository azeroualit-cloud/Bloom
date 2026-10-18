# Bloom — partenza 18 ottobre 2026

## Contratto della prima milestone
App personale iOS/iPadOS 17+, SwiftUI e SwiftData, locale, senza account,
backend, Cloudflare o dipendenze da LifeOS. Nessuna richiesta di rete per salvare
un URL. La disponibilità offline riguarda l'indirizzo, non il contenuto della pagina.

La prova richiesta è: Safari → Condividi → Salva in Bloom → file persistito
nell'App Group → apertura Bloom → importazione SwiftData → dettaglio URL →
chiusura e riapertura → URL ancora presente. Build IPA, firma Signulous e questa
prova su iPhone costituiscono il gate; la sola build non chiude la milestone.

## Flusso e stati
L'estensione accetta un URL HTTP(S), mostra attesa, completa solo dopo la scrittura
atomica. Se fallisce, conserva il link in memoria per Riprova e offre Annulla.
Bloom importa all'apertura, al ritorno in primo piano e con pull-to-refresh.
Errori visibili con retry, senza cancellare il file pendente. L'indisponibilità
dell'App Group è un errore esplicito: nessun archivio privato alternativo che
nasconda una firma non funzionante.

Wireframe funzionale, non design definitivo:

    Safari / foglio condivisione         Bloom / raccolta
    ┌──────────────────────────┐        ┌──────────────────────────┐
    │ Salvataggio in Bloom…    │        │ Bloom                    │
    │ [errore se necessario]   │        │ [errore + Riprova]       │
    │ [Riprova] [Annulla]      │        │ dominio                  │
    └──────────────────────────┘        │ URL (max 2 righe)   >    │
                                        │ data                     │
                                        └──────────────────────────┘
    Raccolta vuota: istruzione per condividere da Safari.
    Dettaglio: URL selezionabile completo, data, Apri nel browser.

Componenti: NavigationStack, List, Form, ContentUnavailableView e controlli
UIKit nativi nell'estensione. Tipografia semantica con Dynamic Type, colori di
sistema chiaro/scuro, spacing 4/16/24 pt, controlli estensione almeno 44 pt.
Nessun componente visivo generalizzato prima di un riuso reale. Verificare VoiceOver,
testo grande, iPhone piccolo e iPad su runtime Apple prima di approvare la UI.

## Dati e concorrenza
Ogni cattura ha UUID, URL e data. L'estensione non apre SwiftData: scrive JSON
atomici in CaptureInbox nell'App Group. Solo l'app importa nel database locale
Bloom.store. L'UUID rende idempotente il replay dello stesso file dopo un crash;
non è ancora deduplicazione di due condivisioni distinte dello stesso URL.
Il file si elimina solo dopo save riuscito. Un file corrotto resta sul disco e
produce errore: recupero manuale documentato, nessuna cancellazione silenziosa.
Per recuperare, conservare una copia del JSON corrotto prima di rimuoverlo dal
container tramite gli strumenti del dispositivo; questa versione non offre UI
per gestire file corrotti. Pianificare migrazioni prima di modificare lo schema.

## Sequenza successiva
1. Chiudere la prova tecnica su dispositivo firmato.
2. Capture + Library: testi, immagini, file, raccolte, ricerca, deduplica.
3. Unified Viewer: viewer interni e browser persistente con fallback.
4. Bloomscrolling: feed personale, varietà e riproposizione.
5. Import PKMS, lingue, AI e backup. Knowledge dopo validazione del metodo.

Ogni fase richiede requisiti, flussi e wireframe prima delle schermate definitive.
