# The supervisor-blackboard pattern: coordinating multi-agent AI workflows


Most multi-agent examples keep agents isolated. Each one gets a prompt, produces output, and hands it to the next step. That works when the data flows in one direction. But some workflows need agents to build on each other's work incrementally, reading and writing to a shared context. This is the blackboard pattern.

The idea comes from AI research in the 1970s. Multiple knowledge sources (agents) read from and write to a shared data structure (the blackboard). A control component (the supervisor) decides which agent to activate next. Each agent contributes partial results that other agents can use. The blackboard accumulates context over time.

In this post I'll walk through building a supervisor-blackboard system in Go using [Phero](https://github.com/henomis/phero). A supervisor coordinates three specialists through tool calls. All agents share a single memory instance. The supervisor drives the workflow, and each specialist sees what the others have written.

## What we're building

A CLI that performs a multi-step repo health-check:

1. A **Researcher** agent runs safe Go commands (`go list`, `go test`) and writes findings to the blackboard
2. A **Drafter** agent reads the findings from the blackboard and writes a report
3. A **Critic** agent reads both the findings and the draft, then produces a corrected version
4. A **Supervisor** agent coordinates the entire flow by calling specialists as tools

Here's what a run looks like:

```
multi-agent architecture example: supervisor + specialists + blackboard
- llm: model=gpt-4o
- goal: Do a quick health-check of this repo: list Go packages and run Go tests, then summarize.

[Supervisor calls research_repo]
  [Researcher calls run_go with args: ["list", "./..."]]
  [Researcher calls run_go with args: ["test", "./..."]]
  Researcher writes findings to blackboard

[Supervisor calls draft_report]
  Drafter reads blackboard, writes report

[Supervisor calls critique_report]
  Critic reads blackboard, produces improved report

=== Final Report ===
Commands run: go list ./... and go test ./...
Packages: 42 packages across agent/, llm/, memory/, tool/, ...
Tests: 38/42 packages pass. 4 failures in vectorstore/qdrant (connection refused).
Suggested next steps: check Qdrant connectivity or skip integration tests with -short flag.
```

The supervisor makes three tool calls. Each specialist reads the shared memory, contributes its work, and the memory accumulates. The final output is grounded in actual command output, not hallucination.

## Why a supervisor with a blackboard?

The previous patterns in this series (debate committee, evaluator-optimizer) use isolated agents. Each agent sees only what's explicitly passed to it. The supervisor-blackboard pattern is different in two ways.

**Delegation, not orchestration in Go.** In the evaluator-optimizer, Go code decides what to do next. Here, the supervisor agent decides. It has tools that represent other agents, and it chooses when to call them. This is useful when the workflow isn't strictly linear, when the supervisor might need to re-run research or skip the critic based on what it sees.

**Shared context without explicit passing.** In a pipeline, you manually thread output from one step into the next. With a blackboard, you inject the same memory instance into all agents. Each agent reads what came before and writes its contribution. This eliminates the boilerplate of formatting and passing intermediate results.

**Separation of capability.** The supervisor can't run commands. The researcher can't write reports. The critic can't gather data. Each agent has exactly the tools and instructions it needs. This is both a security property (the researcher's tool is sandboxed to `go list` and `go test`) and a prompt quality property (smaller, focused prompts produce better results than "do everything" prompts).

**Natural escalation.** If the critic finds problems, the supervisor can re-run the drafter. If the researcher fails, the supervisor can report the error. The decision logic lives in the LLM, not in a hardcoded state machine. For exploratory workflows where you don't know the exact steps in advance, this is the right trade-off.

## The architecture

```
              Supervisor (has tools: research_repo, draft_report, critique_report)
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
Researcher     Drafter       Critic
 (run_go)       (no tools)    (no tools)
    │             │             │
    └─────────────┴─────────────┘
                  │
          Shared Blackboard Memory
```

