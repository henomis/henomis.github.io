---
date: '2026-04-18T12:54:44+02:00'
title: 'Building a conversational agent in Go'
tags: ["Go", "LLM", "AI", "Agents", "Phero"]
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
featuredImage: "/images/phero004.png"
images: ["/images/phero004.png"]
cover:
    image: "/images/phero004.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

Large Language Models are stateless by design. Each API call starts from scratch. The model has no idea what you said thirty seconds ago unless you explicitly pass the conversation history back in. This is a fundamental constraint of the request/response paradigm: the model is a function, not a process.

But real conversations need memory. The user says "my name is Alice" in turn one, and expects the assistant to remember it in turn ten. They build on previous answers, refer back to earlier context, and assume continuity. Bridging this gap between stateless inference and stateful dialogue is one of the first problems you hit when building any conversational system.

In this post I'll walk through building a full conversational agent in Go using [Phero](https://github.com/henomis/phero), showing how memory, tools, and automatic summarization come together in ~200 lines of code.

## What we're building

An interactive terminal chatbot that:

- Maintains a multi-turn conversation with persistent memory
- Can call tools (e.g. get the current time)
- Optionally summarizes older messages to keep context windows manageable
- Reports per-turn metrics: iterations, token usage, latency

Here's what a session looks like:

```
🤖 Conversational Agent (with Memory)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LLM: model=gpt-4o
Memory: 20 messages max
Summarization: disabled

> Hi, my name is Simone. I'm building a Go framework for AI agents.

Hello Simone! That sounds like an exciting project. What's the framework called?

📈 Run summary: iterations=1 llm_calls=1 tool_calls=0 memory=0/2 tokens=45/18 latency=892ms

> It's called Phero. What time is it?

Nice name! Here's the current time: 2026-04-18T14:32:07+02:00.

📈 Run summary: iterations=2 llm_calls=2 tool_calls=1 memory=2/4 tokens=128/31 latency=1.4s

> What's my name and what am I working on?

You're Simone, and you're building Phero, a Go framework for AI agents.

📈 Run summary: iterations=1 llm_calls=1 tool_calls=0 memory=4/6 tokens=180/22 latency=650ms
```

The agent remembered the name, the project, and used a tool to check the time, all without any manual state management.

## The architecture

Most agent frameworks hide the control flow behind abstractions that are hard to reason about. When something goes wrong (the model loops, a tool fails, memory is stale) you're left guessing what happened inside a black box.

Phero takes the opposite approach. The agent loop is explicit and easy to follow:

```
User Input → Agent.Run()
  ├─ Retrieve conversation history from memory
  ├─ Build messages: [system prompt, memory, user message]
  ├─ Loop:
  │   ├─ Call LLM with messages + available tools
  │   ├─ If tool calls → execute each → append results → loop
  │   └─ If no tool calls → return assistant response
  ├─ Save new messages back to memory
  └─ Return Result (text + run summary)
```

There are three key pieces: the **agent**, the **memory**, and the **tools**. Let's look at each.

## Setting up the LLM client

One of the practical realities of building with LLMs is that you'll switch providers. Maybe you start with OpenAI, move to a self-hosted model for cost, or test against multiple backends for quality. If your agent code is coupled to a specific SDK, every switch means a rewrite.

Phero uses an `llm.LLM` interface that any provider can implement. The interface has a single method: `Execute(ctx, messages, tools) (*Result, error)`. For this example we use the OpenAI-compatible backend, which also works with local servers like Ollama:

```go
import (
    "github.com/henomis/phero/llm/openai"
)

client := openai.New(apiKey, openai.WithModel("gpt-4o"))
```

If you prefer a local model, just point it at Ollama:

```go
client := openai.New("", 
    openai.WithModel("llama3"),
    openai.WithBaseURL(openai.OllamaBaseURL),
)
```

Same interface, same agent code. Swap the backend, everything else stays the same.

## Creating the agent

