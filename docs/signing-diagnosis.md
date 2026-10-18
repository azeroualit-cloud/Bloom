# Diagnosi App Groups

Il messaggio «Archivio condiviso non disponibile» è emesso prima di aprire
SwiftData: manca la stringa BloomAppGroup nel bundle oppure containerURL non
restituisce il container per quel gruppo. I sorgenti contengono la stringa e
il gruppo atteso; la run #2 preserva i plist. Questo non prova che l'IPA
rifirmato sia autorizzato allo stesso gruppo.

La homepage Signulous dichiara «all possible entitlements» senza documentare
il collegamento di un App Group tra app ed estensione.

Nel codice pubblico di iOS App Signer, commit
`ec11473fba2a693d2638d6225fba1873a961cdbb`, AppSigner/MainView.swift,
sezione Generate entitlements.plist, gli entitlement sono ricavati dal
provisioning profile (oppure da un file custom nell'app desktop).
ProvisioningProfile.swift aggiorna application-identifier quando necessario,
ma non implementa esplicitamente la rimappatura degli altri wildcard.
Questa è evidenza sul tool pubblico, non sul backend privato di Signulous.

Fonti:
- https://github.com/DanTheMan827/ios-app-signer/blob/ec11473fba2a693d2638d6225fba1873a961cdbb/AppSigner/MainView.swift#L886
- https://github.com/DanTheMan827/ios-app-signer/blob/ec11473fba2a693d2638d6225fba1873a961cdbb/ProvisioningProfile.swift#L111

Non è dimostrato che l'assenza di firma nell'IPA iniziale sia la causa: una
firma ad hoc non può concedere un App Group non autorizzato dal profilo finale.
Non modificare il database e non cancellare dati per trattare questo errore.

## Verifica sul risultato della firma

Scaricare l'IPA dopo la firma dal servizio, se disponibile. Su macOS:

```sh
python3 scripts/audit-signed-ipa.py /percorso/Bloom-firmato.ipa
```

Il controllo verifica la firma strutturale con codesign, poi confronta per app
ed estensione: gruppo richiesto nell'Info.plist, gruppi negli entitlement firmati
e gruppi nel provisioning profile. Stampa solo identificatori pertinenti,
mai l'intero profilo o UDID. Non certifica installabilità, revoche o accesso
runtime su iPhone: la prova Safari resta necessaria. Un fallimento per symlink
richiede ispezione manuale su macOS, senza estrazione non controllata.

Se il gruppo è assente o diverso, occorre configurare il signer perché assegni
lo stesso gruppo autorizzato ai due bundle e perché BloomAppGroup corrisponda.
Se tutti i controlli passano ma l'errore persiste, verificare che l'IPA analizzato
sia quello installato e acquisire la diagnosi runtime del container su dispositivo.

Lo script non è stato eseguito su un IPA firmato reale: quel file non è disponibile
nell'ambiente. Non sono stati contattati terzi né forniti certificati o credenziali.

## Diagnostica dall'app installata — build 2

Quando l'archivio non si apre, Bloom mostra la fase raggiunta e offre
Riprova apertura, Copia report e Condividi report. Il report riporta versione,
commit, bundle ID e App Group dichiarati da app ed estensione incorporata,
esito della risoluzione del container e dominio/codice dell'errore.
Non stampa userInfo, descrizioni tecniche dell'errore, percorsi locali,
contenuti della raccolta, UDID o provisioning profile. Non legge entitlement
tramite API private e non dichiara che il gruppo sia autorizzato solo perché
è presente nell'Info.plist. Non modifica, sposta o elimina il database.
La build CI incorpora il proprio commit nel report; una build locale mostra local.

Su iPhone, installare la nuova build firmata, aprire Bloom e premere Copia report.
Incollare il testo nel caso di assistenza. Non è necessario recuperare l'IPA firmato
per raccogliere questa prima diagnosi runtime.