The supervisor calls specialists as tools via `Agent.AsTool(...)`. All four agents (supervisor included) share the same `memory.Memory` instance. When the researcher runs `go test` and summarizes the results, that summary goes into memory. When the drafter is called next, it sees the researcher's findings in its conversation history. The blackboard is the memory itself.

## Setting up the shared memory

The blackboard is a simple bounded memory with a 60-message capacity:

```go
import memory "github.com/henomis/phero/memory/simple"

shared := memory.New(60)
```

This single instance is injected into every agent. It stores messages in insertion order with a ring buffer, so older messages drop out if the conversation grows too long. For a typical health-check (a few tool calls and short reports), 60 messages is plenty.

The key property: when the supervisor calls the researcher via a tool, the researcher's messages (including tool calls and results) are appended to the same memory that the drafter and critic will read from. No explicit data passing required.

## The researcher: a tool-equipped specialist

The researcher is the only agent with direct tool access. It can run safe Go commands:

```go
researcher, _ := agent.New(llmClient, "Researcher Agent", strings.TrimSpace(`
You are a researcher agent in a multi-agent system.

You have access to the tool run_go. Use it to collect concrete evidence.

Rules:
- Only run 'go list' and 'go test'.
- Prefer at most TWO tool calls total.
- For a repo health-check, run:
  1) go list ./...
  2) go test ./...
- After running commands, write a short findings note with:
  - packages: (any interesting info + package count if easy)
  - tests: (pass/fail + key failures)
  - raw: include the command outputs (truncate if huge)

Be factual; do not speculate.`))
researcher.SetMemory(shared)
researcher.AddTool(goTool)
```

The prompt constrains the researcher to at most two commands. This is important. Without the constraint, an agent with a shell tool will happily run dozens of exploratory commands, burning tokens and time. Explicit limits keep the cost predictable.

## The restricted Go tool

The `run_go` tool is a Go function that only allows `go list` and `go test`. Any other subcommand is rejected:

```go
func runGo(ctx context.Context, in *GoRunInput) (*GoRunResult, error) {
    sub := in.Args[0]
    if sub != "test" && sub != "list" {
        return &GoRunResult{
            ExitCode: 2,
            Error: fmt.Sprintf("unsupported go subcommand: %s", sub),
        }, nil
    }

    cmd := exec.CommandContext(ctx, "go", in.Args...)
    out, _ := cmd.CombinedOutput()
    return &GoRunResult{ExitCode: 0, Output: string(out)}, nil
}
```

This is a deliberate security boundary. The agent sees a tool called `run_go` and might try `go run malicious.go` or `go install something`. The allowlist rejects everything except safe, read-only operations. The tool also validates arguments for injection characters (newlines) and wraps exit codes into a structured result rather than returning raw errors.

## The drafter: context from the blackboard

