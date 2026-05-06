# The parallel research pattern: fan-out / fan-in for multi-agent AI


Most multi-agent examples run agents sequentially. One agent produces output, the next consumes it, and so on down the chain. This is easy to reason about but leaves performance on the table. If you need multiple independent perspectives on the same topic, there is no reason to wait for the first agent before starting the second.

The fan-out / fan-in pattern fixes this. Multiple worker agents run concurrently, each exploring the same topic from a different angle. When all workers finish, a synthesizer merges the findings into a single coherent report. The concurrency is handled by Go's native primitives—goroutines and `sync.WaitGroup`—with no new framework machinery required.

In this post I'll walk through building a parallel research system in Go using [Phero](https://github.com/henomis/phero). Three specialist agents investigate a topic simultaneously. A synthesizer then produces a unified report from all three findings.

## What we're building

A CLI that performs a multi-angle research run on any topic:

1. A **Historical Agent** traces origins, milestones, and the evolution of understanding
2. A **Technical Agent** explains the underlying mechanisms and engineering challenges
3. A **Societal Impact Agent** analyzes real-world effects on people, economies, and the environment
4. A **Synthesizer Agent** integrates all three into one structured, cross-referenced report

All three worker agents run concurrently. The synthesizer runs only after all workers have finished. Here's what a run looks like:

```
multi-agent architecture example: parallel research (fan-out / fan-in)
- llm: model=gpt-4o-mini
- topic: nuclear fusion

=== historical ===
Nuclear fusion research began in the early 20th century...

=== technical ===
Nuclear fusion works by forcing light atomic nuclei together...

=== societal impact ===
Nuclear fusion promises abundant clean energy, but...

synthesizing results...

=== synthesis ===
## Historical Overview
...
## Technical Mechanisms
...
## Societal Impact
...
## Synthesis
...
```

Each angle is printed as it completes (in slice order), then the synthesizer combines everything.

## Why fan-out / fan-in?

In a sequential pipeline, worker latency adds up. If each specialist takes 10 seconds, three specialists cost 30 seconds. With fan-out, all three run at the same time: the total latency is determined by the slowest worker, not the sum.

Beyond latency, independent angles produce better results than a single prompt asking for everything. A focused historical agent writes a tighter historical section than a general-purpose agent juggling three roles at once. Specialization improves quality.

The fan-in step is equally important. A synthesizer that receives all three findings at once can identify connections and tensions across angles—something that isn't possible if the agent only sees one finding at a time.

**When not to use it.** Fan-out requires that the workers are genuinely independent. If worker B needs worker A's output to proceed, sequential execution is the right model (see the evaluator-optimizer or supervisor-blackboard patterns). Fan-out trades sequential dependency for parallel latency savings.

## The architecture

```
                   ┌─► Historical Agent  ──────┐
                   │                           │
topic ──► fan-out ─┼─► Technical Agent   ──────┼─► Synthesizer ──► report
                   │                           │
                   └─► Societal Impact Agent ──┘
                    (all run concurrently via goroutines)
```

Three workers run in parallel. The fan-in waits for all three via `sync.WaitGroup`. The synthesizer then receives all findings in a single structured prompt.

No shared memory, no blackboard, no tool calls between agents. Workers are completely isolated from each other.

## Building the worker agents

Each worker is a plain `agent.Agent` with a focused system prompt. They differ only in angle:

```go
workerDefs := []struct {
    angle string
    sys   string
}{
    {
        angle: "historical",
        sys: `You are a historical research agent.

Your role: provide a concise historical overview of the given topic.
- Cover origins, key milestones, and how understanding or adoption evolved.
- Stay factual and cite approximate dates where relevant.
- Limit your response to 150-200 words.`,
    },
    {
        angle: "technical",
        sys: `You are a technical research agent.

Your role: explain the technical mechanisms behind the given topic.
- Focus on how it works, key technologies, and engineering challenges.
- Keep it accessible but precise.
- Limit your response to 150-200 words.`,
    },
    {
        angle: "societal impact",
        sys: `You are a societal impact research agent.

