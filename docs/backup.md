# Backup locale — incremento 9

Libreria → menu Raccolte e guida → Backup locale.

    Backup locale                               [Fine]
    [Esporta libreria] → preparazione → Salva in File → esito
    [Importa backup] → selettore nativo → verifica → anteprima
    Anteprima: data, contenuti, raccolte, allegati, archiviati
    [Aggiungi alla libreria] → un solo salvataggio → riepilogo

JSON versionato Bloom v1, con ID, date, URL, testi, metadati, stato archivio,
raccolte e allegati incorporati (base64). Cookie e dati del browser esclusi.
File non cifrato: l’utente sceglie dove conservarlo. Nessun invio a server.
Max file 100 MiB, payload complessivo 60 MiB, 10.000 elementi/2.000 raccolte;
limite 25 MiB per testo/allegato come per la cattura. Se l’archivio supera i limiti,
nessun export parziale: errore esplicito. Nessuna cancellazione dell’originale.

Anteprima senza scritture; import solo su azione esplicita. Merge in un contesto
SwiftData dedicato con autosave disattivato e un solo save: rollback su errore.
I record esistenti vincono in caso di stesso ID, URL esatto o fingerprint del
contenuto. Nessuna sovrascrittura di note, titolo, raccolta o stato esistenti.
Raccolte unite per ID o nome normalizzato; riferimenti mancanti, ID duplicati,
formati futuri o contenuti invalidi rifiutati prima di scrivere. Fingerprint
ricalcolati dai dati, mai accettati dal file. Reimportazione idempotente.

Busy/annullamento visibili per lettura e preparazione; niente successi anticipati.
Errori inline persistenti; annulla anteprima non modifica nulla. Export annullato
non è un successo. Schermata riusa document picker nativo e controlli Form.
Nessuna modifica allo schema né dipendenza da App Groups, cloud o firma.

Gate: export → decode → merge in nuovo store → riapertura con tutti i formati,
archivio e raccolte; reimport senza duplicati, conflitti con dati attuali preservati,
file corrotto/versione futura/riferimenti mancanti rifiutati, limiti, salvataggio
atomico. Test iOS e archive IPA. Su dispositivo firmato verificare File → esporta,
riapertura anteprima, annullamento e merge. CI non verifica il provider File iOS.
