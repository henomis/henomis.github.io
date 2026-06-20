---
date: '2026-06-20T16:00:00+02:00'
title: 'Phero 1.0.0: il linguaggio chimico degli agenti AI'
tags: ["go", "ai", "phero", "agents", "open-source"]
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
featuredImage: "/images/phero010.png"
images: ["/images/phero010.png"]
code:
  maxShownLines: -1
cover:
    image: "/images/phero010.png"
    alt: "Phero 1.0.0: il linguaggio chimico degli agenti AI"
    caption: ""
    relative: false
    hidden: false
---

Dopo una lunga serie di release `0.0.x`, Phero raggiunge finalmente la **v1.0.0**.

## Ce l'abbiamo fatta

C'è una sensazione particolare nel tagliare il tag `1.0.0`. Le versioni `0.0.x` sono un cantiere: abbatti muri, sposti le scale, ci dormi sopra e le ricostruisci il mattino dopo. `1.0.0` è il momento in cui apri finalmente la porta e dici: *è pronto, e ci metto la faccia.*

Oggi Phero supera quella soglia.

Se non lo conoscete ancora: **Phero è un framework Go per costruire sistemi AI multi-agente cooperativi.** Non un wrapper per LLM, ma un insieme di primitive piccole e componibili per orchestrazione, tool, RAG, memoria e comunicazione tra agenti, tutto provider-agnostic by design.

## Il percorso

Ogni `0.0.x` è stata una lezione.

Le prime versioni rispondevano a *"un agente può chiamare una funzione Go come tool?"* Poi *"due agenti possono passarsi del lavoro?"* Poi *"un agente può parlare con un altro agente attraverso la rete, via HTTP, via NATS, compatibile con altri ecosistemi?"* Ogni risposta tirava fuori la domanda successiva.

A un certo punto la forma della cosa è emersa. Non un monolite. Una **colonia**: pacchetti indipendenti, ciascuno con un compito preciso, che si riconoscono tra loro e si coordinano attraverso interfacce chiare.

- `agent`: il loop di chat, i tool e i passaggi di consegne
- `llm`: un'interfaccia tipizzata e pulita per i modelli, con middleware
- `tool`: funzioni esposte ai modelli con JSON Schema generato automaticamente
- `rag`, `embedding`, `vectorstore`, `textsplitter`: il layer della conoscenza
- `memory`: contesto conversazionale, da in-process a PostgreSQL a NATS KV
- `mcp`, `a2a`, `nats`: come gli agenti raggiungono il mondo esterno e si parlano
- `trace`: osservabilità opt-in su ogni passo

`1.0.0` è il punto in cui quelle interfacce hanno smesso di muoversi. Si sono guadagnate la promessa di stabilità.

## La formica non è solo una mascotte

Phero prende il nome dai *feromoni*, i segnali chimici che le formiche usano per coordinarsi. E non è decorazione: è tutta la filosofia.

Una colonia di formiche non ha un cervello centrale. Nessuna formica ha il piano generale in testa. Eppure la colonia raccoglie cibo, costruisce, si difende e si adatta, perché ogni formica segue regole locali semplici e lascia segnali che le altre sanno leggere. L'intelligenza è **emergente**, non comandata.

È la scommessa che Phero fa sugli agenti AI: il comportamento interessante non viene da un unico prompt gigante. Viene da molti agenti focalizzati, ciascuno bravo in una cosa, che si lasciano segnali chiari e si fidano del protocollo che li unisce.

**La formica non è solo una mascotte. È la filosofia.** 🐜

## Un solo sviluppatore, fatto in Italia

Voglio essere onesto su una cosa: Phero è costruito da **una sola persona**. Me.

Ogni pacchetto, ogni test, ogni esempio, ogni riga di documentazione vengono da una scrivania in Italia. Non c'è un team, non c'è un round di finanziamento, non c'è un comitato che decide la roadmap. Solo la convinzione che un framework Go pulito, onesto e ben testato per i sistemi multi-agente merita di esistere, e che l'open source è il posto giusto in cui metterlo.

È la parte di cui sono più orgoglioso. Non che sia perfetto (non lo è, e `1.0.0` è un inizio, non una fine), ma che sia **genuino**. Software vero, scritto con cura, dato via liberamente. *Fatto in Italia.*

Se avete mai spedito qualcosa da soli e sentito quel misto di terrore e gioia sul pulsante di rilascio, sapete esattamente cosa si prova oggi.

## Cosa c'è in 1.0.0

Un rapido giro di quello che trovate:

- **Orchestrazione degli agenti**: workflow multi-agente con specializzazione dei ruoli, coordinamento e passaggi di consegne in runtime
- **Function tools**: trasforma qualsiasi funzione Go in un tool, schema generato per te
- **RAG**: vector storage e ricerca semantica integrati (Qdrant, pgvector, Weaviate)
- **Skills**: capacità riutilizzabili degli agenti definite in file `SKILL.md`
- **MCP**: server Model Context Protocol come tool per gli agenti
- **A2A e NATS**: esponi agenti via HTTP o NATS, e chiama quelli remoti come se fossero locali
- **Memory**: da effimera a duratura, con sessioni con nome che sopravvivono ai riavvii
- **Tracing**: output a colori nel terminale e backend NDJSON/OpenTelemetry
- **Lightweight**: solo Go e il provider LLM che preferisci

E un set in crescita di **27 esempi eseguibili**, dal *Simple Agent* in un singolo file alla *A2A newsroom* multi-agente.

## Grazie

A tutti quelli che hanno aperto una issue, messo una stella al repo, provato un esempio o detto anche solo una parola gentile: grazie. L'open source è una strada lunga da percorrere da soli, e ogni segnale che là fuori c'è qualcuno che legge rende il prossimo commit un po' più facile.

`1.0.0` è la fondamenta. Adesso comincia la parte divertente: costruire *sopra* di essa, insieme a voi.

Se Phero vi sembra il vostro tipo di cosa:

- **Mettete una stella su GitHub**: [github.com/henomis/phero](https://github.com/henomis/phero)
- **Leggete la documentazione**: cominciate dall'esempio *Simple Agent*
- **Venite a dirmi ciao**: le issue e le discussioni sono aperte

Alla colonia. 🐜

*Simone Vellei, Italia*
