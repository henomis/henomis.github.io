---
date: '2026-04-18T16:10:15+02:00'
title: 'Building a multi agent debate committee in Go'
tags: ["ai", "go", "phero", "agents"]
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
featuredImage: "/images/phero005.png"
images: ["/images/phero005.png"]
cover:
    image: "/images/phero005.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

A single LLM call gives you one perspective. Ask the same question twice with different system prompts and you'll get meaningfully different answers, different assumptions, different blind spots, different strengths. This isn't a bug. It's the foundation of a useful multi-agent pattern.

The idea is old. Juries deliberate. Academic peer review works because reviewers disagree. Design reviews surface risks that the original author missed. The mechanism is always the same: independent reasoning followed by structured synthesis. LLMs are well-suited to both steps.

In this post I'll walk through building a debate committee in Go using [Phero](https://github.com/henomis/phero). Three agents argue independently, a judge synthesizes, and the whole thing runs in ~180 lines with no shared state between committee members.

## What we're building

A CLI that takes a question and runs it through a structured debate:

1. Three committee members (Advocate, Skeptic, Minimalist) each produce an independent argument
2. A Judge agent reads all arguments and produces a single synthesized answer

Here's what a run looks like:

```
multi-agent architecture example: debate committee + judge
- llm: model=gpt-4o
- question: How would you design a multi-agent workflow for safe repo triage?

=== Advocate ===
I'd propose a three-stage pipeline: a Triage agent classifies incoming
issues by severity and component, a Diagnostic agent reproduces and
isolates the root cause, and a Fix agent proposes patches...

=== Skeptic ===
The biggest risk in multi-agent repo triage is cascading failures from
incorrect classification. If the Triage agent mislabels a critical bug
as low-priority, every downstream agent inherits that mistake...

=== Minimalist ===
You don't need three agents for this. A single agent with a structured
prompt can classify, diagnose, and propose a fix in one pass. Add a
second agent only for review...

=== judge (final) ===
Start with a two-agent design: one for triage and diagnosis, one for
review. The classification step should include confidence scores, and
any item below 80% confidence should be escalated to a human...
```

Each member sees only the question. The judge sees all arguments. The final answer is better than any single agent would produce alone.

## Why multiple agents?

The obvious question: why not just ask one model to "consider multiple perspectives"? You can, and sometimes it works. But there are structural reasons to prefer actual separation.

**Prompt focus.** A system prompt that says "be an advocate for the strongest approach" produces different reasoning than one that says "find the failure modes." When you ask a single model to do both, it hedges. When you give each role its own agent, each one commits to its perspective.

**Independence.** Committee members don't see each other's arguments. This prevents anchoring, a well-known bias where the first answer dominates subsequent reasoning. The Skeptic isn't reacting to the Advocate; it's reasoning from scratch.

**Composability.** You can add or remove committee members without changing the judge. Swap the Minimalist for a Security Auditor. Add a Cost Analyst. The orchestration code doesn't change.

**Debuggability.** When the final answer is wrong, you can trace it back. Was the Advocate's proposal flawed? Did the Skeptic miss a real risk? Did the Judge weigh arguments poorly? With a single agent, you just get a wrong answer with no decomposition.

## The architecture

```
Question
  │
  ├──→ Advocate.Run(question)  ──→ argument₁
  ├──→ Skeptic.Run(question)   ──→ argument₂
  ├──→ Minimalist.Run(question) ──→ argument₃
  │
  └──→ Judge.Run(goal + question + [argument₁, argument₂, argument₃])
         │
         └──→ Final synthesized answer
```

This is a fan-out/fan-in pattern. The committee step fans out the question to N independent agents. The judge step fans in the results. There's no iteration, no tool calling, no shared memory. Each agent makes exactly one LLM call.

## Setting up the LLM

All agents share the same LLM client. The debate pattern works with any provider that implements `llm.LLM`:

```go
import "github.com/henomis/phero/llm/openai"

client := openai.New(apiKey, openai.WithModel("gpt-4o"))
```

Or with a local model via Ollama:

```go
client := openai.New("",
    openai.WithModel("llama3"),
    openai.WithBaseURL(openai.OllamaBaseURL),
)
```