Your role: analyze the real-world effects of the given topic on people, economies, and the environment.
- Highlight both benefits and risks.
- Reference concrete examples where possible.
- Limit your response to 150-200 words.`,
    },
}

workers := make([]worker, 0, len(workerDefs))
for _, def := range workerDefs {
    a, err := agent.New(llmClient, def.angle+" Agent", def.sys)
    if err != nil {
        return nil, nil, err
    }
    workers = append(workers, worker{angle: def.angle, agent: a})
}
```

Each agent is word-count bounded. Without this, a research agent will write as much as the context window allows. Explicit length limits keep cost predictable and the synthesizer's input manageable.

Workers share no memory. There is no risk of one agent's chain of thought bleeding into another's perspective.

## The fan-out: goroutines and WaitGroup

The fan-out is pure Go. Each worker runs in its own goroutine. A `sync.WaitGroup` tracks completion:

```go
results := make([]workerResult, len(workers))
var wg sync.WaitGroup

for i, entry := range workers {
    wg.Add(1)

    go func(idx int, angle string, a *agent.Agent) {
        defer wg.Done()

        prompt := fmt.Sprintf("Research the topic %q from the %s angle.", topic, angle)
        out, err := a.Run(ctx, llm.Text(prompt))
        if err != nil {
            results[idx] = workerResult{angle: angle, err: err}
            return
        }

        results[idx] = workerResult{angle: angle, output: strings.TrimSpace(out.TextContent())}
    }(i, entry.angle, entry.agent)
}

wg.Wait()
```

Each goroutine writes to its own pre-allocated slot in the `results` slice (`results[idx]`), so there is no shared state and no mutex required. The index is captured by value in the closure to avoid the classic loop-variable aliasing bug.

The `ctx` is shared across all goroutines. If the context is cancelled (e.g., by the `-timeout` flag), all in-flight agent runs will be interrupted together.

## Handling worker errors

After `wg.Wait()`, the results are checked before building the synthesis prompt:

```go
for _, r := range results {
    if r.err != nil {
        panic(fmt.Errorf("worker %q failed: %w", r.angle, r.err))
    }

    fmt.Printf("=== %s ===\n%s\n\n", r.angle, r.output)
}
```

In a production system you would handle partial failures more gracefully—run the synthesizer on the successful findings, log the failure, and note the gap. For an example, `panic` keeps the error path visible.

## The fan-in: building the synthesis prompt

The fan-in is the step where parallel work becomes sequential. All worker outputs are assembled into a single structured prompt for the synthesizer:

```go
func buildSynthesisPrompt(topic string, results []workerResult) string {
    b := &strings.Builder{}
    fmt.Fprintf(b, "topic: %s\n\n", topic)
    fmt.Fprintf(b, "research findings:\n")

    for _, r := range results {
        fmt.Fprintf(b, "\n--- %s ---\n%s\n", r.angle, r.output)
    }

    return b.String()
}
```

The prompt labels each finding with its angle. This lets the synthesizer reference sources ("as the technical agent noted...") and identify where angles conflict or reinforce each other.

## The synthesizer agent

The synthesizer has a structured output mandate. It receives all three findings at once and is told to organize them into a fixed set of sections:

```go
synthesizer, err := agent.New(llmClient, "Synthesizer Agent", `You are a synthesis agent in a multi-agent research system.

You receive research findings from multiple specialist agents, each covering a different angle of the same topic.

Your task:
- Integrate the findings into one coherent, well-structured report.
- Identify connections and tensions across the angles.
- Keep the final report to 300-400 words.
- Use clear section headers (Historical Overview, Technical Mechanisms, Societal Impact, Synthesis).`)
```

The four-section structure mirrors the three worker angles plus a cross-cutting synthesis section. The synthesizer knows where each piece of information came from because the prompt labels it explicitly. This is the key advantage of the fan-in design: the synthesizer can produce a report that is better-integrated than any single agent writing all sections alone.

## Running it all together

The `main` function ties the pieces together in a handful of lines:

```go
workers, synthesizer, err := buildAgents(llmClient)
// ...

// Fan-out
results := make([]workerResult, len(workers))
var wg sync.WaitGroup
for i, entry := range workers {
    wg.Add(1)
    go func(idx int, angle string, a *agent.Agent) {
        defer wg.Done()
        out, err := a.Run(ctx, llm.Text(prompt))
        results[idx] = workerResult{angle: angle, output: out.TextContent(), err: err}
    }(i, entry.angle, entry.agent)
}
wg.Wait()

// Fan-in
synthesisPrompt := buildSynthesisPrompt(topic, results)
finalOut, err := synthesizer.Run(ctx, llm.Text(synthesisPrompt))
```

There is no Phero-specific concurrency API. Goroutines and `WaitGroup` are the right tool for this job. Phero handles individual agent execution; Go handles the orchestration.

## Cost and latency

A typical run on a topic like "nuclear fusion":

- **Latency:** ~10–15 s with gpt-4o-mini (3 workers in parallel; synthesizer after)
- **LLM calls:** 3 worker calls (concurrent) + 1 synthesizer call = 4 calls total

Sequential execution of the same three workers would take 3× the single-worker latency before the synthesizer even starts. Fan-out reduces that to 1× (plus some scheduling overhead).

The synthesizer's input token count scales with the sum of all worker outputs. With the 150–200-word limit per worker, the synthesis prompt is around 600–700 words—well within the context window of any current model.

## Comparison with other patterns

| Pattern | Worker independence | LLM calls | Latency model |
|---|---|---|---|
| Sequential pipeline | Dependent | N sequential | Sum of all steps |
| Fan-out / fan-in | Independent | N parallel + 1 | Max of workers + 1 |
| Supervisor-blackboard | Dependent | N + routing | Sum + routing overhead |
| Evaluator-optimizer | Dependent (iterative) | 2 × iterations | Iterations × step latency |

Fan-out / fan-in sits in the sweet spot when you have multiple independent perspectives and care about wall-clock latency. It does not require a supervisor agent or a shared blackboard—just goroutines and a well-designed synthesis prompt.

## When to use this pattern

This pattern works well when:

- **Workers are independent.** Each angle can be researched without knowing what the others find. No shared state, no sequencing constraints.
- **Latency matters.** Parallel execution saves wall-clock time when workers are slow (network I/O, large models, long outputs).
- **Quality improves with specialization.** Focused prompts produce tighter outputs. A dedicated historical agent writes better historical analysis than a general agent juggling all three roles.
- **You need a unified final output.** The synthesizer adds value precisely because it sees all angles simultaneously and can identify connections that no individual worker would notice.

When to avoid it: if the workers are fast (sub-second), the overhead of spinning up goroutines and assembling the synthesis prompt may not be worth it. Sequential execution is simpler to debug and reason about.

## Variations

**Dynamic angle generation.** Instead of hardcoding angles, ask a planning agent to generate a list of investigation angles for the given topic. Feed those angles into a generic worker template. This makes the pattern adaptive to any domain.

**Partial failure tolerance.** Filter out failed workers before building the synthesis prompt. Pass the list of missing angles to the synthesizer so it can note the gaps explicitly.

**Weighted synthesis.** Give the synthesizer metadata about each worker (confidence score, source count, word count) so it can weight findings appropriately when they conflict.

**Streaming fan-in.** Instead of waiting for all workers, stream each result to the synthesizer as it arrives. This requires a different synthesizer design but can reduce end-to-end latency further.

**N-level fan-out.** Each worker can itself fan out to sub-workers. A technical agent might spawn sub-agents for physics, engineering, and materials science. The sub-agents run in parallel; the technical agent synthesizes their outputs before reporting to the top-level synthesizer.

## Wrapping up

The fan-out / fan-in pattern is one of the simplest multi-agent architectures, and one of the most effective for research-style tasks. Independent angles, native Go concurrency, and a focused synthesis step combine to produce reports that are faster and better-integrated than any sequential approach.

The key insight is that framework machinery is not required. `sync.WaitGroup` is the fan-out mechanism. `strings.Builder` assembles the fan-in prompt. Phero handles agent execution. Go handles the rest.

The full source is at [`examples/parallel-research/`](https://github.com/henomis/phero/tree/main/examples/parallel-research).

*[Phero](https://github.com/henomis/phero) is an open-source Go framework for building multi-agent AI systems. Star the repo if you find it useful.*

