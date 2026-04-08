---
date: '2026-04-08T17:01:39+02:00'
title: 'Build a support agent that routes itself'
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
featuredImage: "/images/phero003.png"
images: ["/images/phero003.png"]
cover:
    image: "/images/phero003.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---
A lot of support bots fail for the same reason. They try to do everything with one prompt.

Billing questions, outage reports, refund requests, API errors, onboarding questions. It all goes into one agent, and the prompt turns into a long list of rules, exceptions, and fallback behavior. At first it feels convenient. A few weeks later it feels fragile.

This is where multi agent systems stop being a buzzword and start being useful.

[Phero](https://github.com/henomis/phero) has a simple pattern for this: one agent triages the request, then hands it to the specialist that should actually handle it. The key detail is that the specialist does not start from scratch. It reads the shared conversation history and continues from there.

The result is a support bot that routes itself.

This article is based on the example in [examples/handoff](./examples/handoff/).

## The problem with one big support prompt

If you put every support case behind one agent, you usually get one of two bad outcomes.

The first is prompt sprawl. The system prompt becomes a wall of instructions trying to teach one model to act like a billing specialist, a support engineer, a product guide, and a traffic cop all at once.

The second is shallow answers. Even when the model guesses the category correctly, the reply often sounds generic because there is no clear specialist role behind it.

In real teams, support does not work like that. Triage exists for a reason. Specialists exist for a reason. Phero lets you model that structure directly.

## The architecture

The handoff example has three agents:

1. A triage agent.
2. A billing agent.
3. A technical support agent.

The triage agent never tries to solve the problem itself. Its only job is to route the request to the right specialist.

That makes the architecture easy to explain:

```text
+--------------+
| User message |
+--------------+
       |
       v
+-------------+
| Triage      |
| Agent       |
+-------------+
   |       |
   |       +--------------------+
   v                            v
+-------------+       +--------------------+
| Billing     |       | Technical Support  |
| Agent       |       | Agent              |
+-------------+       +--------------------+
```

That looks simple, but there is an important design decision underneath it. All three agents share the same memory instance.

That means the specialist can see the conversation that led to the handoff. The billing agent does not need the triage agent to rewrite the whole case in a perfect summary. The context is already there.

## The shared memory is the real trick

This is the part that makes the pattern work well.

In the example, all three agents get the same `simple.Memory`:

```go
sharedMemory := simplemem.New(50)

billingAgent.SetMemory(sharedMemory)
technicalAgent.SetMemory(sharedMemory)
triageAgent.SetMemory(sharedMemory)
```

Without that shared state, a handoff would feel like a reset. The specialist would only know that another agent chose it. It would not know why.

With shared memory, the handoff feels natural. A user says, "I was charged twice last month," the triage agent routes to billing, and the billing agent can answer as if it had been in the conversation from the start.

This matters beyond support bots. The same pattern applies when you split work between a planner and an executor, or between a research agent and a writing agent.

## How the handoff works

The routing itself is surprisingly small.

The triage agent registers specialists with `AddHandoff`:

```go
if err := triageAgent.AddHandoff(billingAgent); err != nil {
	panic(err)
}

if err := triageAgent.AddHandoff(technicalAgent); err != nil {
	panic(err)
}
```

That call makes the target agent available as a handoff destination. In practice, it gives the triage agent a structured way to say, "this request belongs to that specialist."

The specialists can also hand work back or across if needed. In the example, billing can hand off to technical support, technical support can hand off to billing, and both can hand off back to triage when a request is ambiguous.

That is an important detail. Real support conversations do not always stay inside one category.

## The application loop stays explicit

One of the reasons this example works well as a teaching piece is that the control flow is visible in the application code.

You run the active agent. If the result contains a handoff target, you switch agents and continue. If not, you print the answer.

The heart of the loop looks like this:

```go
result, err := routingAgent.Run(ctx, currentInput)
if err != nil {
	panic(err)
}

if result.HandoffAgent != nil {
	routingAgent = result.HandoffAgent
	currentInput = ""
	continue
}

fmt.Println(result.Content)
```

There are two things worth noticing here.

First, the handoff is explicit. The framework is not silently changing who is in control. Your application can log it, cap the maximum depth, or inspect the route.

Second, once the first agent has written the user turn to shared memory, the next agent can run with an empty input string. That feels odd the first time you see it, but it is exactly the point. The specialist is not relying on a forwarded summary. It is reading the real context from memory.

## What this feels like at runtime

The example is an interactive chatbot, so the behavior is easy to picture.

A user says:

> I was charged twice for my subscription last month.

The triage agent hands off to billing.

Then the terminal shows something like:

```text
[handoff] Triage Agent -> Billing Agent

Billing Agent: I'm sorry to hear you were charged twice. I can see a duplicate charge on your last billing cycle. I'll process a full refund within 3 to 5 business days.
```

If the next user turn is about a 503 error on `/upload`, the system can route to technical support instead.

That is the kind of behavior users immediately understand. It feels more like a real service team and less like a single chatbot pretending to be everything.

## Why this pattern matters

The main value here is not just correctness. It is maintainability.

A triage prompt can stay focused on classification and routing. A billing prompt can stay focused on billing. A technical support prompt can stay focused on technical diagnosis. You do not need one enormous prompt that tries to carry the whole organization inside it.

This separation also makes iteration easier. If billing responses are weak, you improve the billing agent. If routing is weak, you improve the triage agent. The responsibilities are clear.

That is what a good framework should encourage. Not complexity for its own sake, but structure that stays understandable as the system grows.

## Where this leads next

The handoff example is the cleanest way to understand why Phero is interesting as more than a single agent library.

Once you have routing between specialists, you are one step away from broader coordination patterns like committees, pipelines, and supervisors with shared state. Those systems look more advanced, but they build on the same idea: one agent does not need to do everything.

If you want to try this pattern yourself, start with [examples/handoff](./examples/handoff/).

If this sparked your curiosity, **[give Phero a star on GitHub](https://github.com/henomis/phero)**. It genuinely helps the project grow, and it takes three seconds.

*Phero is open source under the Apache 2.0 license. Contributions, issues, and discussions are welcome.*

*[GitHub](https://github.com/henomis/phero) · [pkg.go.dev](https://pkg.go.dev/github.com/henomis/phero) · [Examples](https://github.com/henomis/phero/tree/main/examples)*