Using the same client for all agents keeps things simple. In production you might use a cheaper model for committee members and a stronger one for the judge, since the synthesis step benefits more from reasoning quality.

## Building the committee

Each committee member is a standard `agent.Agent` with a different system prompt. The prompt defines the role and constrains the behavior:

```go
debateRules := `Rules:
- Stay focused on the question.
- Prefer concrete steps / designs over generic advice.
- Keep your response under 200 lines.
- Do not claim you executed anything; you are reasoning only.`
```

The shared rules are appended to each member's role-specific prompt. This ensures consistent format while allowing divergent reasoning.

### The advocate

```go
advocate, _ := agent.New(client, "Advocate",
    `You are the Advocate in a debate committee.

Your job: propose the strongest, most practical approach that would
work in most repos.

` + debateRules)
```

The Advocate's job is to build the best case for a solution. It's optimistic, concrete, and action-oriented.

### The skeptic

```go
skeptic, _ := agent.New(client, "Skeptic",
    `You are the Skeptic in a debate committee.

Your job: identify risks, hidden assumptions, and failure modes in
typical approaches. Offer concrete mitigations.

` + debateRules)
```

The Skeptic isn't contrarian for its own sake. It identifies what can go wrong and proposes mitigations. This is the agent that catches the assumptions others take for granted.

### The minimalist

```go
minimalist, _ := agent.New(client, "Minimalist",
    `You are the Minimalist in a debate committee.

Your job: propose the simplest architecture that still meets the goal.
Prefer fewer agents, fewer moving parts, and safe deterministic steps.

` + debateRules)
```

The Minimalist pushes back against over-engineering. It asks "do you actually need three agents for this?" and often the answer is no.

These three roles create a productive tension: ambition vs. caution vs. simplicity. The combination surfaces trade-offs that no single perspective would identify.

## The judge

The Judge is also an `agent.Agent`, but with a fundamentally different job. Instead of answering the original question, it evaluates arguments:

```go
judge, _ := agent.New(client, "Judge",
    `You are the Judge in a debate-committee multi-agent system.

You receive a goal, a question, and multiple committee arguments.

Tasks:
- Identify points of agreement and conflict.
- Call out any weak or unsupported claims.
- Produce a single best final answer that merges the strongest parts.

Constraints:
- Keep it concise and actionable.
- Do not mention internal roles ("Advocate", etc.) in the final answer.
- Do not invent tool outputs or execution results.`)
```

Two things to note about the Judge's prompt. First, it explicitly tells the model not to mention internal roles. The final answer should read as a standalone recommendation, not a summary of a debate. Second, it asks the Judge to call out weak claims. This prevents the Judge from being a simple average of the three inputs.

## Orchestrating the debate

The orchestration is plain Go. No framework abstractions, no DAG definitions, no YAML. Fan out to the committee, collect results, render them for the judge, get the final answer:

```go
// Fan out: each member answers independently
debate := make([]DebateResult, 0, len(committee))
for _, member := range committee {
    out, err := member.Agent.Run(ctx, llm.Text(question))
    if err != nil {
        panic(err)
    }
    debate = append(debate, DebateResult{
        Member: member.Name,
        Output: strings.TrimSpace(out.TextContent()),
    })
}

// Fan in: judge reads all arguments
judgeInput := renderJudgeInput(goal, question, debate)
final, err := judge.Run(ctx, llm.Text(judgeInput))
```

The `renderJudgeInput` function formats the arguments into a structured text block:

```go
func renderJudgeInput(goal, question string, debate []DebateResult) string {
    b := &strings.Builder{}
    fmt.Fprintf(b, "goal: %s\n", goal)
    fmt.Fprintf(b, "question: %s\n\n", question)
    fmt.Fprintf(b, "committee_arguments:\n")
    for i, r := range debate {
        fmt.Fprintf(b, "- member_%d: %s\n", i+1, r.Member)
        fmt.Fprintf(b, "  argument: |\n")
        for _, ln := range strings.Split(r.Output, "\n") {
            fmt.Fprintf(b, "    %s\n", ln)
        }
    }
    return b.String()
}
```

