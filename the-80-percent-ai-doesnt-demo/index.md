# L'80% che nessuno mostra nelle demo: una guida pratica alla parte difficile del software


Una demo che funziona è una promessa che il sistema non ha ancora accettato di mantenere.

In un [articolo precedente]({{< relref "AI Is the Fifth Technology to Make Developers Obsolete.it.md" >}}) ho sostenuto che scrivere codice è, per Pareto, circa il 20% del lavoro, e che l'altro 80% è la parte che l'AI non sostituisce. Quell'80% l'avevo liquidato con una serie di punti elenco, e via. È stata una scorciatoia. Quei punti elenco sono l'intero argomento, e meritano più di una lista.

Ecco quindi la guida pratica. Nove parti del lavoro che non compaiono mai in una demo, ciascuna con il momento in cui torna a presentare il conto. Perché il pericolo non è che l'AI scriva codice cattivo. Il pericolo è che scriva codice che *funziona nella demo*, e la demo è esattamente il posto in cui tutto questo resta invisibile.

## Prima di scrivere una riga

### Capire cosa serve davvero, non cosa è stato chiesto

Un cliente chiede un pulsante che esporta il report in Excel. Un agente costruisce un pulsante che esporta il report in Excel. Sono tutti contenti, finché non scopri che quello che gli serviva davvero era riconciliare quel report con il sistema contabile, ed Excel era solo l'unico strumento che sapeva usare per farlo. Il pulsante non è mai stato il requisito. Era l'ipotesi di soluzione del cliente, ripetuta come se fosse un bisogno.

È il primo e il più grande degli scarti, ed è quello in cui l'AI è messa peggio, perché l'agente non ha modo di sapere ciò che non è stato detto. Costruisce, fedelmente e in fretta, la cosa sbagliata. Il primo compito di uno sviluppatore non è scrivere l'export. È chiedere "cosa ci farai con questo file una volta che ce l'hai?", e accorgersi che la risposta cambia tutto.

### Modellare un dominio che sopravviva a cinque anni

Il modello dati è l'unica decisione da cui non puoi uscire con un refactoring a basso costo. Tutto il resto, la UI, gli endpoint, la logica di business, lo riscrivi in un weekend. Lo schema no, perché quando ti accorgi che è sbagliato ha già dentro un milione di righe e quattro sistemi che ci leggono.

Un agente ti darà un modello perfettamente ragionevole per la funzionalità che hai descritto. Il problema è che il modello deve sopravvivere alla funzionalità *successiva*, quella che nessuno ha ancora nominato, quella che trasforma "un utente ha un indirizzo" in "un utente ha molti indirizzi, in molti paesi, alcuni dei quali non validi ma storicamente significativi". Una demo non ti dice mai quali delle tue tabelle reggono il peso. Lo scopri il giorno in cui una funzionalità spacca il modello a metà, e ti ritrovi con i due pezzi in mano.

### I casi limite che non sono nelle specifiche

La specifica descrive il percorso felice, perché il percorso felice è l'unico che qualcuno ha immaginato mentre la scriveva. Non menziona la lista vuota, l'invio duplicato, l'utente il cui fuso orario non esiste legalmente, il nome con l'apostrofo, il file tecnicamente valido e semanticamente folle.

Queste cose non sono nei requisiti perché nessuno ci ha pensato, e un agente, a cui chiedi di implementare i requisiti, non ci penserà nemmeno lui. La specifica è il pavimento, non il soffitto. L'abilità sta nel sapere che la metà interessante del lavoro comincia esattamente dove finisce il documento.

## Dove la produzione si rompe davvero

### Sicurezza: la parte invisibile finché non lo è

Autenticazione, autorizzazione, validazione degli input, threat modeling. Il codice generato è, quasi sempre, *sintatticamente* sicuro: parametrizza la query, fa l'hash della password. È molto meno spesso *strutturalmente* sicuro, perché la sicurezza non è una proprietà di una riga di codice. È una proprietà di come l'intero sistema gestisce qualcuno che sta attivamente cercando di romperlo.

L'agente non modella un avversario a meno che tu non glielo dica, e sai di doverglielo dire solo se ci sei già finito sotto. Il CSV con un carattere inatteso che evade un contesto tre livelli più in basso. L'endpoint che controlla l'autenticazione ma dimentica l'autorizzazione, così qualunque utente loggato può leggere i dati di qualunque altro cambiando un numero nell'URL. Niente di tutto questo compare in una demo, perché in una demo nessuno ti sta attaccando.

### Prestazioni sotto carico reale

Tutto è veloce con tre utenti e cento righe. La demo è sempre veloce. È questa la trappola.

La query N+1 che parte una volta per ogni elemento di una lista è invisibile finché la lista non ha diecimila elementi. L'indice mancante non conta nulla finché la tabella non è abbastanza grande da far durare otto secondi la scansione completa, e le richieste cominciano ad accumularsi una dietro l'altra. La cache che rendeva tutto più rapido diventa la cosa che serve dati stantii al tuo cliente più importante. "Veloce sulla mia macchina" è una misura presa nelle condizioni più favorevoli che esisteranno mai, e la produzione è il posto in cui quelle condizioni finiscono.

### Coerenza dei dati quando le cose vanno storte

