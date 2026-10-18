# Decisione architetturale dopo la prova di firma

La build 2 installata restituiva nil dal lookup del container di
`group.app.bloom.shared`, pur dichiarando lo stesso gruppo in app ed estensione.
Non è stato possibile ispezionare l'IPA dopo la firma. Non è stata dimostrata
un'incompatibilità generale di Signulous; è stato dimostrato il mancato accesso
al gruppo in quella installazione.

L'utente ha deciso di rimuovere il requisito App Groups, senza coinvolgere il
supporto del signer. Dalla build 3: SwiftData nel container privato, nessuna Share
Extension, ingresso manuale, App Intent per Comandi Rapidi e URL scheme.

La verifica della firma di un gruppo non è più un prerequisito di Bloom. Il vecchio
script audit-signed-ipa, specifico per app con estensione e App Groups, è rimosso.
Non vengono cancellati o spostati database esistenti. Il nuovo store non legge il
vecchio container; un recupero futuro richiederebbe accesso e importazione espliciti.

Gli errori del database privato conservano diagnostica copiabile e retry. Non
riportare il vecchio errore App Groups come problema attuale senza verificare
versione e commit dell'app installata.
