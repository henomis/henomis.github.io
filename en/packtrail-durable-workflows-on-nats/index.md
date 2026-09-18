# Packtrail: durable workflows built on nothing but NATS


Picture a pipeline with five steps. An AI agent reads a request, three more research it in parallel, and a human signs off at the end. It runs fine for weeks. Then one night the process dies at step three.

To recover, the system needs to answer two questions. **Where was I?** Which steps already ran, what did they return, which ones must not run again. And **where am I going?** What comes after step three, which branch to take, who is still waiting for an approval.

The first question is about *durability*. The second is about the *workflow*. Packtrail is built on one idea: those two answers belong in the same place.

## Meet packtrail

Packtrail is an open source **workflow engine for Go** that keeps its whole state in **NATS**, and nowhere else. You describe your process as a small graph, in YAML or in Go. Packtrail walks it one step at a time and writes every step to NATS before moving on. If a process crashes, another one picks up exactly where it stopped.

Today I'm releasing version **0.2.0**. It's young, it's pre-1.0, and it's built by one person. I'd love for you to meet it.

- **GitHub**: [github.com/henomis/packtrail](https://github.com/henomis/packtrail)
- **Website and docs**: [simonevellei.com/packtrail](https://simonevellei.com/packtrail/)

## Two halves of the same problem

When I looked at the tools for durable processes, I kept finding one half at a time.

On one side there are **durable execution engines**. They are brilliant at the first question. You write your process as ordinary code, and the engine records every step so it can replay the code after a crash. But the workflow itself has no shape of its own: it lives inside functions, loops and `if` statements. To know what a process does, you read the code. To know where a running instance is, you ask the engine to replay it.

On the other side there are **workflow orchestrators**. They are brilliant at the second question. The flow is a first-class document: you can read it, review it, draw it. But they often come as platforms, with their own servers, databases and consoles to run next to your application.

I wanted both halves in one small library. That is the choice at the heart of packtrail, and nearly every other decision follows from it.

## Why the engine and the workflow belong together

When the durable engine *owns* the workflow, both sides get better.

**The workflow gains durability for free.** A retry with exponential backoff, a parallel fan-out waiting on three branches, an approval that waits 24 hours: none of these are special cases. They are nodes in the graph, and the engine persists each transition between them. A crash in the middle of a 24-hour wait is a non-event.

**Durability becomes something you can see.** The state of an execution is not a replay log only the engine understands. It's "we are at node `route`, and `triage` returned this". A human can read that. `Resume` restarts a failed execution from the exact node that failed, with every earlier result kept. The dashboard draws the graph and shows each execution moving through it live.

**Mistakes are caught before anything runs.** Because the whole graph is known up front, packtrail checks it at startup: steps nobody can reach, routing rules with no default, typos in field names. When the process is buried in code, a broken path like that often stays hidden until the unlucky execution that takes it.

**Even the flow itself is durable.** Every engine publishes its flow graphs to NATS when it starts. So the definition of the process lives next to its state, and any tool connected to NATS can see both without touching your source code.

Here is what that looks like. An agent triages a request, a rule picks the route, and a human has a day to approve:

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

You don't need to know packtrail to read it. And every line of it survives a crash.

## A library, not a platform

Keeping the engine and the workflow together only works if it stays light. Otherwise it's just another platform to operate.

That's why packtrail runs on **NATS alone**. In my projects NATS was always already there, and today it has everything a workflow engine needs underneath: durable streams for work queues, a key-value store with compare-and-swap for state, and, since version 2.12, a scheduler for timers that survive restarts. Packtrail adds no database and no cluster. It's `go get` and a connection you already have.

It's also why packtrail never talks to your services directly. Every step goes through a single interface:

```go
type Invoker interface {
    Invoke(ctx context.Context, req Request) (Result, error)
}
```

Call an AI agent, an HTTP API, a NATS worker: whatever you plug in inherits retries, timeouts and crash recovery. Packtrail owns the *workflow* and the *durability*. The *transport* stays yours.

> **Your transport. Packtrail's durability.**

## What you get

A quick tour, with the details left to the [docs](https://simonevellei.com/packtrail/docs.html):

- **Five building blocks**: `task`, `choice`, `fanout`, `fanin` and `signal`, enough for pipelines, parallel research, routing and human approvals
- **Retries and timeouts** per step, with backoff scheduled in NATS rather than in memory
- **Parallel branches** that join when all, any, or a quorum of them finish
- **Human in the loop**: an execution can wait days for an external signal without holding anything in memory
- **Long-running work**: slow steps move to a durable work queue so they never block the engine
- **Cron schedules, resume, cancel, history and archival** for processes that run for months, not minutes
- **packtrail-ui**: a small dashboard that draws your flows and shows executions moving through them live

## Honest about where it is

I'd rather set expectations than oversell.

Packtrail is **pre-1.0**. The way it stores data in NATS may still change between releases. It needs a recent NATS server (2.12 or newer). Steps run **at least once**, so side effects need care, and packtrail has a result cache to help with that.

And the central choice cuts both ways. If you'd rather express your process as plain code, with loops and conditions written in Go, a code-first durable engine will feel more natural, and that's a perfectly good choice. Packtrail is for people who want to *see* their process.

What I can promise is care. Around 400 tests run against a **real NATS server**, not mocks, because the bugs that matter in a system like this live in the real interaction with the backend.

## A solo project, made in Italy

There's no team or company behind packtrail. It's one person at a desk in Italy. It started in June 2026, and it exists because I wanted this tool and couldn't find it in the shape I had in mind: the workflow and its durability in one place, on infrastructure I already run.

I don't expect it to replace the big engines. I do hope it becomes the obvious choice for people who already run NATS and want durable, visible workflows without adding more infrastructure. The only way to get there is with people who try it, break it and tell me what happened.

## Come along

```sh
go get github.com/henomis/packtrail
```

Then spin up `nats-server -js` and try one of the five runnable examples in the repository. The human approval one is my favorite.

- **Star it** on [GitHub](https://github.com/henomis/packtrail) if the idea resonates
- **Read the docs** at [simonevellei.com/packtrail](https://simonevellei.com/packtrail/)
- **Open an issue** when something confuses you: for a young project, that is the most valuable gift

Thanks for reading, and happy trails.

*Simone Vellei, Italy*

