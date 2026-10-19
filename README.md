# Bloom

App iOS/iPadOS 17+, SwiftUI e SwiftData, locale e indipendente da LifeOS.
L'archivio è nel container privato dell'app: nessun App Group, account o backend.
Vedi [requisiti e flussi](docs/blueprint.md).

## Sviluppo e verifica

Su macOS con Xcode 16+ e XcodeGen (`brew install xcodegen`):

```sh
xcodegen generate
open Bloom.xcodeproj
xcodebuild -project Bloom.xcodeproj -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
scripts/unsigned-ipa.sh
```

Scegliere un simulatore effettivamente presente. `project.yml` è la sorgente del
progetto. Linux supporta editing e controlli di configurazione, non i test iOS.
Nessun segreto o servizio esterno necessario. GitHub Actions esegue XCTest,
archivia e pubblica una release solo dopo il caricamento dell'IPA riuscito.
Le pull request non pubblicano. Un fallimento lascia l'ultima release disponibile.

## Installazione

URL stabile dell'ultima build pubblicata:

https://github.com/azeroualit-cloud/Bloom/releases/latest/download/Bloom.ipa

È un IPA da firmare con il proprio servizio prima dell'installazione. Se il
servizio supporta l'importazione da URL, usare direttamente il link. Non è un
collegamento OTA per installare un IPA non firmato. Non servono entitlement App
Groups o un'estensione incorporata. Conservare lo stesso bundle ID durante gli
aggiornamenti per mantenere i dati locali; non disinstallare per aggiornare.

## Salva subito un link

Aprire Bloom → + → incollare o digitare un URL HTTP(S) → Salva.
Verificare URL e data nella raccolta e la persistenza dopo chiusura e riapertura.
Un URL esatto già presente non crea un duplicato. Il salvataggio offline riguarda
l'indirizzo, non la pagina web.

## Condividi da Safari con una configurazione iniziale

Bloom espone l'azione App Intents **Salva link in Bloom**. In Comandi Rapidi:

1. Creare un comando chiamato **Salva in Bloom**.
2. Nei dettagli attivare **Mostra nel foglio Condividi**, ricevendo URL e pagine
   web di Safari. Usare il comando su una singola pagina/link per volta.
3. Aggiungere **Ottieni URL da input**, con **Input comando rapido** come ingresso.
4. Aggiungere l'azione di Bloom **Salva link in Bloom** e collegare il suo parametro
   URL all'URL ottenuto. Se viene presentato un elenco, usare il primo elemento.
5. In Safari aprire Condividi → Salva in Bloom. Consentire l'esecuzione se iOS lo
   richiede. Il comando salva nell'archivio privato e apre Bloom.

La guida è anche nell'app. App Intents è un'integrazione pubblica nativa, senza
container condivisi. La registrazione dell'azione dopo la firma e il percorso
Safari devono essere verificati sull'iPhone: build e unit test non lo dimostrano.

Se l'azione non compare, aprire Bloom una volta e cercarla nuovamente. Resta
sempre disponibile il percorso copia → + → Incolla → Salva.

### Alternativa con URL scheme

Bloom accetta `bloom://capture?url=<URL codificato come valore query>` e salva
immediatamente il link valido, mostrando l'esito. In un comando alternativo:
ottieni URL dall'input, codifica l'intero URL con **Codifica URL**, componi
`bloom://capture?url=` seguito dal risultato, quindi **Apri URL**.
La codifica del valore è necessaria per non perdere `&`, `#` e query annidate.
Il percorso nativo App Intents evita questa composizione manuale.

## Gate dispositivo — build 3

- Apertura senza App Groups e senza schermata di errore.
- Salva manuale, errore URL invalido con input conservato, annulla senza scritture.
- Stesso link salvato due volte → una voce; riapertura → dati presenti.
- Esecuzione azione Comandi Rapidi e condivisione Safari, anche con Bloom già aperta.
- URL con query e frammento conservato; offline; testo grande e VoiceOver.

La vecchia Share Extension e il vecchio archivio App Group sono stati ritirati
per decisione dell'utente. Nessuna cancellazione o migrazione automatica dal
vecchio container inaccessibile. La diagnostica resta disponibile per eventuali
errori dell'archivio privato, con report copiabile privo di contenuti personali.

## Library — build 4

Ricerca su titolo, URL, note e raccolta. Menu cartella per filtrare e gestire
raccolte; selettore Libreria/Archivio per i contenuti attivi o archiviati.
Aprire un contenuto → Modifica per titolo, note e raccolta. Archiviare dalla riga
o dal dettaglio; ripristinare dall'Archivio. Eliminare una raccolta conserva i
contenuti. I duplicati esatti includono anche i link archiviati.

Aggiornare senza disinstallare. La migrazione aggiunge proprietà opzionali e uno
stato archivio con valore predefinito, senza ricreare il database. La prova di
migrazione e le altre verifiche sono in Tests/LibraryTests.swift. Nessun reset
automatico è consentito in caso di errore. Verificare anche su dispositivo che
i link già salvati siano presenti dopo l'aggiornamento.

Percorsi confermati dall'utente: Instagram, TikTok e Pinterest tramite comando
Condividi con estrazione URL; YouTube con copia/incolla nell'app. Non sono previsti
ulteriori tentativi di condivisione YouTube in questo incremento. Importazione
di testi/immagini/file e Unified Viewer restano da implementare.

