# Library — incremento 4

Scopo: ritrovare e organizzare i link già catturati, mantenendo archivio privato,
Comandi Rapidi per Instagram/TikTok/Pinterest e copia/incolla per YouTube.
Importazione di testi, immagini e file e Unified Viewer restano incrementi successivi.

Flussi: ricerca su titolo, URL, note e nome raccolta; filtro Attivi/Archivio e
Tutte/Senza raccolta/raccolta specifica. Dettaglio → Modifica → titolo, note,
raccolta → save atomico → UI aggiornata. Annulla non modifica il contenuto.
Creare una raccolta è un'azione esplicita separata. Nomi vuoti o duplicati
ignorando maiuscole/accenti sono rifiutati. Rinominare aggiorna i riferimenti;
eliminare una raccolta richiede conferma e conserva i contenuti senza raccolta.
Archivia/Ripristina è reversibile, senza eliminazione dei contenuti. Il comando
Condividi conserva la deduplicazione esatta, anche dei link archiviati.

Wireframe: titolo Bloom e toolbar Raccolte/+; ricerca; selettore Attivi/Archivio;
lista con titolo (dominio come fallback), URL, raccolta/data, eventuale nota.
Un errore di salvataggio non chiude l'editor. Stato vuoto distinto da nessun risultato.
Dettaglio mostra URL, note, raccolta, data, Apri nel browser, Modifica e Archivia.
Controlli nativi, Dynamic Type e colori semantici; nessuna UI definitiva di feed.

Dati: proprietà opzionali title/notes, isArchived=false e relazione opzionale a
LinkCollection aggiunti a CapturedLink. Lo store esistente viene aperto con
migrazione leggera automatica SwiftData. Test da schema precedente → nuovo,
stessi ID/URL/data; nessun reset o cancellazione in caso di errore. Relazione
raccolta→link con deleteRule nullify. Tutte le mutazioni passano da LinkStore,
con save e rollback in caso di errore. Ricerca locale in memoria proporzionata
alla libreria iniziale; i filtri sono condivisi tra UI e test.

Gate: test persistenza, migrazione, ricerca, duplicati di raccolte, rinomina,
eliminazione non distruttiva, archivia/ripristina; build e release. Sul dispositivo:
aggiornare senza disinstallare, verificare vecchi link, modificare e ricercare,
creare/rinominare/eliminare raccolta, archivia/ripristina, riaprire, e riprovare
il comando sociale esistente. Nessun nuovo tentativo richiesto su YouTube.
