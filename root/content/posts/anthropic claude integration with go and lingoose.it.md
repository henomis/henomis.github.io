---
title: "Anthropic's Claude Integration with Go and Lingoose"
date: 2024-03-26T15:51:58+01:00
tags: ["go", "ai", "lingoose","claude", "llm", "anthropic"]
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
featuredImage: "/images/lingoose003.png"
aliases: 
    - "/blog/posts/anthropic-claude-integration-with-go-and-lingoose/"
cover:
    image: "/images/lingoose003.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---
{{< admonition type=info open=true >}}
Questo post è stato originariamente scritto in inglese e tradotto in italiano tramite AI. Se noti errori di traduzione o passaggi poco chiari, segnalamelo pure.

[🇬🇧 Leggi l'articolo originale in inglese](/en/anthropic-claude-integration-with-go-and-lingoose/)
{{< /admonition >}}

Nel mondo in continua evoluzione dell’intelligenza artificiale, è arrivato un nuovo assistente AI chiamato [Claude](https://claude.ai/), che sta attirando molta attenzione. Creato da un’azienda chiamata [Anthropic](https://anthropic.com/), Claude è incredibilmente intelligente e riesce a comprendere e comunicare con gli esseri umani in modi molto naturali e simili a quelli umani.

Ciò che rende Claude così speciale è il modo in cui è stato addestrato. Il team di Anthropic ha fornito a Claude una quantità enorme di dati, che gli permette di comprendere veramente come noi esseri umani parliamo e scriviamo. Quindi, sia che tu stia chiacchierando con Claude in modo informale, sia che gli chieda di affrontare un compito complesso, lui può gestirlo con una notevole abilità.

Ma Claude non è solo intelligente: ha anche un forte codice morale integrato. Anthropic si è assicurata che le risposte di Claude siano buone ed etiche, e che sia trasparente riguardo al fatto di essere un’AI. Questo aiuta a garantire che Claude non venga utilizzato in modi dannosi.

## Usare Claude con Go e Lingoose

A partire dalla versione v0.1.2 del mio progetto [Lingoose](https://lingoose.io), un framework Go per costruire applicazioni AI, è stato aggiunto il supporto a Claude. Questo significa che gli sviluppatori possono sfruttare le incredibili capacità linguistiche di Claude per creare sistemi intelligenti che comprendono il linguaggio naturale, analizzano dati e molto altro. Con l’aiuto di Claude, le menti creative che costruiscono su Lingoose possono ora spingere i loro progetti AI ancora oltre!

Lingoose fornisce un’API semplice e facile da usare per permettere agli sviluppatori di interagire con gli LLMS (Language Learning Models) come Claude. Questo rende semplice integrare Claude nei tuoi progetti e iniziare a costruire applicazioni AI straordinarie. Ecco un esempio di come puoi iniziare a usare Claude con Lingoose:

```go
package main

import (
	"context"
	"fmt"

	"github.com/henomis/lingoose/llm/antropic"
	"github.com/henomis/lingoose/thread"
)

func main() {
	antropicllm := antropic.New().WithModel("claude-3-haiku-20240307")

	t := thread.New().AddMessage(
		thread.NewUserMessage().AddContent(
			thread.NewTextContent("How are you?"),
		),
	)

	err := antropicllm.Generate(context.Background(), t)
	if err != nil {
		panic(err)
	}

	fmt.Println(t)
}
```

Questo esempio mostra quanto sia semplice usare Claude con Lingoose. Creando una nuova istanza di Claude e passando il modello che vuoi usare, puoi iniziare a generare risposte ai messaggi degli utenti in pochissimo tempo. In questo caso stiamo generando una risposta dell’assistente usando la chat completion.

> Per eseguire questo codice, la variabile d’ambiente `ANTHROPIC_API_KEY` deve essere impostata con la tua API key.

### Risposte in streaming

Lingoose supporta anche le risposte in streaming da Claude. Questo è utile quando vuoi gestire risposte parziali. Ecco un esempio di come puoi ricevere risposte in streaming da Claude usando Lingoose:

```go
...
	antropicllm := antropic.New().WithModel("claude-3-opus-20240229").WithStream(
		func(response string) {
			if response != antropic.EOS {
				fmt.Print(response)
			} else {
				fmt.Println()
			}
		},
	)
...
```

In questo esempio, stiamo usando il metodo `WithStream` per passare una funzione di callback che verrà chiamata ogni volta che Claude genera una risposta. Questo ti permette di gestire le risposte man mano che arrivano, il che può essere utile per applicazioni in tempo reale o quando vuoi mostrare risposte parziali all’utente.

## Facciamo una prova!

Con Claude e Lingoose, le possibilità sono infinite. Che tu stia costruendo un chatbot, un modello linguistico o qualcosa di completamente nuovo, le capacità linguistiche di Claude possono aiutarti a creare sistemi intelligenti che comprendono e comunicano con gli esseri umani in modi naturali. Inoltre, Lingoose offre molte altre funzionalità che ti aiutano a costruire applicazioni AI più velocemente ed efficientemente, come embeddings, assistenti, RAG e molto altro.
Quindi perché non fare una prova e vedere cosa puoi creare con [Claude](https://claude.ai/) e [Lingoose](https://lingoose.io)?