## Capture multiformato — build 5

Menu + → Link, Testo, Foto o File. Importazione singola fino a 25 MB; file e foto
sono copiati nell'archivio privato SwiftData, indipendentemente dall'originale.
Annullare durante la lettura impedisce il salvataggio. Se il save fallisce, è
possibile riprovare; l'originale rimane intatto. Foto usa il selettore di sistema,
senza richiedere accesso completo alla libreria. L'importazione non esegue file.

Testi selezionabili, immagini con anteprima ridimensionata e file con Quick Look
quando supportato. Per formati senza anteprima, usare Condividi file dopo aver
preparato l'anteprima. Le copie preparate per le anteprime sono temporanee e non
sono l'archivio permanente. File e testi usano ricerca/raccolte/archivio comuni.
Deduplica esatta del testo o dei byte importati, distinta per tipo; una copia con
nome diverso viene riconosciuta. Non sono ancora presenti modifica del corpo del
testo, OCR, estrazione del testo dai PDF o download offline delle pagine web.

Aggiornare senza disinstallare. Gate dispositivo: vecchi link/raccolte presenti,
importazione testo/foto/PDF, annulla, riapertura offline, lettura e organizzazione.
I test verificano migrazioni build 3 e 4, payload dopo rimozione dell'originale,
deduplica e limiti. La prova dei selettori e dei viewer sul dispositivo è separata.

## File e Markdown — build 6

Il selettore documenti usa UIDocumentPicker in modalità copia, con tipi generici
UTType.item. La lettura coordinata gestisce il passaggio dai provider documenti;
cartelle e file oltre 25 MB sono rifiutati. Nome e stato di importazione sono
visibili, e gli errori di importazione restano nella Library anche durante la
chiusura del selettore, con riprova quando i byte sono già disponibili.

Apri contenuto legge direttamente Markdown e altri file di testo UTF-8/UTF-16
con BOM fino a 512 KB, preservando il testo originale (sorgente, senza rendering
Markdown). File maggiori o altri formati passano all'anteprima di sistema e, quando
preparati, a Condividi file. Restano necessari test sul provider File dell'iPhone.

## Viewer web interno — build 7

Un link nella Library si apre nel browser interno di Bloom, con indirizzo corrente,
indietro/avanti, ricarica/stop, condivisione, fallback esterno e Dettagli per le
funzioni di organizzazione. Il browser usa WebKit con dati persistenti separati
da Safari. L'accesso ai siti va effettuato nel browser di Bloom; un sito può
richiedere nuovamente il login secondo le proprie regole. La riproduzione richiede
un gesto dell'utente e dipende dalle funzionalità offerte dalla piattaforma web.
Nessun bypass di login, TLS o restrizioni dei social.

I tentativi del sito di aprire automaticamente app esterne sono intercettati.
Apri all'esterno rimane un'azione esplicita; i popup web HTTP(S) usano la stessa
vista. Il browser non concede accesso a fotocamera/microfono alle pagine. Il menu
Cancella dati di navigazione richiede conferma e non elimina la libreria SwiftData.

Test WebKit con HTML locale, policy URL e configurazione persistente in CI.
La compatibilità di Instagram/TikTok/Pinterest/YouTube e la persistenza dei login
restano da provare sul dispositivo firmato. Nessuna modifica alla cattura:
YouTube continua a usare copia/incolla; gli altri social il comando verificato.
Testi e allegati conservano i viewer locali. Vedi docs/viewer.md per flussi e gate.

## Build 8 — Riscopri

Due tab: Libreria e Riscopri. Il feed verticale propone fino a 30 contenuti
personali attivi per giro, con ordine giornaliero locale e preferenza per varietà
di formato, raccolta e sito. Nessuna scoperta esterna o personalizzazione AI.
Nuovo giro (anche pull to refresh), apertura nel viewer e archiviazione con
ripristino dalla Libreria → Archivio. Le foto riusano l’anteprima locale ridotta;
nessun caricamento web prima di aprire il contenuto. Nessuna modifica allo schema
o alle modalità di cattura. Flusso e verifiche: [Bloomscrolling](docs/bloomscrolling.md).

## Build 9 — Backup locale

Libreria → menu raccolte → Backup locale. Esportazione JSON con allegati inclusi,
anteprima prima dell’importazione e merge senza sovrascrivere contenuti esistenti.
Reimportazione senza duplicati per ID, URL esatto o impronta dei contenuti.
Include Archivio, raccolte, titoli e note; esclude cookie e dati del browser.
File non cifrato, salvato nella destinazione scelta in File. Nessun backend.
Limiti e comportamento: [Backup locale](docs/backup.md).

## Build 10 — release per l’uso quotidiano

Cattura link/testi con raccolta e apertura dopo il salvataggio; destinazione
raccolta anche per foto/file. Anteprime foto nella Library, filtri per formato
e raccolta condivisi con Riscopri, selezione multipla per spostare/archiviare/
ripristinare. Titoli web recuperabili su richiesta (senza sovrascrivere quelli
personali), anche in gruppo fino a 10 link. Riscopri esclude i contenuti già
proposti nei giri della sessione, con Ricomincia a esaurimento.
Schema e backup invariati. [Flusso completo e verifiche](docs/daily-use.md).