Due richieste arrivano nello stesso istante ed entrambe decidono che il posto è disponibile. Un pagamento va a buon fine ma la scrittura che lo registra va in timeout, così il cliente viene addebitato per qualcosa che il sistema giura non abbia mai comprato. Un retry, servizievole, applica due volte l'operazione che stava ritentando.

È la categoria che prima o poi va storta, perché "prima o poi" è solo un altro modo di dire "su larga scala, nel tempo". Il codice generato gestisce il caso in cui tutto va a buon fine nell'ordine giusto. Tenere insieme un sistema quando due cose succedono nello stesso momento, o quando il terzo passo fallisce dopo che i primi due hanno fatto commit, è una disciplina diversa, ed è una di quelle per cui devi progettare deliberatamente, perché la demo non la farà mai, mai emergere.

## La coda lunga della responsabilità

### Osservabilità e debugging

A due mesi dalla messa in produzione, il tuo cliente più importante segnala un bug. Succede "a volte". Non riesci a riprodurlo. Nei log non c'è niente, perché nessuno ha aggiunto la riga di log che l'avrebbe catturato, perché nella demo non c'era niente da catturare.

Non puoi sistemare ciò che non vedi, e il codice generato va in produzione senza occhi. Strumentazione, logging strutturato, tracce, la briciola di pane che ti permette di ricostruire cosa ha fatto davvero una richiesta alle 2 di notte di sabato: niente di tutto questo è una funzionalità che qualcuno mostra in demo, quindi niente di tutto questo viene costruito fino al giorno in cui daresti qualsiasi cosa per averlo già.

### Manutenibilità: il codice si legge cento volte più di quanto si scriva

Un agente risponde a una domanda e poi tace sul *perché*. Il codice che produce è spesso pulito, ma non porta con sé alcuna memoria della decisione che c'è dietro: perché questo approccio e non quello ovvio, quale vincolo ha reso necessario il ramo brutto, quale riga non devi toccare mai.

Quel silenzio non costa nulla il primo giorno e costa tutto il giorno in cui qualcun altro deve modificarlo. Il software si legge molto più spesso di quanto si scriva, e la maggior parte di quella lettura è qualcuno che cerca di modificare in sicurezza una cosa che non ha costruito lui. Il codice ottimizzato per essere *generato* non è lo stesso del codice ottimizzato per essere *vissuto*, e la differenza non compare finché non arriva la seconda persona.

### Integrazione con sistemi le cui regole non sono scritte

C'è sempre un sistema legacy. La sua API è documentata peggio di come si comporta, i suoi vincoli reali non sono scritti da nessuna parte, e l'unico modo per impararli è violarne uno e leggere l'errore. Il campo nominalmente opzionale che però rompe tutto a valle quando è vuoto. L'endpoint che restituisce `200 OK` con un fallimento nel body. Il rate limit non documentato che scopri sbattendoci contro in produzione.

Questa parte del lavoro è archeologia, non ingegneria, e un agente può lavorare solo su ciò che è scritto. Le regole non scritte, quelle che vivono nella testa di un collega senior, o nella testa di nessuno, sono esattamente ciò di cui è fatta l'integrazione.

## Lo schema sotto la superficie

### Perché niente di tutto questo si vede in tempo

Guarda le nove voci e il tratto comune è evidente. Ognuna è invisibile in demo, invisibile il primo giorno, e costosa al secondo mese. Non è una coincidenza. È la definizione. Sono esattamente i problemi che *non possono* emergere presto, perché hanno bisogno di scala, tempo, un avversario, un secondo sviluppatore o un fallimento per rivelarsi.

È questo che intendevo dicendo che l'AI non cambia la linea temporale. Le precedenti ondate di tecnologia "gli sviluppatori sono obsoleti" fallivano in fretta: nel giro di mesi era evidente che la cosa non scalava, e chiamavi qualcuno. L'AI è diversa e più pericolosa proprio qui. Non fallisce in fretta. Ti lascia costruire molto, molto più in là prima che le crepe si mostrino. Pubblichi, cresci, porti dentro utenti veri, e *poi* l'80% arriva tutto insieme, dentro un sistema che nessuno ha davvero progettato.

## Per cosa stai pagando davvero uno sviluppatore

Torniamo alla frase del primo articolo: uno sviluppatore senior non viene pagato per scrivere `if/else`. Viene pagato per aver visto cosa succede dopo l'`if/else`.

Le nove sezioni qui sopra non sono in realtà nove abilità separate. Sono una sola abilità con nove travestimenti: la capacità di anticipare il fallimento in un sistema che non esiste ancora. Di sentire, mentre la demo sta ancora applaudendo, dove farà male tra due mesi. Quell'istinto è l'intero lavoro, ed è l'unica cosa che una demo è strutturalmente incapace di mettere alla prova, perché una demo ti mostra sempre e solo il 20%.

L'AI è straordinaria sul 20%. È davvero trasformativa lì, e far finta di niente sarebbe disonesto. Ma non fornisce l'80%. Lo amplifica nelle persone che già lo possiedono, e ne rende l'assenza catastrofica, e veloce, nelle persone che non ce l'hanno.

Quindi, la prossima volta che una demo sembra magia, fai l'unica domanda che conta: non "funziona?" ma "cosa succede due mesi dopo che ha funzionato?". La risposta a quella domanda è ancora, per ora, una persona.

