# Simulating public opinion with Phero


A single LLM answer has a neat, confident shape. Public opinion does not.

When a policy changes, a product launches, or a company announces something unpopular, the interesting part is rarely the first reaction. It is what happens after people see each other reacting. Arguments harden. Coalitions form. A practical objection becomes the sentence everyone repeats. A weak point disappears because nobody picks it up.

That is hard to study with one prompt.

The [social simulation example](https://github.com/henomis/phero/tree/main/examples/social-simulation) in Phero explores a different shape: give the system a seed scenario, build a cast of fictional people with conflicting views, let them post concurrently for a few rounds, then ask a report agent to analyze the transcript.

It is not prediction magic. It is a structured way to ask: *if different kinds of people reacted to this situation in public, what dynamics might emerge?*

## What we're building

The example is a CLI inspired by MiroFish, built entirely with [Phero](https://github.com/henomis/phero). It takes a seed scenario and runs it through four phases:

1. Extract neutral world facts from the seed text
2. Generate diverse fictional personas with conflicting stances
3. Run several simulation rounds, with all persona agents posting concurrently
4. Synthesize a structured report from the full transcript

Optionally, it then opens an interactive Q&A session with the report agent.

A run starts like this:

```text
multi-agent architecture example: social simulation
- llm: model=gpt-4o
- agents: 8  rounds: 5  topk: 15
- estimated LLM calls: ~43

phase 1/4: extracting world facts...
world facts extracted.

phase 2/4: generating 8 personas...
8 personas generated:
  - Maria Lopez (pragmatic, community-focused)
  - James Okafor (skeptical, data-driven, direct)

phase 3/4: running 5 simulation rounds...
  round 1/5
    [Maria Lopez] This policy is exactly what our city needs to...
    [James Okafor] The timeline is completely unrealistic. Banning...
```

The default scenario is a controversial municipal ban on private gas vehicles in a city center. You can replace it with a news article, a policy brief, a product announcement, or a short paragraph typed directly into the command line.

## The architecture

The architecture is a pipeline with a concurrent middle:

```text
seed text
    |
    v
KnowledgeExtractor  -> world facts
                              |
                              v
                     PersonaOrchestrator -> N persona agents
                                                      |
                                          +-----------+-----------+
                                          |   simulation rounds   |
                                          |  goroutine fan-out    |
                                          |  shared WorldFeed     |
                                          +-----------+-----------+
                                                      |
                                                      v
                                               ReportAgent
                                                      |
                                               optional REPL
```

There are three different agent roles in the pipeline.

The `KnowledgeExtractor` turns arbitrary seed material into neutral world facts. The `PersonaOrchestrator` turns those facts into a cast. Each persona then becomes its own `agent.Agent`, with its own memory and system prompt. At the end, the `ReportAgent` reads the full transcript and produces the analysis.

The simulation itself is plain Go: goroutines, `sync.WaitGroup`, a mutex-protected feed, and a context timeout. Phero provides the agent abstraction, memory, LLM interface, and prompt/tool loop. The orchestration stays visible in application code.

## From seed text to world facts

The first step is deliberately boring, and that is the point.

Before generating opinions, the example extracts a neutral summary of the situation:

```go
worldFacts, err := extractWorldFacts(ctx, llmClient, seedText)
if err != nil {
    panic(fmt.Errorf("world facts: %w", err))
}
```

The extractor is a normal Phero agent:

```go
knowledgeAgent, err := agent.New(
    llmClient,
    "KnowledgeExtractor",
    `You are a knowledge extraction specialist.

Read the provided source material and produce a concise, neutral
"world facts" summary covering the central situation, key entities,
main tensions, current state, and open questions.

Be factual and neutral. Do not take a stance.`,
)
```

This keeps the rest of the system grounded. Every persona is generated from the same facts, not from a different interpretation of the original article. That reduces noise in a place where you want disagreement to come from the personas, not from accidental context drift.

It also gives you a useful debugging checkpoint. If the simulation later feels strange, inspect the world facts first. If the facts are wrong, everything downstream is reacting to the wrong world.

## Generating the cast

The second phase creates fictional people who have reasons to disagree.

The persona schema is intentionally small:

```go
type Persona struct {
    Name        string `json:"name"`
    Background  string `json:"background"`
    Stance      string `json:"stance"`
    Personality string `json:"personality"`
}
```

The `PersonaOrchestrator` receives the world facts and a requested count. Its prompt asks for exactly that number of personas, with genuinely distinct stances:

```go
prompt := fmt.Sprintf(
    "World facts:\n%s\n\nGenerate exactly %d personas with diverse and conflicting stances.",
    worldFacts, n,
)
```

The agent is told to return only JSON. The example then trims any surrounding text and unmarshals the result into Go structs. This is not glamorous, but it is a good example design: keep the LLM output boundary narrow, validate it, and fail loudly if the shape is wrong.

Each persona then becomes an agent with its own system prompt:

```go
systemPrompt := fmt.Sprintf(`You are %s in a social simulation.

Background: %s
Your stance: %s
Personality: %s

Stay fully in character. React authentically to what others say.
Do not break character or refer to yourself as an AI.
Keep your posts concise (3-5 sentences).`,
    p.Name, p.Background, p.Stance, p.Personality,
)
```

The persona memory is bounded:

```go
memCapacity := uint(roundsHint*2 + 10)
a.SetMemory(simplemem.New(memCapacity))
```

That matters because the persona should remember its own prior turns, but the simulation should still have predictable cost and context size.

## The world feed

The shared state in the example is not a social graph. It is a public transcript.

```go
type FeedEntry struct {
    Round  int
    Author string
    Post   string
}

type WorldFeed struct {
    mu      sync.Mutex
    entries []FeedEntry
}
```

Every post is appended to the feed. Before each round, agents receive the last `topk` entries:

```go
snapshot := s.feed.TopK(s.topk)
```

This is much simpler than a real social network. There is no follower graph, no ranking algorithm, no quote-post mechanic, no private messages. Everyone sees the same recent public square.

That simplicity is a tradeoff. You lose realism, but you gain inspectability. The whole simulation is a transcript you can read from top to bottom, and the report agent can cite round numbers and agent names directly.

## Running rounds concurrently

The core of the example is `Simulation.RunRound`.

For each round, the simulation takes a snapshot of the feed before starting any persona agents:

```go
snapshot := s.feed.TopK(s.topk)
results := make([]roundResult, len(s.agents))
```

Then it fans out to all agents using goroutines:

```go
for i, pa := range s.agents {
    wg.Add(1)

    go func(idx int, pa *personaAgent) {
        defer wg.Done()

        prompt := buildRoundPrompt(round, totalRounds, snapshot)
        out, err := pa.agent.Run(ctx, llm.Text(prompt))
        if err != nil {
            results[idx] = roundResult{err: fmt.Errorf("agent %q: %w", pa.name, err)}
            return
        }

        results[idx] = roundResult{
            entry: FeedEntry{
                Round:  round,
                Author: pa.name,
                Post:   strings.TrimSpace(out.TextContent()),
            },
        }
    }(i, pa)
}

wg.Wait()
```

The snapshot detail is important. If agents read the feed while other agents are writing to it, the order of goroutine scheduling would change what each persona sees. Instead, every agent in a round sees the same pre-round state. The posts are collected afterward in deterministic agent order.

This gives the example a useful property: concurrency improves latency without turning the simulation into a race-dependent mess.

## Turning the transcript into a report

After the final round, the full feed becomes a transcript:

```go
transcript := sim.Transcript()
```

The example writes it to `transcript.txt`, then sends it to the report agent together with the world facts:

```go
reportPrompt := fmt.Sprintf(
    "World facts:\n%s\n\nSimulation transcript:\n%s\n\nAnalyze this simulation and produce the report.",
    worldFacts, transcript,
)
```

The report agent has a fixed analytical structure:

```text
## Opinion Evolution
## Coalitions & Dynamics
## Key Inflection Points
## Final Outlook
```

This is where the transcript becomes useful. The report agent is not asked to summarize vibes. It is asked to cite agents, rounds, shifts, coalitions, and moments where the conversation changed direction.

The optional `--interact` flag opens a REPL with the same report agent. Because the agent has memory, follow-up questions can refer back to the report and transcript without manually pasting everything again.

## Cost and limits

The example prints the rough cost before it starts:

```go
estimatedCalls := numAgents*numRounds + 3
```

The default settings are 8 agents and 5 rounds, so the run makes about 43 LLM calls: one for world facts, one for personas, 40 persona posts, and one report.

That means the knobs matter:

```bash
go run . --agents 4 --rounds 3
go run . --agents 12 --rounds 8
```

Start small. Once the prompt and scenario produce useful behavior, scale up.

The README is explicit about the tradeoffs compared with MiroFish. This Phero example does not implement GraphRAG, long-term cloud memory, a million agents, or a dual-platform social graph. It uses flat world facts, bounded in-process memory, goroutine fan-out, and a shared feed.

That is exactly why it is a good example. The moving parts fit in a few files, and the architectural idea is visible.

## Try it

From the example directory:

```bash
cd examples/social-simulation
go run .
```

With a custom inline scenario:

```bash
go run . --seed "A city announces a pilot program converting downtown parking spaces into bike lanes, trees, and outdoor seating."
```

From a file:

```bash
go run . --seed ./article.txt --agents 12 --rounds 8
```

With interactive Q&A after the report:

```bash
go run . --interact
```

The OpenAI-compatible client is configured through environment variables:

```bash
export OPENAI_API_KEY="..."
export OPENAI_MODEL="gpt-4o"
export OPENAI_BASE_URL="https://api.openai.com/v1"
```

If no key or base URL is set, the example defaults to a local Ollama-compatible endpoint.

The interesting thing about this example is not that it forecasts the future. It does something more modest and more useful: it gives you a repeatable way to explore how disagreement can move through a small artificial public.

For product launches, policy drafts, incident communication, community management, or plain curiosity, that is often enough to reveal the question you should have asked earlier.

If you want to try it, start with [examples/social-simulation](https://github.com/henomis/phero/tree/main/examples/social-simulation).

If this sparked your curiosity, **[give Phero a star on GitHub](https://github.com/henomis/phero)**. It genuinely helps the project grow, and it takes three seconds.

*Phero is open source under the Apache 2.0 license. Contributions, issues, and discussions are welcome.*

*[GitHub](https://github.com/henomis/phero) · [pkg.go.dev](https://pkg.go.dev/github.com/henomis/phero) · [Examples](https://github.com/henomis/phero/tree/main/examples)*
