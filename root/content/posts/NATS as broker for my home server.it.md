---
title: "NATS as broker for my home server"
date: 2025-09-07T17:00:32+02:00
tags: ["nats", "home server", "development", "golang"]
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
disableHLJS: true # to disable highlightjs
disableShare: false
disableHLJS: false
hideSummary: false
searchHidden: true
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
featuredImage: "/images/pollenium04.png"
aliases: 
    - "/blog/posts/nats-as-broker-for-my-home-server/"
cover:
    image: "/images/pollenium04.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---
{{< admonition type=info open=true >}}
Questo post è stato originariamente scritto in inglese e tradotto in italiano tramite AI. Se noti errori di traduzione o passaggi poco chiari, segnalamelo pure.

🇬🇧 [Leggi il post originale in inglese](/en/nats-as-broker-for-my-home-server/)
{{< /admonition >}}

Uno dei miei ricordi d’infanzia è legato all’abitudine di mia zia di fare l’impasto per la pizza. Era il suo modo preferito per rilassarsi. Potrebbe sembrare normale, se non fosse che lei faceva la panettiera di mestiere. Ironico, vero? Il lavoro stesso che poteva essere fonte di stress era diventato il suo modo per staccare. La cosa buffa è che, dopo essere diventato sviluppatore software, mi sono ritrovato nella stessa identica situazione. Amo programmare, ma a volte ho bisogno di farlo per rilassarmi. Ed è esattamente quello che è successo quando ho iniziato a sviluppare il mio home server.

Tuttavia, questo articolo non parla strettamente del mio home server. Riguarda più che altro l’architettura che ho scelto per realizzarlo, in particolare usando **NATS** come message broker. Spiegherò perché ho fatto questa scelta e come ha giovato al mio progetto.

# Il server domestico

**TLDR;** Un mini-pc con CPU N100, 16 GB di RAM e un SSD da 512 GB, con Debian. Tutti i servizi sono containerizzati tramite `Docker`, e l’intero sistema è gestito con un singolo file docker-compose. Questo è solo il primo approccio, poiché ho diversi piani per il futuro. Attualmente il server esegue alcuni servizi, tra cui AdGuard, Nextcloud e Traefik. Ma la parte più interessante sono i servizi personalizzati che ho sviluppato io stesso usando Go e NATS.

# Il primo servizio: un sistema di monitoraggio dei pollini

