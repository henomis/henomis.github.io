---
date: '2026-10-14T09:00:00+02:00'
title: 'Packtrail con gli esempi: sei workflow di tutti i giorni'
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
featuredImage: "/images/packtrail003.jpg"
images: ["/images/packtrail003.jpg"]
code:
  maxShownLines: -1
cover:
    image: "/images/packtrail003.jpg"
    alt: "Packtrail con gli esempi: sei workflow di tutti i giorni"
    caption: ""
    relative: false
    hidden: false
---

La maggior parte del lavoro che ha bisogno di un motore durevole non ha niente di affascinante. È una nota spese in attesa di una firma. Un job che fallisce alle 3 di notte perché un cavo di rete ha starnutito. Un messaggio d'ordine che arriva due volte. Un batch di cui conosci la dimensione solo quando parte.

Sono i problemi che avevo in mente mentre costruivo Packtrail. Ecco sei workflow normalissimi, ognuno basato su un esempio eseguibile del repository, e cosa ci fa Packtrail.

## Una nota spese che aspetta il responsabile

Qualcuno presenta una nota spese da 2.500 euro. La policy aziendale dice che le spese piccole si pagano subito, mentre sopra i 1.000 serve l'approvazione di un responsabile. Il responsabile è in ferie. Durante la settimana il server si riavvia due volte.

```yaml
name: expense
nodes:
  - id: check
    type: choice
    rules:
      - {when: "input.amount > 1000", to: approval}
      - {default: true, to: pay}
  - id: approval
    type: await
    signal: manager-decision
    timeout: 72h
    on_timeout: escalate
    next: route
  - id: route
    type: choice
    rules:
      - {when: "signals['manager-decision'].approved", to: pay}
      - {default: true, to: reject}
  - {id: pay, type: task, kind: payments}
  - {id: reject, type: task, kind: notify}
  - {id: escalate, type: task, kind: notify}
```

Letto dall'alto in basso, è la policy stessa. Il nodo `check` guarda l'importo: fino a 1.000 la nota va dritta a `pay`, sopra aspetta il responsabile. La regola sta nel flow, dove chiunque può leggerla e cambiarla, non sepolta nel codice di qualche worker.

Il nodo `approval` parcheggia l'esecuzione finché non arriva un segnale `manager-decision`. Quando arriva, `route` paga la spesa oppure notifica il rifiuto. Se passano tre giorni in silenzio, il flow smette di aspettare e scala la nota più in alto.

Mentre la nota aspetta non gira niente: nessuna goroutine, nessun processo addormentato. La scadenza di 72 ore è uno schedule di messaggi NATS durevole, quindi il flow va avanti da solo, che il motore sia stato riavviato nel frattempo oppure no. L'unico codice che scrivi è quello che fa davvero qualcosa: pagare e notificare.

## Chiedi a tre, vai con i primi due

Ti servono informazioni da tre fonti: un archivio, una banca dati di riviste, un forum. Una delle tre è sempre lenta. Non vuoi aspettarla, ma non vuoi nemmeno fidarti di una risposta sola.

```yaml
name: research
channels:
  notes:   {reducer: append}
  sources: {reducer: merge}
  cost:    {reducer: sum}
budget: {cost: 10}
nodes:
  - {id: gather, type: fanout, branches: [archive, journals, forums], next: enough}
  - {id: archive,  type: task, kind: source, timeout: 5s}
  - {id: journals, type: task, kind: source, timeout: 5s}
  - {id: forums,   type: task, kind: source, timeout: 5s}
  - {id: enough, type: join, policy: "quorum:2", next: write}
  - {id: write, type: task, kind: writer}
```

Un nodo `fanout` avvia i tre rami in parallelo, e un `join` con policy `quorum:2` va avanti appena due hanno finito. Il ramo più lento viene cancellato, e se il suo risultato arriva in ritardo viene semplicemente ignorato. Poi `write` mette insieme quello che è stato trovato.

La parte bella è come i rami condividono quello che trovano. Ognuno scrive su **canali** con dei reducer: `notes` accoda, `sources` unisce, `cost` somma. Le scritture concorrenti vengono combinate invece di sovrascriversi, quindi niente lock e niente sorprese da "vince l'ultimo che scrive". Un budget sul contatore `cost` ferma l'esecuzione se i rami spendono troppo. I budget sono contatori generici: contano qualunque cosa i worker riportino.

## Contare le parole in una pila di documenti

Il classico map-reduce, con una variante: non sai quanti documenti ci sono finché l'esecuzione non parte.

```yaml
name: wordcount
channels:
  total: {reducer: sum}
  longest: {reducer: append}
nodes:
  - {id: count, type: map, kind: counter, over: input.docs, max_parallel: 4}
```

Questo è tutto il flow. Il nodo `map` esegue un task per ogni elemento della lista in input, al massimo quattro alla volta, e ogni task vede il proprio elemento come `item`. Gli output tornano in ordine, e il passo di reduce non è nemmeno un passo: ogni task aggiunge il suo conteggio a `total` e la sua parola più lunga a `longest`, e il resto lo fanno i reducer.

Sostituisci il conteggio delle parole con il ridimensionamento di immagini, l'invio di fatture o il controllo di una lista di URL, e il flow non cambia.

## Una pipeline piena di worker difettosi

È il mio esempio preferito, perché è una piccola galleria di cose che vanno storte in produzione. Quattro passi in fila, ognuno con la sua policy di retry, e ogni worker che si comporta male a modo suo.

