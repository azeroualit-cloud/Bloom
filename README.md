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