The term "agent" gets overloaded in AI discussions. Here it means something specific: a loop that calls an LLM, inspects the response, executes any requested tool calls, and feeds the results back until the model produces a final answer. It's the ReAct (Reason + Act) pattern, made concrete.

An agent needs three things: an LLM, a name, and a system prompt.

```go
a, err := agent.New(
    client,
    "Conversational Assistant",
    "You are a helpful, friendly conversational assistant. "+
        "Maintain context from previous messages. Be concise but personable.",
)
if err != nil {
    panic(err)
}
```

The name identifies the agent in traces and handoff scenarios. The description becomes the system message sent to the LLM on every turn.

## Adding memory

Memory is what turns a single-shot Q&A into a conversation. The naive approach is to prepend the entire chat history to every request. This works until it doesn't: context windows have limits, token costs scale linearly, and latency grows with every turn. A good memory system needs to be selective about what it keeps and how it presents it.

Without memory, each call to `agent.Run()` would be independent. The memory interface in Phero is deliberately minimal, three methods:

```go
type Memory interface {
    Save(ctx context.Context, messages []llm.Message) error
    Retrieve(ctx context.Context, query string) ([]llm.Message, error)
    Clear(ctx context.Context) error
}
```

For a conversational agent, the `simple` memory backend is a good fit. It's a thread-safe in-process ring buffer with a fixed capacity:

```go
import memory "github.com/henomis/phero/memory/simple"

conversationMemory := memory.New(20) // keep up to 20 messages
a.SetMemory(conversationMemory)
```

When the buffer is full, the oldest messages are silently dropped. For many use cases this is fine. But for longer conversations, you might want something smarter.

### Automatic summarization

Dropping old messages is simple but lossy. The user mentioned their name twenty messages ago, and now it's gone. A better strategy is to compress older context into a summary that preserves the essential facts while fitting in fewer tokens. This is the same idea behind how humans remember conversations: you don't recall every word, but you retain the key points.

The simple memory backend supports opt-in summarization. When enabled, it uses the LLM itself to compress older messages into a structured summary before they'd be lost:

```go
conversationMemory := memory.New(20,
    memory.WithSummarization(client, 8, 15),
)
```

The parameters are:
- **Threshold (8)**: when the buffer reaches 8 messages, trigger summarization
- **Summary size (15)**: after summarizing, keep the 15 most recent messages plus the summary

The summarization prompt asks the LLM to produce a "State Snapshot" covering:

1. **Entities & Facts**: key people, technologies, data points
2. **User Preferences**: likes, dislikes, style requirements
3. **Current Progress**: what's been accomplished, problems solved
4. **Open Loops**: pending questions, unresolved tasks

The result is stored as a system message at the start of the conversation, so the agent retains context from earlier turns without paying the full token cost.

## Adding tools

A conversational agent that can only generate text is limited. The real power comes when the model can take actions: check the time, query a database, read a file, call an API. The function calling protocol (pioneered by OpenAI and now supported by most providers) lets the model request a structured function call instead of producing text. The agent executes the function and feeds the result back, allowing the model to incorporate real-world data into its response.

In Phero, tools are Go functions with typed input and output structs. The JSON Schema that the LLM needs is generated automatically from struct tags:

```go
type TimeInput struct{}

type TimeOutput struct {
    CurrentTime string `json:"current_time" jsonschema:"description=The current local time in RFC3339 format"`
}

func getCurrentTime(_ context.Context, _ *TimeInput) (*TimeOutput, error) {
    return &TimeOutput{
        CurrentTime: time.Now().Format(time.RFC3339),
    }, nil
}
```

Register it with the agent:

```go
timeTool, err := llm.NewTool(
    "get_current_time",
    "Get the current local time",
    getCurrentTime,
)
if err != nil {
    panic(err)
}
a.AddTool(timeTool)
```

When the user asks "what time is it?", the LLM decides to call `get_current_time`. The agent executes the Go function, feeds the result back, and the LLM formulates a natural language response. This tool-call loop can repeat multiple times per turn. `SetMaxIterations` caps it:

