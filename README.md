# Bloom

App nativa SwiftUI, local-first, indipendente da LifeOS. Prima slice tecnica:
Share Extension → inbox App Group → SwiftData → raccolta e dettaglio URL.
Vedi [contratto e wireframe](docs/blueprint.md).

## Sviluppo su Mac

Prerequisiti: macOS, Xcode 16+, iOS SDK, XcodeGen (`brew install xcodegen`).

```sh
cd /percorso/Bloom
xcodegen generate
open Bloom.xcodeproj
```

`project.yml` è la sorgente del progetto Xcode; rigenerare dopo ogni modifica
alla configurazione. Non occorrono chiavi API, servizi o database esterni.
In Linux si possono modificare sorgenti e controllare plist/YAML/shell, ma non
compilare SwiftUI/SwiftData o eseguire i test iOS.

Per il dispositivo impostare il proprio team, bundle ID di app/estensione e un
App Group registrato. `APP_GROUP_IDENTIFIER` deve corrispondere nell'Info.plist
e negli entitlement di entrambi i target. I valori `app.bloom.ios` e
`group.app.bloom.shared` sono identificatori di sviluppo da configurare,
non attestano alcuna registrazione Apple.

## Test e IPA

Su Mac, scegliere un simulatore disponibile da `xcrun simctl list devices available`:

```sh
xcodebuild -project Bloom.xcodeproj -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
scripts/unsigned-ipa.sh
```

La GitHub Action seleziona un iPhone disponibile, esegue XCTest, archivia app ed
estensione e pubblica **come artifact della run** `Bloom-unsigned.ipa`.
Lo script richiede Xcode e XcodeGen. L'IPA è non firmato: non è installabile
prima della firma. La pipeline non è stata eseguita da questo ambiente Linux.
Nessuna modifica è stata inviata a GitHub automaticamente.

## Gate Signulous / dispositivo reale

Prima di considerare valido il metodo di distribuzione, verificare con Signulous
il supporto alla firma dell'estensione incorporata e a un App Group comune:
la firma deve autorizzare lo stesso gruppo per entrambi i bundle. La sola presenza
del plist degli entitlement non concede il diritto al container condiviso.
Se il servizio rimuove o non autorizza App Groups, questa architettura non supera
la milestone con quella firma: serve una modalità di firma compatibile oppure
una decisione esplicita sull'architettura. Non è stata verificata compatibilità
Signulous e non è stato prodotto un IPA in questa macchina.

1. Firmare l'IPA con app ed estensione; installarlo su iPhone.
2. In Safari condividere un URL HTTP(S), attivare “Salva in Bloom” se necessario.
3. Verificare chiusura del foglio senza errore, aprire Bloom e vedere URL e data.
4. Terminare e riaprire Bloom: URL ancora presente, anche offline.
5. Condividere quando Bloom è già aperta, ritornarvi: nuova cattura presente.
6. Aprire il dettaglio e il link nel browser; controllare testi lunghi e VoiceOver.
7. Registrare device, versione iOS, run CI e risultato della firma/prova.

I test coprono persistenza/reopen, replay senza duplicazione, rifiuto URL non web
e conservazione di catture corrotte. Non sostituiscono Safari e la firma reale.

## URL diretto della build più recente

Dopo una pipeline riuscita su `main`, il job `publish-ipa` crea una release
con il commit della build e l'asset `Bloom.ipa`. I pull request non pubblicano.
L'URL stabile punta all'ultima release pubblicata con successo:

https://github.com/azeroualit-cloud/Bloom/releases/latest/download/Bloom.ipa

Il file è l'IPA non firmato, da passare al servizio di firma. Non è un link
per installare direttamente su iPhone. Se Signulous offre importazione da URL,
incollare questo indirizzo nella relativa funzione; il supporto di tale funzione
non è ancora verificato. Per un repository privato il servizio deve avere accesso
al download: non inserire token nel link. Non viene pubblicata alcuna credenziale.
Una build fallita lascia disponibile la precedente release riuscita.
La pubblicazione è registrata nella run GitHub Actions; il link non è disponibile
prima della prima esecuzione riuscita del job di pubblicazione.
