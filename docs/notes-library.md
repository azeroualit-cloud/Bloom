# Libreria di note — build 13

Bloom usa note con titolo e testo Markdown facoltativi, fino a dieci link/file
allegati e tag manuali multipli. Basta un titolo, un testo o un allegato per
salvare. Nessuna selezione tag è obbligatoria: “Da specificare” è la vista delle
note senza tag, non un tag persistente. I tag iniziali sono Salute, Alimentazione,
Studio, Lavoro, Progetti, Casa, Tecnologia, Comunicazione, Dating, Psicologia,
Viaggi. I nuovi nomi devono essere una parola (massimo 40 caratteri).

Il catalogo riusa gli identificatori delle precedenti raccolte, mantenendone
nomi e appartenenze. I nomi precedenti di più parole restano validi. Rinomina non
cambia le appartenenze; eliminazione rimuove soltanto quel tag. Le note e gli
altri tag restano intatti. L’assegnazione multipla sostituisce i tag della
selezione con quelli scelti, con conferma esplicita.

La homepage mostra Recenti e sezioni per tag (incluse le note non classificate).
Ogni sezione ha Vedi tutte; Tutte le note mostra la lista completa. Ricerca su
titolo, testo, link e nomi dei tag; filtro formato, archivio e ordinamento.
Le card hanno lo stesso contenitore: preview, titolo, estratto e tag. Il poster
apre il link; titolo e testo aprono la nota. I video YouTube/TikTok/Reels tentano
un Universal Link con universalLinksOnly; soltanto se iOS non trova un gestore
si apre WebKit. Questo passaggio va verificato sull’iPhone firmato con le app
installate. Non vengono istanziati player nella homepage.

Le preview vengono recuperate con LinkPresentation quando una card entra nella
Libreria, in una coda seriale con deduplica per ID. Un insuccesso non viene
ritentato prima di 24 ore. Cache locale separata, nessuna AI/OCR/classificazione.
Un sito senza preview resta identificabile dal dominio e dall’icona.

Gli screenshot locali possono essere aperti con zoom e doppio tap. Inquadratura
salva quattro margini normalizzati, applicati anche alla homepage; originale e
hash dei byte restano intatti. Mostra originale azzera i margini. Il primo file
di una nuova nota senza link è conservato come allegato principale, così immagini
e documenti mantengono viewer e funzioni locali.

Backup v2 include tag, testo, link multipli, file e inquadratura. Legge ancora
backup v1; i backup v2 richiedono questa build o successiva. Le note nuove si
uniscono per ID: note distinte con lo stesso video non vengono perse. I vecchi
contenuti conservano la deduplica per URL/hash. Le cache web rigenerabili non
sono incluse. Limite note: 25 MB complessivi, dieci allegati. Limiti backup
complessivi invariati.

Test: migrazioni precedenti, note complete con due tag e più allegati, backup e
riapertura, rimozione di un tag senza perdita degli altri, stato non classificato,
validazione prima della mutazione, riconoscimento domini social, UI di cattura e
organizzazione. Test su dispositivo firmato e compatibilità dei siti non sono
sostituiti dai test del simulatore.