```yaml
name: pipeline
nodes:
  - id: flaky
    type: task
    kind: flaky
    retry: {max_attempts: 5, backoff: exponential, delay: 100ms, max_delay: 2s}
    next: slow
  - id: slow
    type: task
    kind: slow
    timeout: 1s
    retry: {max_attempts: 2, backoff: fixed, delay: 100ms}
    next: typed
  - id: typed
    type: task
    kind: typed
    retry: {max_attempts: 2, backoff: fixed, delay: 100ms}
    output_schema:
      type: object
      required: [total]
      properties: {total: {type: number}}
    next: broken
  - {id: broken, type: task, kind: broken, retry: {max_attempts: 3}}
```

- `flaky` fallisce due volte con "connection reset". La policy di retry aspetta con backoff esponenziale (di nuovo su timer durevoli) e il terzo tentativo va a buon fine.
- `slow` si blocca al primo tentativo. Il timeout di un secondo scatta, il tentativo viene cancellato, e qualunque cosa restituisca dopo viene scartata. Vince il secondo tentativo.
- `typed` restituisce `"forty-two"` dove l'`output_schema` del flow chiede un numero. Una violazione dello schema conta come tentativo fallito, quindi viene ritentato, e la seconda volta restituisce `42`.
- `broken` restituisce un errore permanente: "invalid account number". Nessun numero di tentativi lo risolve, quindi Packtrail non ci prova nemmeno, anche se il nodo ne permette tre. L'esecuzione fallisce, con il nodo e il motivo registrati.

La differenza tra un errore transitorio e uno permanente sembra piccola. È la differenza tra un sistema che si ripara da solo durante la notte e uno che martella un fornitore di pagamenti tre volte con lo stesso IBAN sbagliato.

## Un onboarding che chiama un altro flow

Un nuovo cliente si registra. Prima di mandare l'email di benvenuto bisogna verificarne l'identità, e la verifica è un piccolo processo a sé: controllare il documento, poi aspettare fino a 24 ore un revisore umano, che accetta o rifiuta. Se nessuno lo revisiona in tempo, viene rifiutato.

```yaml
name: onboarding
nodes:
  - {id: identity, type: subflow, flow: verify, input: "input.person", next: verified}
  - id: verified
    type: choice
    rules:
      - {when: "results.identity.verified", to: welcome}
      - {default: true, to: sorry}
  - {id: welcome, type: task, kind: mailer}
  - {id: sorry, type: task, kind: mailer}
```

Il flow `verify` gira come **esecuzione figlia**, con il suo id, il suo log e il suo stato. Lo puoi riusare da qualsiasi altro flow. Quando finisce, il suo output diventa `results.identity` nel padre, e i suoi contatori si sommano a quelli del padre. La scelta `verified` legge quel risultato: un cliente verificato riceve l'email di benvenuto, tutti gli altri un cortese "ci dispiace".

E quando un candidato si ritira a metà strada, cancellare l'onboarding cancella anche la verifica ancora in attesa del revisore. Nessun orfano parcheggiato per sempre su un await.

## Avviati dall'orologio, avviati da un messaggio

Non tutte le esecuzioni partono perché qualcuno chiama `Start`. Alcune partono col tempo, altre con gli eventi.

Uno schedule non fa parte del flow: il flow dice cosa fare, lo schedule dice quando. Lo registri una volta, da Go o dalla riga di comando:

```sh
packtrail schedule nightly report "0 0 2 * * *" -tz Europe/Rome
```

Così il flow `report` parte ogni notte alle 2:00, ora di Roma (il primo dei sei campi sono i secondi). Non c'è nessun processo che tiene il tempo: lo schedule è esso stesso uno schedule di messaggi JetStream, quindi sopravvive ai riavvii senza che nessuno debba badarci.

Un trigger, invece, sta dentro il flow:

```yaml
name: order
triggers:
  - {subject: orders.created}
nodes:
  - {id: fulfil, type: task, kind: work}
```

Ogni messaggio pubblicato su `orders.created` avvia un'esecuzione di `order`. L'id dell'esecuzione deriva dal `Nats-Msg-Id` del messaggio, quindi quando lo stesso ordine viene pubblicato due volte, per un retry o un producer confuso, il secondo non avvia niente. Proprio il tipo di bug noioso da prevenire e costoso da ripulire.

## Cosa hanno in comune

Riguarda i sei esempi: il codice dei worker è quasi niente. Pagare una nota spese, contare parole, mandare un'email. Tutto ciò che è difficile (l'attesa, i retry, le scadenze, il parallelismo, la deduplicazione, il crash nel mezzo di tutto questo) sta in poche righe di YAML e nel log di eventi sottostante.

È quello che volevo da Packtrail fin dall'inizio. Tu descrivi la forma del lavoro, e il motore si occupa delle parti che di solito ti svegliano di notte. Che la parte lenta sia un'API instabile o un responsabile che ci mette tre giorni a rispondere, il flow ha lo stesso aspetto.

## Provali tu

Ogni esempio è un singolo `main.go` con il suo namespace, quindi non interferiscono tra loro.

```sh
docker run --rm -p 4222:4222 nats:2.14.2 -js
go run ./examples/resilience
make examples   # eseguili tutti
```

Mentre uno gira, punta `packtrail-ui` sul suo namespace e guarda il grafo accendersi. Il codice è su [GitHub](https://github.com/henomis/packtrail), e la documentazione completa è sul [sito di Packtrail](https://simonevellei.com/packtrail/). Se hai un workflow di tutti i giorni che non ci sta dentro, mi piacerebbe saperlo: apri una issue e raccontamelo.
