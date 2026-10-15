---
date: '2026-10-14T09:00:00+02:00'
title: 'Packtrail by example: six everyday workflows'
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
    alt: "Packtrail by example: six everyday workflows"
    caption: ""
    relative: false
    hidden: false
---

Most of the work that needs a durable engine is not glamorous. It is an expense waiting for a signature. A job that fails at 3 a.m. because a network cable sneezed. An order message that arrives twice. A batch whose size you only know when it starts.

These are the problems I had in mind while building Packtrail. Here are six ordinary workflows, each based on a runnable example in the repository, and what Packtrail does with them.

## An expense that waits for a manager

Someone files an expense of 2,500 euros. Company policy says small expenses are paid right away, while anything above 1,000 needs a manager's approval. The manager is on holiday. The server restarts twice during the week.

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

Read it top to bottom and it is the policy itself. The `check` node looks at the amount: up to 1,000, the expense goes straight to `pay`; above that, it waits for the manager. The rule sits in the flow, where anyone can read it and change it, not buried in some worker's code.

The `approval` node parks the execution until a `manager-decision` signal arrives. When it does, `route` pays the expense or notifies the rejection. If three days go by in silence, the flow stops waiting and escalates to someone further up.

Nothing is running while the expense waits: no goroutine, no sleeping process. The 72 hour deadline is a durable NATS message schedule, so the flow moves on by itself whether or not the engine was restarted in between. The only code you write is the part that actually does something: paying and notifying.

## Ask three, go with the first two

You need information from three sources: an archive, a journal database, a forum. One of them is always slow. You don't want to wait for it, but you also don't want to trust a single answer.

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

A `fanout` node starts the three branches in parallel, and a `join` with policy `quorum:2` moves on as soon as two of them are done. The slowest branch is cancelled, and if its result shows up late, it is simply ignored. Then `write` puts the findings together.

The nice part is how the branches share their findings. Each one writes to **channels** with reducers: `notes` appends, `sources` merges, `cost` sums. Concurrent writes are folded together instead of overwriting each other, so there are no locks and no "last writer wins" surprises. A budget on the `cost` counter stops the execution if the branches overspend. Budgets are generic counters: they count whatever your workers report.

## Count the words in a pile of documents

The classic map-reduce, with a twist: you don't know how many documents there are until the execution starts.

```yaml
name: wordcount
channels:
  total: {reducer: sum}
  longest: {reducer: append}
nodes:
  - {id: count, type: map, kind: counter, over: input.docs, max_parallel: 4}
```

That is the whole flow. The `map` node runs one task per element of the input list, at most four at a time, and each task sees its element as `item`. The outputs come back in order, and the reduce step is not a step at all: every task adds its count to `total` and its longest word to `longest`, and the reducers do the rest.

Swap word counting for resizing images, sending invoices or checking a list of URLs, and the flow does not change.

## A pipeline full of bad workers

This is my favourite example, because it is a little gallery of things that go wrong in production. Four steps in a row, each with its own retry policy, and each worker misbehaving in its own way.

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

- `flaky` fails twice with "connection reset". The retry policy waits with exponential backoff (again on durable timers) and the third attempt succeeds.
- `slow` hangs on its first attempt. The one second timeout fires, the attempt is cancelled, and whatever it returns afterwards is dropped. The second attempt wins.
- `typed` returns `"forty-two"` where the flow's `output_schema` asks for a number. A schema violation counts as a failed attempt, so it is retried, and the second time it returns `42`.
- `broken` returns a permanent error: "invalid account number". No amount of retrying fixes that, so Packtrail doesn't try, even though the node allows three attempts. The execution fails, with the node and the reason recorded.

The distinction between a transient and a permanent error sounds small. It is the difference between a system that heals itself overnight and one that hammers a payment provider three times with the same wrong IBAN.

## Onboarding that calls another flow

A new customer signs up. Before you send the welcome email, their identity has to be verified, and verification is its own little process: check the document, then wait up to 24 hours for a human reviewer, who accepts or rejects it. If nobody reviews it in time, it is rejected.

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

The `verify` flow runs as a **child execution**, with its own id, its own log and its own state. You can reuse it from any other flow. When it finishes, its output becomes `results.identity` in the parent, and its counters are added to the parent's. The `verified` choice reads that result: a verified customer gets the welcome email, everyone else gets a polite "sorry" instead.

And when an applicant withdraws halfway through, cancelling the onboarding cancels the verification still waiting for a reviewer. No orphans left parked on an await forever.

## Started by the clock, started by a message

Not every execution is started by someone calling `Start`. Some are started by time, some by events.

A schedule is not part of the flow: the flow says what to do, the schedule says when. You register it once, from Go or from the command line:

```sh
packtrail schedule nightly report "0 0 2 * * *" -tz Europe/Rome
```

That starts the `report` flow every night at 2:00, Rome time (the first of the six fields is the seconds). There is no process keeping time: the schedule itself is a JetStream message schedule, so it survives restarts without anyone babysitting it.

A trigger, instead, lives in the flow itself:

```yaml
name: order
triggers:
  - {subject: orders.created}
nodes:
  - {id: fulfil, type: task, kind: work}
```

Every message published on `orders.created` starts an `order` execution. The execution id is derived from the message's `Nats-Msg-Id`, so when the same order is published twice, by a retry or a confused producer, the second one starts nothing. Exactly the kind of bug that is boring to prevent and expensive to clean up.

## What they have in common

Look back at the six examples and the code your workers contain is almost nothing: pay an expense, count some words, send an email. Everything hard (the waiting, the retries, the deadlines, the parallelism, the deduplication, the crash in the middle of it all) lives in a few lines of YAML and in the event log underneath.

That is what I wanted from Packtrail from the start. You describe the shape of the work, and the engine takes care of the parts that usually wake you up at night. Whether the slow part is a flaky API or a manager who takes three days to answer, the flow looks the same.

## Run them yourself

Every example is a single `main.go` with its own namespace, so they don't interfere with each other.

```sh
docker run --rm -p 4222:4222 nats:2.14.2 -js
go run ./examples/resilience
make examples   # run them all
```

While one runs, point `packtrail-ui` at its namespace and watch the graph light up. The code is on [GitHub](https://github.com/henomis/packtrail), and the full documentation is on the [Packtrail website](https://simonevellei.com/packtrail/). If you have an everyday workflow that doesn't fit, I would love to hear about it: open an issue and tell me.