This produces YAML-like structured input that's easy for the LLM to parse. The numbered member labels (`member_1`, `member_2`) give the Judge a way to reference specific arguments without leaking role names.

## Deliberate isolation: no shared memory

Notice that committee members have no memory and don't see each other's output. This is intentional.

Shared context between agents creates coupling. If the Skeptic reads the Advocate's answer first, it anchors on that answer and critiques it specifically rather than reasoning independently about the question. The resulting "debate" is really just a review, which is a different (and less useful) pattern.

By keeping members isolated, you get genuinely diverse outputs. The diversity is what makes the Judge's synthesis valuable. If all three agents said the same thing, you wouldn't need a committee.

## Running the example

```bash
# With OpenAI
export OPENAI_API_KEY=sk-...
go run ./examples/debate-committee/

# With a custom question
go run ./examples/debate-committee/ \
    -question "What's the best strategy for migrating a monolith to microservices?"

# With Ollama
export OPENAI_BASE_URL=http://localhost:11434/v1
export OPENAI_MODEL=llama3
go run ./examples/debate-committee/

# With a custom goal and timeout
go run ./examples/debate-committee/ \
    -question "How should we handle secrets in CI/CD?" \
    -goal "Produce a pragmatic answer suitable for a small team" \
    -timeout 3m
```

The default question is about multi-agent design for test diagnosis, which makes it a meta-example: agents debating how to build agents.

## Cost and latency

This pattern makes 4 LLM calls per run: one per committee member plus one for the judge. The calls are sequential in this example, but the committee calls are independent and could easily be parallelized with goroutines:

```go
var wg sync.WaitGroup
results := make([]DebateResult, len(committee))

for i, member := range committee {
    wg.Add(1)
    go func(i int, m Debater) {
        defer wg.Done()
        out, err := m.Agent.Run(ctx, llm.Text(question))
        if err != nil { /* handle */ }
        results[i] = DebateResult{Member: m.Name, Output: out.TextContent()}
    }(i, member)
}

wg.Wait()
```

With parallel execution, wall-clock time is roughly `max(member latencies) + judge latency` instead of `sum(all latencies)`. For three members on GPT-4o, that's typically ~3s instead of ~6s.

Token cost scales linearly with the number of committee members, but the judge's input also grows. With three members producing ~200 lines each, the judge's input can be 2-3x a single member's output. Keep this in mind when adding members.

## Variations

The debate committee pattern is flexible. Here are a few useful variations:

**Multi-round debate.** Instead of one round, let members respond to each other. Feed the first round's arguments back to each member and ask them to revise. This converges toward consensus but costs more LLM calls.

**Voting instead of a judge.** Have each member vote on the best argument (including their own). If two or more agree, use that answer. Only invoke the judge when there's no majority. This saves one LLM call in the common case.

**Specialized committees.** Match the roles to the domain. For code review: Correctness Expert, Performance Expert, Security Auditor. For product decisions: User Advocate, Engineering Lead, Business Analyst.

**Tool-equipped members.** Give committee members tools. The Advocate could search documentation, the Skeptic could run static analysis, the Minimalist could check dependency counts. Each member's tools reflect its role.

## What to try next

- **Add tracing** with `trace/text` to see the full message flow between agents
- **Parallelize** the committee calls with goroutines for lower latency
- **Add tools** to committee members for grounded reasoning
- **Try different models** for different roles (fast/cheap for members, strong for the judge)
- **Combine with other patterns**: use a debate committee as a single step in a larger orchestrator-workers pipeline

## Wrapping up

The debate committee is one of the simplest multi-agent patterns, and one of the most effective. No shared state, no complex coordination, no iteration. Just independent reasoning followed by structured synthesis.

The key insight is that LLM outputs are highly sensitive to system prompts. By giving the same question to agents with different perspectives, you get genuine diversity of thought. The judge turns that diversity into a better answer than any single agent would produce.

Building it in Go with Phero takes ~180 lines. The orchestration is explicit, the agents are standard, and the pattern is easy to extend.

The full source is at [`examples/debate-committee/`](https://github.com/henomis/phero/tree/main/examples/debate-committee).

*[Phero](https://github.com/henomis/phero) is an open-source Go framework for building multi-agent AI systems. Star the repo if you find it useful.*
