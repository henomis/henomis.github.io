# Packtrail: workflow durevoli costruiti solo su NATS


Immagina una pipeline di cinque passi. Un agente AI legge una richiesta, altri tre la approfondiscono in parallelo, e alla fine una persona dà l'approvazione. Gira senza problemi per settimane. Poi una notte il processo muore al terzo passo.

Per ripartire, il sistema deve rispondere a due domande. **Dove ero?** Quali passi sono già stati eseguiti, cosa hanno restituito, quali non vanno ripetuti. E **dove sto andando?** Cosa viene dopo il terzo passo, quale ramo prendere, chi sta ancora aspettando un'approvazione.

La prima domanda riguarda la *durabilità*. La seconda riguarda il *workflow*. Packtrail nasce da un'idea sola: queste due risposte devono stare nello stesso posto.

## Vi presento packtrail

Packtrail è un **workflow engine open source per Go** che tiene tutto il suo stato in **NATS**, e da nessun'altra parte. Descrivi il tuo processo come un piccolo grafo, in YAML o in Go. Packtrail lo percorre un passo alla volta e scrive ogni passo su NATS prima di andare avanti. Se un processo crasha, un altro riprende esattamente da dove si era fermato.

Oggi rilascio la versione **0.2.0**. È giovane, è pre-1.0 ed è costruita da una sola persona. Mi piacerebbe fartela conoscere.