Sapevi che ho delle allergie? Sì, le ho. E le odio. Ogni primavera, quando il livello dei pollini aumenta, soffro di starnuti, prurito agli occhi e naso che cola. Non è affatto divertente. Per fortuna non è troppo grave, ma comunque fastidioso. L’anno scorso ho trovato un modo per gestirlo senza farmaci, affidandomi a rimedi naturali, principalmente a base di ribes nero. Ma per farlo in modo efficace, avevo bisogno di conoscere i livelli di polline nella mia zona con qualche giorno di anticipo. Così, ho deciso di costruire un sistema di monitoraggio dei pollini usando i dati del sito [ARPAM Marche](https://pollini.arpa.marche.it/), che fornisce dati quasi in tempo reale sui pollini della mia regione.

## Pollenium

L’interfaccia utente del sito ufficiale è macchinosa e lenta, ma fortunatamente espone un’API pubblica. Ho sfruttato questa API scrivendo un leggero programma in Go che recupera quotidianamente i dati dei pollini per la mia zona. Il programma gestisce la propria pianificazione internamente, assicurandosi che i dati vengano aggiornati automaticamente ogni giorno e memorizzati in un database SQLite locale. Sopra questo ho sviluppato una semplice interfaccia web che mostra le ultime rilevazioni e visualizza le tendenze storiche con grafici interattivi, rendendo facile monitorare i livelli di polline nel tempo.

![zoom monitoring](/images/pollenium01.png)

Questo è ciò che ho chiamato **Pollenium**.

## Avvisi sui pollini

Ho già detto che voglio essere avvisato quando i livelli di polline sono alti? Pollenium è ottimo, ma se il livello di polline sale improvvisamente, voglio ricevere un avviso immediato. Tuttavia, non volevo implementare questa funzionalità direttamente in Pollenium. Ho preferito mantenerlo semplice e concentrato sulle sue funzioni principali. Così ho deciso di creare un’architettura separata per gestire le notifiche. È qui che entra in gioco NATS.

# Perché NATS?

NATS è un sistema di messaggistica ad alte prestazioni, leggero e facile da distribuire. Supporta vari modelli di messaggistica, tra cui publish/subscribe, request/reply e code. Ecco alcune ragioni per cui ho scelto NATS per il mio home server:

* **Semplicità**: NATS ha un’API semplice ed è facile da configurare. Questo era fondamentale per me, poiché volevo concentrarmi sullo sviluppo del server domestico senza perdermi in configurazioni complesse.
* **Prestazioni**: NATS è progettato per un’elevata velocità di trasmissione e una bassa latenza.
* **Supporto linguistico**: NATS ha librerie client per molti linguaggi di programmazione, incluso Go, che ho usato per il mio server domestico.

# Servizio di notifica

Il modo più semplice per ricevere una notifica è tramite un bot Telegram. Il nuovo servizio che ho implementato ascolta i messaggi su determinati “subjects” e invia un messaggio alla chat del mio bot Telegram. Il servizio è altamente configurabile e puoi specificare diversi subjects da ascoltare, oltre al formato del messaggio e agli ID delle chat a cui inviare le notifiche. Ho chiamato questo servizio **Telenats**. Le notifiche sono messaggi NATS JetStream, quindi sono persistenti e possono essere riprodotte se necessario.

![zoom monitoring](/images/pollenium02.png)

# Interfacce utente

Il sistema funzionava bene, ma volevo che NATS gestisse più delle sole notifiche. Poi mi sono venute due idee un po’ folli:

* perché non usare NATS per ascoltare le pressioni dei tasti?
* perché non usare NATS per inviare messaggi a un servizio di sintesi vocale?

Ho comprato un tastierino numerico USB e un altoparlante USB come dispositivi di input/output per il mio home server.

## Ascoltare le pressioni dei tasti

Ho implementato un semplice programma in Go che ascolta le pressioni dei tasti. Ogni pressione viene catturata e pubblicata su un subject NATS correlato. In questo modo posso inviare “*comandi*” a qualsiasi servizio in ascolto su quel subject. Semplice, no? Ho chiamato questo servizio **Typocast**. Mi è bastato passare il dispositivo `/dev/input/eventX` come parametro al container, e funziona perfettamente.

## Sintesi vocale

La funzionalità di sintesi vocale è un po’ più complessa. Mi servivano un paio di cose:

* un servizio che converta testo in voce
* un servizio che ascolti i messaggi tts e riproduca l’audio dopo la conversione

Per la conversione testo-voce ho usato [Piper](https://github.com/OHF-Voice/piper1-gpl), che dispone di voci in diverse lingue, tra cui l’italiano. Include un semplice server HTTP che accetta testo e restituisce un file audio. Il secondo servizio, che ho chiamato **Voicecast**, ascolta i messaggi tts su un determinato subject NATS. Quando riceve un messaggio, invia il testo al server Piper, ottiene il file audio e lo riproduce usando l’interfaccia classica `ALSA`.

# Mettere tutto insieme

Ora che avevo tutti i componenti, dovevo collegarli. Ecco come funziona attualmente:

1. Pollenium ogni giorno recupera i dati dei pollini e li memorizza nel database.
2. Se il livello dei pollini supera una certa soglia, Pollenium pubblica un messaggio di notifica su un subject NATS specifico.
3. Telenats ascolta i messaggi di notifica e invia un messaggio alla chat del mio bot Telegram.
4. Se voglio ascoltare i livelli di polline attuali, posso premere un tasto specifico sulla tastiera.
5. Typocast cattura la pressione del tasto e pubblica un messaggio specifico sul relativo subject NATS.
6. Pollenium ascolta quel subject/tasto e, quando riceve il messaggio, preleva dal database i pollini con livelli elevati e pubblica un messaggio formattato sul subject tts di NATS.
7. Voicecast ascolta i messaggi tts, invia il testo al server Piper, ottiene il file audio e lo riproduce.

![zoom monitoring](/images/pollenium03.png)

# Conclusione

Usare NATS come message broker per il mio home server è stata un’ottima scelta. Mi ha permesso di costruire un’architettura modulare, facile da mantenere ed estendere. Posso aggiungere nuovi servizi o modificare quelli esistenti senza influenzare l’intero sistema. Inoltre, è stata un’esperienza divertente e **rilassante** sviluppare il mio home server usando Go e la messaggistica asincrona.

