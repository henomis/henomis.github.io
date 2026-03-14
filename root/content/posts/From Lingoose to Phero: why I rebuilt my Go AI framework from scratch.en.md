---
date: '2026-03-14T15:09:51+01:00'
title: 'From Lingoose to Phero: why i rebuilt my Go AI framework from scratch'
tags: ["Go", "AI", "Frameworks", "Agents", "Development"]
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
featuredImage: "/images/phero001.png"
images: ["/images/phero001.png"]
cover:
    image: "/images/phero001.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

There's a moment every developer knows. You're staring at a codebase you built with your own hands, something you poured months into, something that works, and you realize it's fighting you. Not because it's broken, but because the world around it moved somewhere your original design never anticipated.

That moment came for me with [LinGoose](https://github.com/henomis/lingoose).

---

## A bit of history

I built [LinGoose](https://github.com/henomis/lingoose) in 2023 as a Go framework for LLM-powered applications. It grew, people used it, and I was proud of it. But after a while I hit a wall I couldn't design my way around: LinGoose was built around *pipelines*. A single flow, a single thread, steps executing in sequence.

That worked well, until the world went agentic.

---

## The honest truth about what happened

Life gets in the way. Between work, other projects, and the relentless pace of the AI space, LinGoose quietly stopped getting updates. No dramatic decision, no deprecation notice, just the slow drift that happens when time runs out and priorities shift.

In the meantime, the world went fully agentic. By 2026, **multi-agent systems** had moved from research curiosity to the default architecture everyone reaches for. Not "chat with an LLM" but *orchestrated networks of specialized agents*, each with a role, tools, memory, and the ability to cooperate or hand off work to each other.

LinGoose did have some basic building blocks that could support simple agents. But I never seriously tried to push it in that direction, and looking at it honestly, I don't think it would have been worth it. The framework was designed around *pipelines*: a single flow, steps in sequence, one thing at a time. That mental model runs deep. Bolting an agent coordination layer onto a pipeline framework wouldn't have given me what I actually wanted. It would have given me a compromise.

So in early 2026 I sat down and asked myself a simple question: if I were starting today, with everything I now know, what would I actually build?

The answer wasn't an updated LinGoose. It was something new, designed from day one around agents, not pipelines.

I would have been optimizing a goose when what I needed was an ant colony.

So I made the call: start clean.

---

## Enter Phero 🐜

[Phero](https://github.com/henomis/phero) is the framework I wish I'd had a year ago.

The name comes from pheromones, the chemical signals ants use to communicate, coordinate, and collectively solve problems no single ant could tackle alone. That metaphor is the whole philosophy. An agent in Phero isn't a pipeline step. It's a *participant* in a system, with a role, tools, memory, and the ability to coordinate with others through clean, composable patterns.

Everything I learned from years of building LinGoose went into Phero's design:

**Interfaces over implementations.** Want to swap your LLM from OpenAI to Ollama to some local endpoint? One line. Vector store? Same deal. Phero defines clean contracts and stays out of your way.

**Tools are first-class citizens.** Go functions become callable agent tools with automatic JSON Schema generation. The gap between your code and what your agents can *do* is as thin as I could make it.

**Purpose-built for the multi-agent era.** Phero ships with the patterns you actually need: supervisor-worker coordination, shared blackboards, debate committees, multi-agent workflows. These aren't afterthoughts, they're the core use cases the architecture was designed around.

**Built-in MCP support.** The [Model Context Protocol](https://modelcontextprotocol.io) is becoming the standard way to expose external tools to agents. Phero integrates it natively.

**Skills from SKILL.md files.** Phero lets you define reusable agent capabilities in markdown files and expose them as tools. It's a small thing that makes a surprisingly big difference in how you think about agent design.

---

## What stayed the same

Starting over didn't mean abandoning what worked. The values I cared about most carried over in stronger form: modularity (each package does one thing well), explicit control flow (no hidden magic), a lightweight dependency footprint (it's just Go), and a focus on developer experience with clean APIs and errors that actually help you.

The challenge was never "how do I call an LLM." It's always been "how do I build a system of cooperating agents that's maintainable and doesn't surprise me at 2am." Phero is built around that question from the ground up.

---

## A few things I'm proud of

The **examples directory** is a first-class part of the framework. I've seen too many frameworks that treat examples as an afterthought. Phero ships with a complete progression from a simple agent to multi-agent workflows, RAG chatbots, supervisor-blackboard patterns, and MCP integration. If you want to learn how to build something, the example is there.

The **package structure** is something I spent a lot of time on. Every package in Phero has a single, clear responsibility. You import what you need and nothing else. Want just the LLM abstraction without the agent orchestration? Take it. Need RAG without MCP? Fine. This isn't just good practice, it's a deliberate statement that a framework shouldn't force you into a monolith when you only need one piece of it.

---

## What's next

Phero is live. I'm using it in my own projects, and I'd love for other Go developers building in this space to try it, break it, and tell me what I got wrong.

The agentic era is just getting started. I want to build the best tools I can to help Go developers participate in it.

If you're curious, the best place to start is the [simple agent example](https://github.com/henomis/phero/tree/main/examples/simple-agent), around 100 lines of code that will give you a feel for how everything fits together.

---

*Built with ❤️*

*The ant is not just a mascot. It is the philosophy. 🐜*

---

**Links:**
- [Phero on GitHub](https://github.com/henomis/phero)
- [LinGoose on GitHub](https://github.com/henomis/lingoose)
