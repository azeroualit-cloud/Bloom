# Bloom — archivio privato, senza App Groups

Decisione richiesta dall’utente: nessuna dipendenza dagli App Groups o dal supporto
del servizio di firma. Resta un’app iOS 17+ SwiftUI/SwiftData, locale, separata da
LifeOS e senza backend. Il database vive in Application Support/Bloom.

Prima slice aggiornata: Safari → Condividi → comando “Salva in Bloom” → azione
nativa Bloom → salvataggio privato → raccolta. Il comando si configura una volta
in Comandi Rapidi. Alternativa: Copia URL → Bloom → Incolla link → Salva.
Il collegamento bloom://capture?url=… è un ingresso alternativo, con validazione
HTTP(S), senza salvataggi di altri schemi o operazioni distruttive.

Wireframe: raccolta nativa con pulsante +. Il foglio Aggiungi link contiene URL,
Incolla link, Annulla e Salva. Errore in linea, input conservato, salvataggio
confermato solo dopo SwiftData.save. Guida Condividi da Safari nella raccolta.
Controlli di sistema, Dynamic Type, colori semantici e spaziature native.

Una cattura valida è persistita prima della conferma. Riapertura e retry non
duplicano lo stesso URL esatto. Query string e frammenti restano invariati:
la deduplicazione semantica è una fase successiva. L’archivio non dipende dal
successo di App Intents o URL scheme: è sempre disponibile l’ingresso manuale.
Non si recuperano o cancellano dati nel vecchio container condiviso; su questo
dispositivo iOS non lo ha mai reso disponibile. Un eventuale recupero futuro
richiederà un’importazione esplicita, senza sostituire il nuovo archivio.

Gate: build/test macOS, IPA aggiornato, avvio sul dispositivo firmato, salvataggio
manuale e riapertura, poi prova dell’azione Comandi Rapidi nel foglio Condividi.
La build non dimostra la registrazione delle azioni sul dispositivo rifirmato.

Dopo questa slice: Capture + Library (testi/immagini/file, raccolte, ricerca),
Unified Viewer, Bloomscrolling, poi estensioni PKMS/lingue/AI/backup.
