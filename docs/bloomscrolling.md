# Bloomscrolling — incremento 8

Obiettivo: riscoprire i propri contenuti senza cercarli nella Library.
Due tab native: Libreria (flussi esistenti) e Riscopri (feed personale verticale).
Nessun backend, scoperta esterna, AI o modifica dello schema in questo incremento.

Wireframe iPhone/iPad, Dynamic Type e colori semantici di sistema:

    Riscopri                         [Nuovo giro]
    Contenuti dalla tua libreria. Fino a 30 per giro.
    [formato · raccolta]
    [titolo e data di salvataggio]
    [estratto testo / anteprima foto / indirizzo / nome file]
    [Apri contenuto]       [Archivia]
    ... scroll verticale, card a larghezza leggibile (max 680 pt)
    Fine del giro → [Nuovo giro]
    [Libreria]                       [Riscopri]

Selezione locale e ripetibile nello stesso giorno: ordine pseudocasuale stabile
basato su ID e giorno UTC, preferendo varietà rispetto ai due elementi precedenti
(formato, raccolta e host). Recenti e vecchi contenuti hanno la stessa possibilità
di comparire. Nessun duplicato nello stesso giro; massimo 30 elementi, solo attivi.
Nuovo giro / pull to refresh cambia il seme della sessione e può riproporre elementi.
Non registra letture o interessi, né promette personalizzazione appresa.

Query SwiftData comune allo store esistente. Nessun accesso ai byte degli allegati
nel selettore; thumbnail foto caricate solo dalle card materializzate e ridotte
con lo stesso componente del viewer. Nessuna pagina web caricata prima di Apri.
Apri usa ContentViewer esistente, tornando al feed con Back. Archivia salva con
LinkStore: l'elemento scompare solo dopo il salvataggio, errore con stato recuperabile.
Ripristino sempre disponibile nella Libreria → Archivio. Nessuna cancellazione.
Vuoto: spiegazione e pulsante per passare alla Libreria; fine giro con nuovo giro.

Gate automatici: ordinamento stabile indipendente dall'ordine di input, esclusione
archiviati, unicità/limite, varietà quando possibile, nuovo giro e tutti i test
esistenti più archive IPA. Verifica visiva/touch su dispositivo firmato richiesta:
passaggio tab, scroll, foto e testo lungo, apri/torna, archivio/ripristino, libreria
vuota, riavvio. CI non certifica il layout né i player social sul dispositivo.
