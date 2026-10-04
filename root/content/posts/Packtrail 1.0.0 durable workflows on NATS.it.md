---
date: '2026-10-04T09:00:00+02:00'
title: 'Packtrail 1.0.0: workflow durevoli solo con NATS'
tags: ["go", "nats", "workflows", "open-source", "packtrail"]
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
disableHLJS: true
disableShare: false
hideSummary: false
searchHidden: true
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
featuredImage: "/images/packtrail002.png"
images: ["/images/packtrail002.png"]
code:
  maxShownLines: -1
cover:
    image: "/images/packtrail002.png"
    alt: "Packtrail 1.0.0: workflow durevoli solo con NATS"
    caption: ""
    relative: false
    hidden: false
---

Quando ho scritto di Packtrail per la prima volta, il discorso stava in una frase: un motore di workflow durevoli che non ha bisogno di altro che NATS. Niente database, niente coordinatore, niente una seconda cosa da tenere in vita.

Oggi quella frase riceve un numero di versione. **Packtrail 1.0.0 è uscito.**

## La seconda volta

Ecco la parte che di solito non metto in un post di rilascio: la 1.0.0 non è la prima bozza con un tag più elegante. È il secondo tentativo.

La prima versione funzionava. Mi ha anche insegnato, un bug alla volta, dove un motore durevole si rompe davvero. Una cancellazione che arriva nel momento sbagliato e si perde. Un fan-out che si parcheggia proprio mentre finisce l'ultimo ramo. Un segnale che arriva prima del passo che lo aspetta. Uno start che va in crash a metà e lascia un'esecuzione a metà.

Ognuno di questi è diventato un test di regressione. Poi ho fatto una cosa un po' scomoda: ho scritto la lista e sono ripartito da una cartella vuota, con una regola. Il nuovo motore doveva conservare ogni lezione, e poteva buttare ogni meccanismo nato per aggirare quei problemi.

Alcune toppe sono semplicemente sparite. Lease, watchdog e cicli di re-drive esistevano perché lo stato viveva in memoria e poteva essere sbagliato. Nel nuovo design una decisione è un messaggio aggiunto a un log ordinato con un controllo sulla sequenza attesa, quindi un secondo scrittore viene respinto da NATS stesso. Quando in memoria non c'è niente da recuperare, non c'è niente da sorvegliare.

Questo è lo spirito della 1.0.0: meno parti in movimento, e quelle rimaste sono più facili di cui fidarsi.

## Cos'è Packtrail

Se lo incontri per la prima volta: Packtrail è un motore di workflow dove il workflow sono **dati**, non codice. Dichiari un grafo in YAML o in struct Go, e il motore lo interpreta.

- **Event-sourced.** Ogni esecuzione è un log ordinato di eventi sul proprio subject. Stato, snapshot, timer e indice di visibilità sono tutti derivati da lì. Viaggi nel tempo, fork, replay e audit arrivano gratis, perché la storia è la fonte di verità.
- **Un grafo dichiarativo.** Task, scelte, fan-out e join, attese per l'intervento umano, mappe dinamiche, sottoflussi, interruzioni e instradamento dei fallimenti per la compensazione. Nessuna regola di determinismo per il tuo codice, perché il tuo codice non viene mai rieseguito.
- **Worker in qualsiasi linguaggio.** Un task è un job su un subject, e il worker risponde con un comando su un piccolo protocollo JSON versionato. L'SDK Go è incluso, ma nulla impedisce di scrivere un worker in qualsiasi linguaggio che parli NATS.
- **Agnostico.** Niente agenti, LLM o token nel core. Un "agente" è solo un worker. I budget sono contatori generici.
- **Solo NATS.** Stream JetStream per il log, schedule di messaggi per timer durevoli e cron, KV e object store per tutto il resto.

Un piccolo flusso si presenta così:

```yaml
name: review
nodes:
  - id: draft
    type: task
    kind: writer
    timeout: 1m
    retry: {max_attempts: 3, backoff: exponential}
    next: check
  - id: check
    type: choice
    rules:
      - {when: "results.draft.score >= 8", to: approve}
      - {default: true, to: draft}
  - id: approve
    type: await
    signal: approval
    timeout: 48h
    next: publish
  - {id: publish, type: task, kind: publisher}
start: draft
```

Una bozza viene rifatta finché non ottiene un punteggio sufficiente, poi attende fino a due giorni l'approvazione di una persona, poi viene pubblicata. Il motore può andare in crash in mezzo a uno qualsiasi di questi passi e l'esecuzione riprende quando torna.

## Cosa significa 1.0.0

Una `1.0.0` è una promessa, quindi ecco cosa prometto davvero.