The drafter has no tools. It reads the blackboard (which now contains the researcher's findings) and writes a report:

```go
drafter, _ := agent.New(llmClient, "Drafter Agent", strings.TrimSpace(`
You are a technical writer agent.

Given the user's goal and the researcher's findings, write a concise report:
- What commands were run
- What the outputs show (grounded)
- Next suggested steps if something failed

Do not invent details. If the findings are missing, ask to re-run research.`))
drafter.SetMemory(shared)
```

Notice the last instruction: "If the findings are missing, ask to re-run research." This handles the case where the supervisor calls the drafter before the researcher. Because the drafter reads from shared memory, it can detect when the prerequisite data isn't there. The supervisor sees the drafter's response ("findings missing, please run research first") and can adjust.

## The critic: verification against evidence

The critic also reads the shared memory, but its job is adversarial. It checks the draft against the raw findings:

```go
critic, _ := agent.New(llmClient, "Critic Agent", strings.TrimSpace(`
You are a critic / verifier agent.

You will be given a draft report and the research findings.
Return:
- any claims not supported by the findings
- missing key observations
- a corrected, improved version of the report (keep it short)

Be direct and practical.`))
critic.SetMemory(shared)
```

The critic produces the final output. It's the last quality gate before the supervisor returns. Because it reads the same blackboard that contains both the raw tool output and the drafter's report, it can cross-reference claims against evidence.

## Exposing agents as tools

This is the core mechanism that makes the supervisor pattern work in Phero. Each specialist is wrapped as a tool using `Agent.AsTool(...)`:

```go
researchTool, _ := researcher.AsTool(
    "research_repo",
    "Delegate to the Researcher Agent to run safe 'go list'/'go test' and report findings.",
)

draftTool, _ := drafter.AsTool(
    "draft_report",
    "Delegate to the Drafter Agent to turn findings into a concise technical report.",
)

critiqueTool, _ := critic.AsTool(
    "critique_report",
    "Delegate to the Critic Agent to verify the draft against evidence and improve it.",
)
```

From the supervisor's perspective, these are just tools with names and descriptions. The supervisor doesn't know they're backed by LLM agents. It calls `research_repo` like it would call any other function. Under the hood, `AsTool` runs the full agent (prompt, memory, tool calls) and returns the text output as the tool result.

This is composable. You can nest it: an agent-as-tool can itself have agent-as-tool dependencies, creating hierarchies. But for most workflows, one level of delegation is sufficient.

## The supervisor: routing and coordination

The supervisor ties everything together. It has all three specialist tools and a prompt that defines the workflow order:

```go
supervisor, _ := agent.New(llmClient, "Supervisor Agent", strings.TrimSpace(`
You are a Supervisor/Router agent orchestrating specialists in a
blackboard-style multi-agent system.

You have tools that represent other agents:
- research_repo: runs safe Go commands and returns findings
- draft_report: writes a report based on findings
- critique_report: verifies the report against findings

Workflow (follow it):
1) Call research_repo once to gather evidence.
2) Call draft_report with the goal and the findings.
3) Call critique_report with the draft and the findings.
4) Output the final, corrected report.

Constraints:
- Do not run commands directly (only via research_repo).
- Keep the final report grounded in tool outputs.
- Keep it concise.`))
supervisor.SetMemory(shared)
supervisor.AddTool(researchTool)
supervisor.AddTool(draftTool)
supervisor.AddTool(critiqueTool)
```

The workflow is specified in the prompt, not in Go code. This means the supervisor can deviate if needed. If the researcher returns an error, the supervisor can skip drafting and report the failure directly. If the critic says the draft is perfect, the supervisor can output it without further revision. The prompt is a guideline, not a hardcoded state machine.

## The blackboard in practice

Here's what the shared memory looks like after a full run (conceptually):

```
[1] User: Do a quick health-check of this repo...
[2] Supervisor: (calls research_repo)
[3] Researcher: (calls run_go ["list", "./..."])
[4] Tool result: github.com/henomis/phero/agent\ngithub.com/henomis/phero/llm\n...
[5] Researcher: (calls run_go ["test", "./..."])
[6] Tool result: ok github.com/henomis/phero/agent 1.2s\nFAIL github.com/...
[7] Researcher: "Findings: 42 packages, 4 test failures in..."
[8] Supervisor: (calls draft_report)
[9] Drafter: "Report: Commands run: go list, go test. Results show..."
[10] Supervisor: (calls critique_report)
[11] Critic: "The draft correctly states 42 packages. However, it misses..."
[12] Supervisor: (outputs final report)
```

Every agent reads from message 1 onward when it's invoked. The drafter at step [8] sees messages [1]-[7]. The critic at step [10] sees messages [1]-[9]. Context accumulates naturally. No explicit threading.

The trade-off: memory grows with each step. For a three-step workflow this is fine. For a 20-step workflow with long tool outputs, you'd hit context limits. The ring buffer (capacity 60) provides a safety valve, but you should also consider summarization for longer workflows.

## Running the example