```go
a.SetMaxIterations(10)
```

## The conversation loop

With the agent configured (LLM, memory, tools), the application layer is thin. The complexity lives in the agent loop, not in the code that drives it.

The REPL is straightforward: read a line, call `agent.Run()`, print the response.

```go
response, err := a.Run(ctx, llm.Text(line))
if err != nil {
    fmt.Printf("Error: %v\n", err)
} else {
    fmt.Println(response.TextContent())
}
```

`llm.Text()` creates a text content part. Phero also supports multimodal input. You can mix `llm.Text()` with `llm.ImageURL()` or `llm.ImageFile()` in the same call.

## Observability: run summaries

When you're building with LLMs, "it works" is not enough. You need to know *how* it works: how many LLM calls did this turn take? Did the model use a tool or answer directly? How many tokens were consumed? Where did the latency come from? Without this visibility, debugging is guesswork and cost estimation is impossible.

Every call to `Run()` returns a `RunSummary` with detailed metrics:

```go
type RunSummary struct {
    AgentName       string
    Iterations      int
    LLMCalls        int
    ToolCalls       int
    ToolErrors      int
    MemoryRetrieved int
    MemorySaved     int
    Usage           UsageSummary    // InputTokens, OutputTokens
    Latency         LatencySummary  // Total, LLM, Tool, Memory
    Tools           []ToolCallSummary
}
```

This makes it easy to track costs and debug performance:

```
📈 Run summary: iterations=2 llm_calls=2 tool_calls=1 memory=2/4 tokens=128/31 latency=1.4s
```

Two LLM calls (one that triggered the tool, one after the tool result), one tool execution, four messages saved to memory, 128 input tokens, 31 output tokens. No guessing.

For deeper inspection, attach a tracer:

```go
import texttracer "github.com/henomis/phero/trace/text"

a.SetTracer(texttracer.New(os.Stderr))
```

This prints colorized, human-readable lifecycle events (LLM requests/responses, tool calls/results, memory operations) directly to the terminal.

## Running the example

Clone the repo and run:

```bash
# With OpenAI
export OPENAI_API_KEY=sk-...
go run ./examples/conversational-agent/

# With Ollama (no API key needed)
go run ./examples/conversational-agent/

# With summarization enabled
go run ./examples/conversational-agent/ -summarize -summary-threshold 8 -summary-size 15
```

Use `/history` to inspect the conversation buffer, `/stats` to see message counts by role, and `/clear` to reset.

## What to try next

This example is deliberately minimal. A production conversational agent would likely need persistent storage, richer tools, and structured logging. Phero's interface-driven design means each of these is a swap, not a rewrite. From here you can:

- **Swap memory backends**: use `memory/jsonfile` to persist conversations across restarts, `memory/psql` for PostgreSQL, or `memory/rag` for semantic retrieval
- **Add more tools**: file I/O, web search, database queries. Any `func(context.Context, *Input) (*Output, error)` works
- **Plug in MCP servers**: connect external tool servers via the Model Context Protocol
- **Add tracing**: use `trace/text` for development or `trace/jsonfile` for production logging
- **Build multi-agent workflows**: use agent handoffs to delegate to specialized agents mid-conversation

## Wrapping up

The gap between "call an LLM API" and "have a useful conversation" is mostly about plumbing: managing message history, executing tool calls, capping iteration loops, tracking costs. None of it is conceptually hard, but getting it right and keeping it maintainable matters.

Building a conversational agent with memory in Go doesn't require a heavy framework. Phero gives you composable primitives (an agent loop, a memory interface, typed tools, and observability) and stays out of the way.

The full source is at [`examples/conversational-agent/`](https://github.com/henomis/phero/tree/main/examples/conversational-agent).

*[Phero](https://github.com/henomis/phero) is an open-source Go framework for building multi-agent AI systems. Star the repo if you find it useful.*

