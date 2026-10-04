# Packtrail 1.0.0: durable workflows on nothing but NATS


When I first wrote about Packtrail, the pitch was a single sentence: a durable workflow engine that needs nothing but NATS. No database, no coordinator, no second thing to keep alive.

Today that sentence gets a version number. **Packtrail 1.0.0 is out.**

## The second time around

Here is the part I don't usually put in a release post: version 1.0.0 is not the first draft with a nicer tag. It is the second attempt.

The first version worked. It also taught me, one bug at a time, where a durable engine really breaks. A cancel that arrives at the wrong moment and gets lost. A fan-out that parks itself just as the last branch finishes. A signal that shows up before the step that wants it. A start that crashes halfway and leaves half an execution behind.

Every one of those became a regression test. Then I did something slightly uncomfortable: I wrote down the list, and started again from a blank directory, with a rule. The new engine had to keep every lesson, and it was allowed to throw away every mechanism that had been invented to patch around them.

Some of the patches simply disappeared. Leases, watchdogs and re-drive loops existed because state lived in memory and might be wrong. In the new design a decision is one message appended to an ordered log with an expected-sequence check, so a second writer is rejected by NATS itself. When there is nothing in memory to recover, there is nothing to watch.

That is the whole spirit of 1.0.0: fewer moving parts, and the ones left are easier to trust.

## What Packtrail is

If you are meeting it for the first time: Packtrail is a workflow engine where the workflow is **data**, not code. You declare a graph in YAML or Go structs, and the engine interprets it.

- **Event-sourced.** Every execution is an ordered log of events on its own subject. State, snapshots, timers and the visibility index are all derived from it. Time travel, forks, replays and audit come for free, because the history is the source of truth.
- **A declarative graph.** Tasks, choices, fan-out and join, awaits for human in the loop, dynamic maps, subflows, interrupts and failure routing for compensation. There are no determinism rules for your code, because your code is never replayed.
- **Workers in any language.** A task is a job on a subject, and a worker answers with a command over a small, versioned JSON protocol. The Go SDK is included, but nothing stops a worker from being written in anything that speaks NATS.
- **Agnostic.** No agents, LLMs or tokens in the core. An "agent" is just a worker. Budgets are generic counters.
- **Only NATS.** JetStream streams for the log, message schedules for durable timers and cron, KV and object stores for everything else.

A small flow looks like this:

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

A draft loops until it scores well enough, then waits up to two days for a human to approve it, then publishes. The engine can crash in the middle of any of those steps and the execution carries on when it comes back.

## What 1.0.0 means

A `1.0.0` is a promise, so here is what I am actually promising.

The flow format, the worker protocol and the event log layout are the contracts. They are versioned, documented, and covered by a conformance suite, so a client or worker written in another language can check itself against the same cases the Go code passes. Flows are immutable and versioned by hash, and an execution always keeps the version it started with, so deploying a new flow never changes the meaning of one already in flight.

Delivery is at-least-once, and I would rather say that plainly than hide it. A task can run twice after a crash, so side effects should be idempotent, or you can turn on the result cache. The engine itself is exactly-once per decision: duplicates and stale results are absorbed by the fold.

## Built to be broken

The part of the project I am most proud of is not a feature. It is how hard the tests lean on failure.

The suite runs against a real embedded `nats-server`, not mocks. There are tests that kill the engine at every single step of a flow, restart NATS in the middle of an execution, and replace all the engines every 700 milliseconds under load while a third of the flows fan out. In that scenario, three thousand executions all complete. Ten thousand executions can sit parked on a 24 hour await while the engine restarts, and then all wake up and finish when they are signalled.

When an execution has events the dispatcher can never process, it is quarantined instead of stalling its partition, and once the cause is fixed you can replay what was skipped. Transient outages never quarantine anything: the dispatcher just waits.

## Fast enough

I measured it, with the usual caveat that this is one laptop-class machine with the server, engine, workers and client in a single process.

On a three-step linear flow it handles about 1,500 executions per second, with roughly 0.9 milliseconds of latency per step. On a simulated three-node cluster with replication it is around 1,000 executions per second.

## Tools around the engine

A durable engine you cannot see into is not much use at three in the morning, so the CLI and the dashboard are part of the release.

```sh
packtrail run -flows flows/ &
packtrail start review -input '{"topic":"NATS"}' -wait
packtrail history <exec>          # every event
packtrail get <exec> -seq 12      # state right after event 12
packtrail fork <exec> 12          # continue from there in a new execution
packtrail rerun <exec> draft      # run a node (and what follows) again
```

You can look at the state of an execution at any point of its life, fork it from there with edited state, or rerun a single node. Because the log is the truth, none of this needs special machinery. `packtrail-ui` adds a dashboard with the graph, the timeline and the state at any event, for every namespace on your NATS account. It has no authentication and binds to loopback by default, so treat it as a debugging tool.

## Try it

You need Go 1.26 and NATS Server 2.12 or later with JetStream enabled.

```sh
docker run --rm -p 4222:4222 nats:2.14.2 -js
go get github.com/henomis/packtrail
go install github.com/henomis/packtrail/cmd/packtrail@latest
go install github.com/henomis/packtrail/cmd/packtrail-ui@latest
```

The repository has runnable examples for human in the loop, parallel research with reducers, map-reduce, retries and timeouts, time travel and forks, an agent-style tool loop, subflows, and cron and message triggers. Full documentation, including the worker protocol and the event log reference, is on the [Packtrail website](https://simonevellei.com/packtrail/), and the code is on [GitHub](https://github.com/henomis/packtrail).

## What comes next

Like Phero, Packtrail is a one person project, made at one desk in Italy, and `1.0.0` is a beginning. I want to see how it behaves on real clusters, hear where the documentation falls short, and find the failure I have not thought of yet. If you build something with it, or break it in an interesting way, please open an issue and tell me.

Durable workflows should not require a small infrastructure of their own. If you already run NATS, you already have most of what you need.