```bash
# With OpenAI
export OPENAI_API_KEY=sk-...
go run ./examples/supervisor-blackboard

# With a custom goal
go run ./examples/supervisor-blackboard \
    -goal "Run go tests and summarize what failed"

# With Ollama
export OPENAI_BASE_URL=http://localhost:11434/v1
export OPENAI_MODEL=gpt-oss:20b-cloud
go run ./examples/supervisor-blackboard

# With a longer timeout for slow models
go run ./examples/supervisor-blackboard -timeout 10m
```

The default goal is a repo health-check: list packages, run tests, summarize results.

## Cost and latency

This pattern makes multiple LLM calls, but the exact number depends on the supervisor's decisions and each specialist's behavior. A typical run:

- Supervisor: 1 call to decide to invoke research_repo
- Researcher: 1 call to plan + 2 tool calls + 1 call to summarize = 2 LLM calls
- Supervisor: 1 call to invoke draft_report
- Drafter: 1 LLM call
- Supervisor: 1 call to invoke critique_report
- Critic: 1 LLM call
- Supervisor: 1 call to produce final output

That's roughly 7-8 LLM calls total. More than the evaluator-optimizer (4 calls) or the debate committee (4 calls), but this pattern does more: it gathers real data, writes a report, and verifies it.

The calls are sequential because each step depends on the blackboard state from the previous step. Parallelization isn't possible here, which is the right trade-off for a workflow where each step builds on the last.

## When to use this pattern

The supervisor-blackboard pattern shines when:

- **You need real-world interaction.** One or more agents use tools (APIs, shells, databases). The supervisor coordinates which agent acts when.
- **Workflow order is flexible.** The supervisor can re-run steps, skip steps, or add steps based on intermediate results. A Go loop can't adapt.
- **Specialists have different capabilities.** Security boundaries matter. The researcher can run commands; the drafter and critic cannot. You wouldn't give a report-writing agent shell access.
- **Context needs to accumulate.** Each agent builds on what came before. Passing all intermediate results explicitly would be verbose and error-prone.

When not to use it: if your workflow is strictly linear and deterministic, a simple Go loop (like the evaluator-optimizer) is simpler and cheaper. The supervisor adds LLM calls for routing decisions that a Go `for` loop makes for free.

## Variations

**Dynamic specialist selection.** Instead of a fixed workflow in the prompt, give the supervisor a larger toolbox and let it decide which specialists to call based on the goal. "Run security audit" might call a different set of specialists than "run performance benchmark."

**Multiple researchers.** Add specialized researcher agents: one for Go, one for Docker, one for CI config. The supervisor routes to the appropriate researcher based on the goal. Each researcher has its own restricted tools.

**Iterative refinement.** After the critic produces feedback, the supervisor can re-call the drafter with the criticism. This combines the blackboard pattern with the evaluator-optimizer loop. The supervisor decides when quality is sufficient.

**Persistent blackboard.** Replace the in-memory ring buffer with a persistent store (file, database). This lets you resume workflows across process restarts or share the blackboard between distributed agents.

## Wrapping up

The supervisor-blackboard pattern gives you the most flexibility of any multi-agent architecture. The supervisor decides what to do, specialists have focused capabilities, and shared memory eliminates the plumbing of passing data between steps.

The key insight is that `Agent.AsTool(...)` collapses the distinction between tools and agents. From the supervisor's perspective, calling a specialist is no different from calling a function. This makes the architecture composable: you can nest supervisors, mix tool-equipped and pure-language agents, and add or remove specialists without changing the orchestration logic.

The trade-off is cost. Every routing decision is an LLM call. For workflows where the order is always the same, a Go loop is cheaper. But for exploratory, adaptive workflows where the next step depends on what you found in the previous one, the supervisor earns its keep.

The full source is at [`examples/supervisor-blackboard/`](https://github.com/henomis/phero/tree/main/examples/supervisor-blackboard).

*[Phero](https://github.com/henomis/phero) is an open-source Go framework for building multi-agent AI systems. Star the repo if you find it useful.*

