---
date: '2026-06-20T16:00:00+02:00'
title: 'Phero 1.0.0: the chemical language of AI agents'
tags: ["go", "ai", "agents", "open-source", "phero"]
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
    alt: "Phero 1.0.0: the chemical language of AI agents"
    caption: ""
    relative: false
    hidden: false
---

After a long string of `0.0.x` releases, Phero finally reaches **v1.0.0**.

## We made it to 1.0.0

There's a particular feeling that comes with cutting a `1.0.0` tag. The `0.0.x` versions are a workshop: you tear walls down, you move the staircase, you sleep on it and rebuild it the next morning. `1.0.0` is the moment you finally open the door and say: *this is ready, and I stand behind it.*

Today Phero crosses that threshold.

If you haven't met it yet: **Phero is a Go framework for building cooperative multi-agent AI systems.** Not an LLM wrapper, but a set of small, composable primitives for orchestration, tools, RAG, memory, and inter-agent networking, all provider-agnostic by design.

## The journey

Every `0.0.x` was a lesson.

The early versions answered *"can an agent call a Go function as a tool?"* Then *"can two agents hand work to each other?"* Then *"can an agent talk to another agent across the network, over HTTP, over NATS, wire-compatible with other ecosystems?"* Each answer pulled the next question into view.

Somewhere along the way the shape of the thing emerged. Not a monolith. A **colony**: independent packages, each doing one job well, recognising one another and coordinating through clear interfaces.

- `agent`: the chat loop, tools, and handoffs
- `llm`: a clean, typed model interface with middleware
- `tool`: functions exposed to models with auto-generated JSON Schema
- `rag`, `embedding`, `vectorstore`, `textsplitter`: the knowledge layer
- `memory`: conversational context, from in-process to PostgreSQL to NATS KV
- `mcp`, `a2a`, `nats`: how agents reach the outside world and each other
- `trace`: opt-in observability into every step

`1.0.0` is the point where those interfaces stopped moving. They've earned the stability promise.

## The ant is not just a mascot

Phero is named for *pheromones*, the chemical signals ants use to coordinate. And that's not decoration; it's the whole philosophy.

An ant colony has no central brain. No ant holds the master plan. Yet the colony forages, builds, defends, and adapts, because each ant follows simple local rules and leaves signals the others can read. Intelligence is **emergent**, not commanded.

That's the bet Phero makes about AI agents: the interesting behaviour doesn't come from one giant prompt. It comes from many focused agents, each good at one thing, leaving each other clear signals and trusting the protocol between them.

**The ant is not just a mascot. It is the philosophy.** 🐜

## One developer, made in Italy

I'll be honest about something: Phero is built by **one person**. Me.

Every package, every test, every example, every line of documentation comes from a single desk in Italy. There's no team, no funding round, no roadmap committee. Just the conviction that a clean, honest, well-tested Go framework for multi-agent systems deserves to exist, and that open source is the right place to put it.

That's the part I'm proudest of. Not that it's perfect (it isn't, and `1.0.0` is a beginning, not an ending), but that it's **genuine**. Real software, written carefully, given away freely. *Fatto in Italia.*

If you've ever shipped something alone and felt that mix of terror and joy at the release button, you know exactly what today feels like.

## What's in 1.0.0

A quick tour of what you get:

- **Agent orchestration**: multi-agent workflows with role specialization, coordination, and runtime handoffs
- **Function tools**: turn any Go function into a tool, schema generated for you
- **RAG**: built-in vector storage and semantic search (Qdrant, pgvector, Weaviate)
- **Skills**: reusable agent capabilities defined in `SKILL.md` files
- **MCP**: Model Context Protocol servers as agent tools
- **A2A and NATS**: expose agents over HTTP or NATS, and call remote ones as local tools
- **Memory**: from ephemeral to durable, with named sessions that survive restarts
- **Tracing**: colorized terminal output and NDJSON/OpenTelemetry backends
- **Lightweight**: just Go and your choice of LLM provider

And a growing set of **27 runnable examples**, from a single-file *Simple Agent* to a multi-agent *A2A newsroom*.

## Thank you

To everyone who opened an issue, starred the repo, tried an example, or just said a kind word: thank you. Open source is a long road to walk alone, and every signal that someone is out there makes the next commit easier.

`1.0.0` is the foundation. Now the fun part begins: building *on* it, with you.

If Phero sounds like your kind of thing:

- **Star it on GitHub**: [github.com/henomis/phero](https://github.com/henomis/phero)
- **Read the docs**: start with the *Simple Agent* example
- **Come say hi**: issues and discussions are open

Here's to the colony. 🐜

*Simone Vellei, Italy*
