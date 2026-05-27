---
date: '2026-05-27T07:00:00+02:00'
title: 'I put a visual editor in front of my AI framework. Draw nodes, get NATS agents'
tags: []
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
featuredImage: "/images/anthill-002.png"
images: ["/images/anthill-002.png"]
cover:
    image: "/images/anthill-002.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

Every builder reaches a moment when they start to suspect their own work.

Mine came while I was adding yet another example to [phero](https://github.com/henomis/phero), my Go framework for multi-agent AI systems. The example looked clean. The code was elegant. The abstractions composed nicely. But there was a question I kept circling: was any of this actually modular, or had I just written boilerplate that I was too close to see?

Phero is built around a single conviction: LLM adapters, tools, memory backends, RAG pipelines, NATS transport. Every piece should be an independent, swappable primitive. That's easy to claim. It's a lot harder to prove. And the longer I worked on the framework, the more I needed to know whether that claim was real.

So I built a test. I called it **anthill**.

## The question that breaks frameworks

The test came from a question I'd heard asked of other frameworks, and dreaded being asked of mine: *can you describe the configuration of this thing declaratively?*

It sounds simple. It's not. If your abstractions have hidden dependencies, if things are coupled in ways you didn't admit to yourself, a declarative config will find every one of those cracks. You can't describe as data what you haven't actually decomposed.

For phero, the bet was this: if the abstractions are genuinely clean, you should be able to write a YAML file that describes an entire multi-agent architecture (LLM selection, tool wiring, memory backends, RAG pipelines, workflows) and have a runner build and wire it all up automatically. No boilerplate. No glue code. No manually instantiating clients and threading dependencies through function calls.

```
anthill run -c config.yaml
```

That's the whole interface. Feed it a YAML file, get a running fleet of NATS micro-services.

## What a working config looks like

I started with the simplest case: a single agent with a bash tool.

```yaml
version: '1.0'
namespace: examples

llms:
  - name: default
    provider: openai
    model: ${OPENAI_MODEL:-gpt-4o-mini}
    api_key: ${OPENAI_API_KEY}
    base_url: ${OPENAI_BASE_URL:-https://api.openai.com/v1}

tools:
  - name: bash
    type: bash

agents:
  - name: simple-agent
    llm: default
    description: |
      You are a helpful assistant.
      You can run bash commands to answer questions or complete tasks.
      Be concise and accurate in your responses.
    tools:
      - bash
```

It ran. First try. That was the first sign the abstractions were holding.

Then I pushed harder. Multi-agent pipelines where each agent passes its output to the next:

```yaml
workflows:
  - name: analysis-pipeline
    timeout: 15m
    nodes:
      - name: plan
        agent: planner

      - name: execute
        agent: runner
        needs: [plan]

      - name: analyze
        agent: analyst
        needs: [execute]

      - name: review
        agent: critic
        needs: [analyze]
```

The `needs` field declares dependencies. Anthill builds a DAG, finds the entry node, and executes from there. Nodes whose dependencies are satisfied run concurrently. When a node has multiple `needs`, their outputs are joined automatically and passed as a single input. Fan-in, handled without special cases.

The planner, runner, analyst, and critic are defined elsewhere in the same file, each with its own LLM and tool list. The workflow just names them and wires them together. That separation, declaration versus composition, was exactly what I was testing for.

## Why NATS changed the game

Choosing NATS as the communication layer wasn't incidental. It changed the character of the whole system.

Every agent, including every workflow, registers as a [NATS micro-service](https://nats.io). Service discovery is built into the protocol. When agent A needs to call agent B, it doesn't look up a URL or a port; it discovers B by name under the deployment namespace. You can move agent B to a different process, a different container, a different machine. As long as both connect to the same NATS server, the call works identically.

This meant a single `config.yaml` could describe both *local* agents (started by this process) and *remote* agents (running elsewhere, referenced by name only). The workflow executor calls agents the same way regardless of where they're running. Location becomes irrelevant to the config.

It also meant the entire fleet was observable through standard tooling the moment it started:

```bash
nats req agents.prompt.examples.analysis-pipeline --replies=0 \
  --reply-timeout=10m "Analyse the Go module dependencies in this project"
```

No custom dashboard. No instrumentation to add. Just NATS.

## What actually happens at startup

When `anthill run` starts, it builds components in strict dependency order:

**LLMs → Embedders → Vectorstores → RAGs → Memories → Tools → Agents**

Each type is built independently, taking only what it needs from types already constructed. There are no cross-cutting dependencies, no circular initialization, no magic. Adding a new LLM provider means touching exactly one file. The rest of the system doesn't care.

Workflows get the same treatment as agents. From the outside, a workflow looks like a regular agent: it has a name, it accepts input, it returns output. Inside, it routes the request through the DAG and returns the final node's result. Calling a workflow is identical to calling a real agent. This was the property I most wanted to be true, and it was.

## The cascade: what clean abstractions give you for free

Here's the thing about getting the data model right: everything built on top of it gets cheaper.

When the config is pure data, a visual editor is almost trivial. Anthill ships a canvas where you drag typed nodes (agents, LLMs, tools, RAG pipelines, memories, vectorstores) and connect them with edges. Every connection you draw corresponds directly to a relationship in the YAML. The canvas is just another way to edit the same data structure.

Here's what a multi-agent setup looks like on the canvas, with an LLM, a RAG pipeline, a tool, and an agent wired together:

<!-- SCREENSHOT: anthill canvas showing a multi-agent config with LLM, RAG, tool, and agent nodes connected by typed edges -->
![anthill canvas](/images/anthill001.png "anthill canvas showing a multi-agent config with LLM, RAG, tool, and agent nodes connected by typed edges")

At any point you can open the YAML view and copy it out. The canvas and the YAML file are the same config. I want to be honest about the effort involved: the UI was fast to build because it had nothing to invent. It just reflects structure that already existed.

The same logic applies to deployment. `anthill deploy` reads the YAML and generates a self-contained Kubernetes manifest, with environment variables, config, and deployment settings all wired up.

```bash
anthill deploy -c config.yaml \
  --image myrepo/anthill:v1 \
  --nats-url nats://nats:4222 \
  --from-env | kubectl apply -f -
```

The config that runs locally with `anthill run` goes straight to Kubernetes unchanged. The config doesn't change; only the runtime does. This, too, was free: a consequence of the same underlying property.

## What I learned

Anthill isn't the point. The point is that phero's primitives are composable enough that an entire multi-agent architecture (LLM selection, tool wiring, memory backends, RAG pipelines, parallel workflows, service discovery) can be expressed as a YAML file and executed without a single line of application code.

The k8s deployer, the visual builder, the NATS-native communication: each of those is just another consequence of the same underlying property. If the abstractions are right, everything else follows. If they're wrong, nothing works without hacks.

I now have my answer. The claim about phero wasn't just good intentions buried in code.

## Should I open source this?

Anthill is not public yet. I built it as a personal experiment, and I'm genuinely undecided about releasing it. The argument for going public is strong: the whole point is to show what phero enables, and that argument lands better when anyone can run it, fork it, and push it in directions I haven't thought of. The argument against is that it's still rough in places, and open sourcing something half-finished can create more noise than signal.

So I'm asking directly: would you use this? Would you want to contribute to it, build on top of it, or just have it as a reference for your own YAML-driven agent setup? If there's real interest, that settles the question for me. Reach out directly. I'd love to hear your take.

---

The code for phero is at [github.com/henomis/phero](https://github.com/henomis/phero).