- **GitHub**: [github.com/henomis/packtrail](https://github.com/henomis/packtrail)
- **Sito e documentazione**: [simonevellei.com/packtrail](https://simonevellei.com/packtrail/)

## Due metà dello stesso problema

Guardando gli strumenti per i processi durevoli, continuavo a trovarne solo una metà alla volta.

Da una parte ci sono i **motori di durable execution**. Sono bravissimi a rispondere alla prima domanda. Scrivi il processo come codice normale, e il motore registra ogni passo per poterlo rieseguire dopo un crash. Ma il workflow non ha una forma propria: vive dentro funzioni, cicli e `if`. Per sapere cosa fa un processo, leggi il codice. Per sapere a che punto è un'istanza in esecuzione, chiedi al motore di rieseguirla.

Dall'altra ci sono gli **orchestratori di workflow**. Sono bravissimi a rispondere alla seconda domanda. Il flusso è un documento a tutti gli effetti: puoi leggerlo, rivederlo, disegnarlo. Ma spesso arrivano come piattaforme, con server, database e console propri da far girare accanto alla tua applicazione.

Io volevo entrambe le metà in una piccola libreria. È questa la scelta al centro di packtrail, e quasi tutte le altre decisioni discendono da lì.

## Perché engine e workflow devono stare insieme

Quando il motore durevole *possiede* il workflow, migliorano entrambi.

**Il workflow diventa durevole senza sforzo.** Un retry con backoff esponenziale, un fan-out che aspetta tre rami in parallelo, un'approvazione che attende 24 ore: nessuno di questi è un caso speciale. Sono nodi del grafo, e l'engine salva ogni transizione tra l'uno e l'altro. Un crash nel mezzo di un'attesa di 24 ore è un non-evento.

**La durabilità diventa qualcosa che si vede.** Lo stato di un'esecuzione non è un log di replay che solo il motore capisce. È "siamo al nodo `route`, e `triage` ha restituito questo". Una persona può leggerlo. `Resume` riparte da esattamente il nodo che ha fallito, conservando tutti i risultati precedenti. La dashboard disegna il grafo e mostra ogni esecuzione che lo attraversa in tempo reale.

**Gli errori vengono intercettati prima che parta qualsiasi cosa.** Siccome l'intero grafo è noto in anticipo, packtrail lo controlla all'avvio: passi irraggiungibili, regole di routing senza default, refusi nei nomi dei campi. Quando il processo è sepolto nel codice, un percorso rotto come questi spesso resta nascosto fino alla sfortunata esecuzione che lo imbocca.

**Anche il flusso stesso è durevole.** Ogni engine pubblica i grafi dei suoi flussi su NATS all'avvio. Così la definizione del processo vive accanto al suo stato, e qualsiasi strumento collegato a NATS può vedere entrambi senza toccare il tuo codice sorgente.

Ecco come appare. Un agente fa il triage di una richiesta, una regola sceglie la strada e una persona ha un giorno per approvare:

```yaml
nodes:
  - {id: triage, type: task, invoker: agent, target: triage-agent,
     retry: {max_attempts: 3, backoff: exponential}}
  - id: route
    type: choice
    rules:
      - {when: 'results.triage.risk_score > 80', to: escalation}
      - {default: true, to: approval}
  - {id: approval, type: signal, signal_name: approved,
     timeout: 24h, on_timeout: escalation}
```

Non serve conoscere packtrail per leggerlo. E ogni sua riga sopravvive a un crash.

## Una libreria, non una piattaforma

Tenere insieme engine e workflow funziona solo se resta leggero. Altrimenti è solo un'altra piattaforma da gestire.

Per questo packtrail gira **solo su NATS**. Nei miei progetti NATS c'era sempre già, e oggi ha tutto quello che serve sotto un workflow engine: stream durevoli per le code di lavoro, un key-value store con compare-and-swap per lo stato e, dalla versione 2.12, uno scheduler per timer che sopravvivono ai riavvii. Packtrail non aggiunge né database né cluster. Basta `go get` e una connessione che hai già.

Ed è anche per questo che packtrail non parla mai direttamente con i tuoi servizi. Ogni passo passa da un'unica interfaccia:

```go
type Invoker interface {
    Invoke(ctx context.Context, req Request) (Result, error)
}
```

Un agente AI, un'API HTTP, un worker NATS: qualunque cosa colleghi eredita retry, timeout e recupero dai crash. Packtrail si occupa del *workflow* e della *durabilità*. Il *trasporto* resta tuo.

> **Il trasporto è tuo. La durabilità è di Packtrail.**

## Cosa trovi dentro

Un giro veloce, lasciando i dettagli alla [documentazione](https://simonevellei.com/packtrail/docs.html):

- **Cinque mattoncini**: `task`, `choice`, `fanout`, `fanin` e `signal`, abbastanza per pipeline, ricerche in parallelo, routing e approvazioni umane
- **Retry e timeout** per ogni passo, con il backoff pianificato in NATS e non in memoria
- **Rami paralleli** che si ricongiungono quando finiscono tutti, uno qualsiasi o un quorum
- **Persone nel ciclo**: un'esecuzione può aspettare giorni un segnale esterno senza tenere nulla in memoria
- **Lavori lunghi**: i passi lenti vanno su una coda di lavoro durevole e non bloccano mai l'engine
- **Cron, resume, cancel, cronologia e archiviazione** per processi che girano per mesi, non per minuti
- **packtrail-ui**: una piccola dashboard che disegna i flussi e mostra le esecuzioni che li attraversano in tempo reale

## Onesto su dove siamo

Preferisco chiarire le aspettative piuttosto che vendere troppo.

Packtrail è **pre-1.0**. Il modo in cui salva i dati su NATS può ancora cambiare tra una release e l'altra. Richiede un server NATS recente (2.12 o successivo). I passi vengono eseguiti **almeno una volta**, quindi gli effetti collaterali vanno gestiti con attenzione, e packtrail offre una cache dei risultati apposta.

E la scelta centrale ha due facce. Se preferisci esprimere il processo come codice normale, con cicli e condizioni scritti in Go, un motore di durable execution code-first ti sembrerà più naturale, ed è una scelta legittima. Packtrail è per chi vuole *vedere* il proprio processo.

Quello che posso promettere è la cura. Circa 400 test girano contro un **server NATS reale**, non contro dei mock, perché i bug che contano in un sistema così stanno nell'interazione vera con il backend.

## Un progetto in solitaria, fatto in Italia

Dietro packtrail non c'è un team né un'azienda. C'è una persona a una scrivania in Italia. È partito a giugno 2026 ed esiste perché volevo questo strumento e non lo trovavo nella forma che avevo in mente: il workflow e la sua durabilità in un unico posto, su un'infrastruttura che uso già.

Non mi aspetto che sostituisca i grandi engine. Spero però che diventi la scelta naturale per chi usa già NATS e vuole workflow durevoli e visibili senza aggiungere infrastruttura. L'unico modo per arrivarci è con persone che lo provano, lo rompono e mi raccontano cos'è successo.

## Unisciti al viaggio

```sh
go get github.com/henomis/packtrail
```

Poi avvia `nats-server -js` e prova uno dei cinque esempi eseguibili nel repository. Quello dell'approvazione umana è il mio preferito.

- **Lascia una stella** su [GitHub](https://github.com/henomis/packtrail) se l'idea ti piace
- **Leggi la documentazione** su [simonevellei.com/packtrail](https://simonevellei.com/packtrail/)
- **Apri una issue** quando qualcosa ti confonde: per un progetto giovane è il regalo più prezioso

Grazie per aver letto, e buon cammino.

*Simone Vellei, Italia*

