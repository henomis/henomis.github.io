# Go is the right language for production AI agents


AI agents are graduating from demos to production, and the infrastructure choices you make today will shape your system's reliability, cost, and scalability for years. The language you build on matters.

Go was designed for exactly the kind of systems that AI agents are: networked, concurrent, long-running services that need to be fast, small, and maintainable at scale. Yet most AI tooling still defaults to languages built for interactive data work, not production services.

This is an article about Go, production AI agents, and a framework called [Phero](https://github.com/henomis/phero) that shows what building multi-agent systems *should* look like.

## What Go brings to the table

Go was designed for networked services that need to be fast, small, and reliable under concurrency, which is exactly what an AI agent runtime is.

**Real concurrency without the ceremony.** Go's goroutines are cheap enough that you can run hundreds of concurrent agent tasks without a thread pool or a complex event loop. Spawning a goroutine costs about 2 to 4 KB of stack. When you're running a debate committee of six agents in parallel, this matters. It's just a `go func()`.

**Type safety that actually scales.** Go's static typing means the compiler catches your mistakes before runtime. When you define a tool's input struct, the JSON Schema is generated from Go's type system, with no runtime surprises. Your function receives a real typed struct; the LLM gets a precise schema.

**Single binary deploys.** `go build` produces a self-contained executable. No runtime to install, no dependency management at deploy time, no version conflicts. Your agent system is a binary. You ship the binary. Done.

**Tiny footprint.** A Go AI agent service can have a Docker image under 20 MB using a scratch base. At scale, the difference in cold start time and memory pressure is real money.

**Explicit error handling.** Go's explicit error returns mean failures are visible at every layer. There are no silently swallowed exceptions, no surprising `nil` results propagating through an agent loop undetected. Explicit is better than implicit.

## Introducing Phero

[Phero](https://github.com/henomis/phero) is a Go framework for building multi-agent AI systems. The name comes from pheromones, the chemical signals that ants use to coordinate without a central authority. Like ants in a colony, agents in Phero cooperate, communicate, and coordinate toward shared goals, each with specialized roles.

The framework is organized into focused packages:

- **`agent`**: the core orchestration loop: LLM call, tool execution, repeat until done
- **`llm`**: a clean interface over OpenAI-compatible endpoints and Anthropic
- **`memory`**: conversational context, in-process, file-backed, PostgreSQL-backed, or RAG-backed
- **`rag`**: full RAG pipeline with embeddings and vector stores (Qdrant, pgvector, Weaviate)
- **`skill`**: define reusable agent capabilities in Markdown files
- **`mcp`**: plug in any Model Context Protocol server as agent tools
- **`a2a`**: expose agents as HTTP servers or call remote agents as local tools
- **`trace`**: colorized human-readable traces and NDJSON file logging

Each package does one thing. You compose them. There's no magic, no hidden global state, no `init()` functions.

## Your first Phero agent in ~80 lines

Let's stop talking theory and look at code. This is a complete, runnable agent that uses a custom Go function as a tool.

First, get the module:

```bash
go get github.com/henomis/phero
```

No cloud account required. Phero supports [Ollama](https://ollama.com/) out of the box. Run a local model:

```bash
ollama pull llama3.2
```

Now the agent:

```go
package main

import (
    "context"
    "fmt"
    "os"

    "github.com/henomis/phero/agent"
    "github.com/henomis/phero/llm"
    "github.com/henomis/phero/llm/openai"
    "github.com/henomis/phero/trace/text"
)

// CalculatorInput defines the tool's parameters.
// The jsonschema tags become the JSON Schema that
// the LLM sees — no separate schema file needed.
type CalculatorInput struct {
    Operation string  `json:"operation" jsonschema:"description=The operation to perform,enum=add,enum=subtract,enum=multiply,enum=divide"`
    A         float64 `json:"a" jsonschema:"description=The first number"`
    B         float64 `json:"b" jsonschema:"description=The second number"`
}

// calculate is a plain Go function — the tool wraps it.
func calculate(_ context.Context, input *CalculatorInput) (float64, error) {
    switch input.Operation {
    case "add":
        return input.A + input.B, nil
    case "subtract":
        return input.A - input.B, nil
    case "multiply":
        return input.A * input.B, nil
    case "divide":
        if input.B == 0 {
            return 0, fmt.Errorf("division by zero")
        }
        return input.A / input.B, nil
    default:
        return 0, fmt.Errorf("unknown operation: %s", input.Operation)
    }
}

func main() {
    ctx := context.Background()

    // Point at Ollama running locally — no API key needed.
    client := openai.New("",
        openai.WithBaseURL(openai.OllamaBaseURL),
        openai.WithModel("llama3.2"),
    )

    // Wrap the Go function as an LLM tool.
    // JSON Schema is derived automatically from CalculatorInput.
    calcTool, err := llm.NewTool("calculator", "Performs basic arithmetic", calculate)
    if err != nil {
        panic(err)
    }

    // Create the agent.
    a, err := agent.New(
        client,
        "Math Assistant",
        "You are a helpful math assistant. Use the calculator tool for all arithmetic.",
    )
    if err != nil {
        panic(err)
    }

    // Attach a colorized tracer so you can see every LLM call and tool invocation.
    a.SetTracer(text.New(os.Stderr))

    if err := a.AddTool(calcTool); err != nil {
        panic(err)
    }

    // Run it.
    result, err := a.Run(ctx, "If I have 15 apples and give away 7, then buy 23 more, how many do I have?")
    if err != nil {
        panic(err)
    }

    fmt.Println(result.Content)
}
```

Run it:

```bash
go run main.go
```

You'll see something like this in your terminal (the tracer colorizes LLM calls, tool calls, and results in real time):

```
[math-agent] ▶ agent start  input="If I have 15 apples..."
[math-agent] ◈ llm call     model=llama3.2
[math-agent] ⚙ tool call    calculator  {"operation":"subtract","a":15,"b":7}
[math-agent] ✓ tool result  8
[math-agent] ⚙ tool call    calculator  {"operation":"add","a":8,"b":23}
[math-agent] ✓ tool result  31
[math-agent] ◈ llm call     model=llama3.2
[math-agent] ■ agent end    output="You have 31 apples."

You have 31 apples.
```

**That's it.** No frameworks with hundreds of indirect dependencies. No YAML configuration files. Just types, functions, and a clean runtime.

## What makes this different

Notice what happened in that code:

1. `CalculatorInput` is a plain Go struct with field tags.
2. `llm.NewTool` reads those tags via reflection at startup and generates a complete JSON Schema.
3. When the LLM calls the tool, Phero deserializes the JSON arguments directly into a `*CalculatorInput`, validated and typed.
4. Your function receives a real Go struct with compile-time type guarantees.

The same pattern works for complex nested types, enums, optional fields, and arrays, all derived from Go's type system. You write typed Go code; the LLM gets a precise schema; you get validated inputs. No separate schema definition files, no code generation step.

And because it's Go, running multiple agents in parallel needs no special framework support. It's just goroutines:

```go
go func() {
    result, err := a.Run(ctx, question)
    // ...
}()
```

Real OS threads. Real parallelism. Built into the language.

## The ant philosophy

The name Phero is intentional. Ant colonies are a fascinating model for distributed intelligence: no single ant knows the full plan, yet the colony achieves complex emergent behavior through local communication and specialized roles. There is no queen issuing commands. There is only the pheromone trail, a shared signal that coordinates without centralizing.

Phero is built on the same idea. Agents don't need a monolithic orchestrator. They need clean protocols to discover each other, hand off work, share context, and signal completion. The framework gives you those protocols (`AddHandoff`, `SetMemory`, `A2A`) and gets out of the way.

**The ant is not just a mascot. It is the philosophy.** 🐜

## What's next

This was the introduction. In the next article in this series, we'll move from the big picture to a practical walkthrough and show how simple it is to get a real agent running with Phero.

If this sparked your curiosity, **[give Phero a star on GitHub](https://github.com/henomis/phero)**. It genuinely helps the project grow, and it takes three seconds.

*Phero is open source under the Apache 2.0 license. Contributions, issues, and discussions are welcome.*

*[GitHub](https://github.com/henomis/phero) · [pkg.go.dev](https://pkg.go.dev/github.com/henomis/phero) · [Examples](https://github.com/henomis/phero/tree/main/examples)*

