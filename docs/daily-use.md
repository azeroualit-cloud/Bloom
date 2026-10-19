# Release 10 — uso quotidiano

Un solo incremento: cattura → riconoscimento → organizzazione → riscoperta.
Schema invariato, archivio privato e backup v1 compatibili.

Libreria: filtri raccolta/formato condivisi con Riscopri, foto in anteprima,
estratti dei testi limitati, titolo facoltativo dei link in cattura. Recupero del
titolo web esplicito (singolo o selezione, max 10 per operazione): rete con timeout,
annullamento, esito parziale e nessuna sovrascrittura di un titolo già presente.
Nessuna richiesta web provocata dallo scroll della libreria.

Seleziona → Seleziona visibili / tocchi multipli → raccolta, archivia/ripristina,
recupera titoli → singolo save per le operazioni di organizzazione. Errori lasciano
la selezione disponibile. Cambiare filtro elimina dalla selezione i contenuti
nascosti. Raccolte eliminate e selezioni mancanti danno un errore prima di mutare.
Nessuna cancellazione permanente introdotta.

Cattura link/testo: raccolta e creazione raccolta nello stesso foglio, titolo link,
Apri dopo il salvataggio. Duplicati: apri l'esistente senza cambiarne metadati.
Foto/file: scegli raccolta → selettore nativo → import con raccolta atomica →
conferma con Apri contenuto. Un retry conserva destinazione e payload; se la
raccolta scompare, annulla e scegli nuovamente. Nessuna modifica alla cattura
YouTube via copia/incolla o ai Comandi Rapidi già verificati.

Riscopri: filtri per formato e raccolta. Nuovo giro esclude i contenuti proposti
nei giri precedenti della sessione, fino a esaurimento; poi offre Ricomincia.
La cronologia si azzera al cambio filtri/giorno o al riavvio dell'app. Nessuna
promessa di letture misurate, AI o scoperte esterne.

Wireframe nativo:
    Bloom        [Filtri/strumenti] [Seleziona] [+]
    Libreria | Archivio       [Filtri attivi / conteggio]
    foto/icone · titolo · estratto · raccolta · data
    selezione → [visibili] [raccolta] [archivia/ripristina] [titoli]
    + link/testo → input, titolo, raccolta, apri → salva → viewer
    + foto/file → raccolta → selettore → esito → apri
    Riscopri → [Filtri] [Nuovo giro] → feed → esaurito → Ricomincia

Controlli SwiftUI nativi, Dynamic Type, menu e azioni con etichette, thumbnail
ridotte, controlli disposti verticalmente sui layout stretti. Test su filtri,
azioni multiple/rollback preventivo, cattura organizzata/duplicati, metadati
con provider simulato e round senza ripetizioni, più regressioni/IPA. Un test UI
su store in memoria (solo DEBUG) attraversa cattura testo/raccolta, apertura,
selezione, archivio/ripristino e Riscopri. Player,
richieste reali ai social e UI sul dispositivo firmato richiedono una sola prova
integrata dell'utente dopo la release.