Il formato dei flussi, il protocollo dei worker e il layout del log degli eventi sono i contratti. Sono versionati, documentati e coperti da una suite di conformità, così un client o un worker scritto in un altro linguaggio può verificarsi sugli stessi casi che il codice Go supera. I flussi sono immutabili e versionati tramite hash, e un'esecuzione mantiene sempre la versione con cui è partita, quindi rilasciare un nuovo flusso non cambia mai il significato di uno già in corso.

La consegna è at-least-once, e preferisco dirlo chiaramente piuttosto che nasconderlo. Un task può girare due volte dopo un crash, quindi gli effetti collaterali vanno resi idempotenti, oppure puoi attivare la cache dei risultati. Il motore stesso è exactly-once per decisione: duplicati e risultati obsoleti vengono assorbiti dal fold.

## Fatto per essere rotto

La parte del progetto di cui vado più fiero non è una funzionalità. È quanto i test insistono sul fallimento.

La suite gira contro un vero `nats-server` embedded, non contro dei mock. Ci sono test che uccidono il motore a ogni singolo passo di un flusso, riavviano NATS in mezzo a un'esecuzione e sostituiscono tutti i motori ogni 700 millisecondi sotto carico, mentre un terzo dei flussi fa fan-out. In quello scenario, tremila esecuzioni si completano tutte. Diecimila esecuzioni possono restare parcheggiate su un'attesa da 24 ore mentre il motore si riavvia, e poi svegliarsi e finire quando ricevono il segnale.

Quando un'esecuzione ha eventi che il dispatcher non riuscirà mai a processare, viene messa in quarantena invece di bloccare la sua partizione, e una volta risolta la causa puoi rieseguire ciò che era stato saltato. Le interruzioni transitorie non mettono mai nulla in quarantena: il dispatcher semplicemente aspetta.

## Abbastanza veloce

L'ho misurato, con la solita avvertenza: una sola macchina da portatile, con server, motore, worker e client nello stesso processo.

Su un flusso lineare di tre passi gestisce circa 1.500 esecuzioni al secondo, con circa 0,9 millisecondi di latenza per passo. Su un cluster simulato a tre nodi con replica siamo intorno a 1.000 esecuzioni al secondo.

## Gli strumenti intorno al motore

Un motore durevole in cui non puoi guardare dentro serve a poco alle tre di notte, quindi CLI e dashboard fanno parte del rilascio.

```sh
packtrail run -flows flows/ &
packtrail start review -input '{"topic":"NATS"}' -wait
packtrail history <exec>          # ogni evento
packtrail get <exec> -seq 12      # stato subito dopo l'evento 12
packtrail fork <exec> 12          # continua da lì in una nuova esecuzione
packtrail rerun <exec> draft      # riesegue un nodo (e ciò che segue)
```

Puoi guardare lo stato di un'esecuzione in qualsiasi punto della sua vita, fare un fork da lì con lo stato modificato, o rieseguire un singolo nodo. Siccome il log è la verità, niente di tutto questo richiede macchinari speciali. `packtrail-ui` aggiunge una dashboard con il grafo, la timeline e lo stato a ogni evento, per ogni namespace dell'account NATS. Non ha autenticazione e di default ascolta solo su loopback, quindi consideralo uno strumento di debug.

## Provalo

Servono Go 1.26 e NATS Server 2.12 o successivo con JetStream abilitato.

```sh
docker run --rm -p 4222:4222 nats:2.14.2 -js
go get github.com/henomis/packtrail
go install github.com/henomis/packtrail/cmd/packtrail@latest
go install github.com/henomis/packtrail/cmd/packtrail-ui@latest
```

Il repository contiene esempi eseguibili per human in the loop, ricerca parallela con reducer, map-reduce, retry e timeout, viaggi nel tempo e fork, un ciclo di tool in stile agente, sottoflussi, trigger cron e su messaggi. La documentazione completa, incluso il protocollo dei worker e il riferimento sul log degli eventi, è sul [sito di Packtrail](https://simonevellei.com/packtrail/), e il codice è su [GitHub](https://github.com/henomis/packtrail).

## E poi

Come Phero, Packtrail è un progetto di una persona sola, fatto da una scrivania in Italia, e la `1.0.0` è un inizio. Voglio vedere come si comporta su cluster reali, sapere dove la documentazione non basta, e trovare il fallimento a cui non ho ancora pensato. Se ci costruisci qualcosa, o lo rompi in modo interessante, apri una issue e raccontamelo.

I workflow durevoli non dovrebbero richiedere una piccola infrastruttura tutta loro. Se usi già NATS, hai già quasi tutto ciò che serve.
