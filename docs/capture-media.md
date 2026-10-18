# Capture — incremento 5

Obiettivo: salvare testi, immagini da Foto e documenti da File nella stessa Library,
con raccolte, ricerca e archivio già presenti. Link e percorsi social restano quelli
verificati dall'utente. Nessun nuovo tentativo sulla condivisione YouTube.

Wireframe: menu + → Link / Testo / Foto / File. Link riusa l'editor attuale; Testo
apre titolo facoltativo e corpo multilinea con Annulla/Salva. Foto/File aprono i
selettori di sistema. Durante lettura/importazione la Library mostra avanzamento
indeterminato e Annulla; conferma solo dopo save. Errore visibile; l'originale non
viene modificato. File massimo 25 MB, singolo elemento per importazione.

Dati: il modello storico CapturedLink conserva nome e proprietà per compatibilità.
Si aggiungono solo campi opzionali: contentKind (nil = link precedente), textContent,
fileName, contentType, attachmentByteCount, contentFingerprint e attachmentData
con @Attribute(.externalStorage). SwiftData gestisce database e payload locale;
nessuna dipendenza dai file originali dopo il save. Hash SHA-256 per duplicati esatti,
con prefisso per distinguere tipo contenuto. Nessun server Bloom. Il selettore Foto può dover ottenere un originale iCloud prima dell’importazione.
Le letture dei file avvengono fuori dal main actor, con accesso security-scoped e
lettura limitata anche se la dimensione del file cambia. Il picker Foto usa
FileRepresentation per evitare di caricare foto arbitrariamente grandi in memoria.

Viewer minimo: testo selezionabile, immagine ridimensionata a massimo 2048 pixel,
file tramite Quick Look su copia temporanea privata (nessun percorso proveniente
liberamente dall'input). Raccolte, note e archiviazione comuni a tutti i contenuti.
Un allegato mancante/non decodificabile mostra errore, senza crash o finta anteprima.
Non è il viewer definitivo per i social: quello resta un incremento separato.

Gate: test persistenza payload e testo dopo reopen, deduplica, limiti e lettura file,
ricerca del corpo del testo, migrazione dagli schemi precedenti, build e pubblicazione.
Sul dispositivo: aggiornare senza disinstallare, verificare i link esistenti, importare
foto/PDF/testo, riaprire offline, leggere e organizzare, annullare importazione.
File esterni e foto restano gestiti dal sistema e non sono mai eliminati da Bloom.
