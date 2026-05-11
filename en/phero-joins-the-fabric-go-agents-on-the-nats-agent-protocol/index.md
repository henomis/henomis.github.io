# Phero joins the fabric: Go agents on the NATS Agent Protocol


[Synadia published the NATS Agent Protocol](https://www.synadia.com/blog/heterogeneous-agents-one-fabric) last week and the core idea is blunt: AI agents are already deployed everywhere (IDE, CI, support queue, factory floor) and none of them were built to talk to each other. The model isn't the bottleneck anymore. Coordinating the fleet you've already deployed is.

Their answer is a wire spec, not a framework. Two pages of contract on top of NATS micro services. An agent is a NATS service named `agents` with three endpoints: `prompt`, `status`, and `hb`. Discovery is one round-trip: `nats req '$SRV.INFO.agents'`. Multi-tenancy, cloud-to-edge, audit trail: all inherited from NATS, none of it written twice.

[Phero](https://github.com/henomis/phero) now speaks that protocol.

This post walks through what it looks like to put a Go agent on the fabric, how to discover and prompt agents from Go, and how `AsTool` turns a remote agent into something any local orchestrator can call.

## The protocol in one paragraph

Subjects follow `agents.{verb}.{agent}.{owner}.{name}`. Requests are plain UTF-8 text or a JSON envelope with optional base64 attachments. Responses stream typed JSON chunks (`response`, `status`, `query`) and terminate with an empty-body message. Errors ride on the `Nats-Service-Error` header.

That's it. There is no custom transport, no service registry, no API gateway configuration. If you can reach the NATS server you can reach every agent on it. Synadia already shipped TypeScript and Python SDKs. Phero adds Go.

## Putting a Phero agent on the fabric

The `nats` package adds two types to Phero: `Server` for hosting an agent, `Client` for discovering and calling agents. On the server side, any `agent.Agent` can be registered with `nats.New`:

```go
import (
    "github.com/henomis/phero/agent"
    natsagent "github.com/henomis/phero/nats"
    "github.com/henomis/phero/llm/openai"
    "github.com/henomis/phero/trace/text"
)

llmClient := openai.New(apiKey, openai.WithModel("gpt-4o-mini"))

a, err := agent.New(llmClient, "assistant",
    "You are a helpful assistant. Be concise and clear.")
a.SetTracer(text.New(os.Stderr))

srv, err := natsagent.New(nc, a, "alice", "demo",
    natsagent.WithAgentID("phero"),
    natsagent.WithHeartbeatInterval(10*time.Second),
)

if err := srv.Start(ctx); err != nil {
    log.Fatal(err)
}
```

`Start` blocks until the context is cancelled. When it returns, the agent has been shut down gracefully: in-flight prompt handlers are allowed to complete before the service unregisters.

From the moment `Start` is called the agent is:

- **Discoverable** via `$SRV.INFO.agents`: subject, protocol version, owner, name, and endpoint metadata are all included in the response
- **Streaming**: typed JSON chunks are written as the LLM produces tokens; a terminator signals end of response
- **Alive**: a heartbeat is published on `agents.hb.phero.alice.demo` every 10 seconds
- **Observable**: every LLM call, token count, and latency is emitted to stderr through the tracer

The prompt subject is printed at startup: `agents.prompt.phero.alice.demo`. Any client that speaks the protocol (Go, TypeScript, Python, or plain `nats req` from the terminal) can use it directly. No Phero library required on the caller side.

## Discovering and calling agents

The `Client` mirrors the caller SDK from Synadia. Discovery first, then prompt:

```go
c := natsagent.NewClient(nc,
    natsagent.WithDiscoveryTimeout(2*time.Second),
    natsagent.WithInactivityTimeout(60*time.Second),
)

agents, err := c.Discover(ctx,
    natsagent.FilterByOwner("alice"),
    natsagent.FilterByName("demo"),
)
if err != nil {
    log.Fatal(err) // ErrNoAgentsFound if nothing on the bus
}

stream, err := agents[0].Prompt(ctx, "What is NATS?")
if err != nil {
    log.Fatal(err)
}
defer stream.Close()

response, err := stream.Text(ctx)
fmt.Println(response)
```

`Discover` sends a single `$SRV.INFO.agents` fan-out request and collects responses using a stall strategy: it stops after 750 ms of silence from the last reply, capped by a 2 s absolute deadline. Results can be filtered by `agent`, `owner`, or `name` before the handles are returned.

`Stream.Text` reassembles the typed JSON chunks into a single string. Inactivity is tracked per-chunk: if no chunk arrives within the configured window, `ErrStreamTimeout` is returned. This enforces the protocol's liveness contract without a hard per-call deadline.

You can also call agents that aren't Phero. A Claude Code instance, an OpenClaw agent, a Pi Agent: they all respond to the same `$SRV.INFO.agents` subject with the same endpoint structure. `Discover` returns them alongside Phero agents. `Prompt` works on any of them.

## AsTool: the feature that ties it together

This is where the NATS protocol becomes genuinely useful for multi-agent Go code.

`AsTool` wraps any discovered agent as an `*llm.Tool`, the same type used for local tools like bash execution or file operations. The resulting tool can be handed directly to any Phero agent:

```go
// Discover a specialised coding agent on the fabric.
agents, err := c.Discover(ctx, natsagent.FilterByName("coder"))

// Wrap it as a tool the supervisor LLM can call.
coderTool, err := agents[0].AsTool("remote_coder",
    "A remote Go coding agent. Input: the coding task to perform.")

// Add it to a local orchestrator.
supervisor.AddTool(coderTool)
```

From the supervisor's perspective, calling the remote agent is identical to calling any other tool. The LLM decides when to invoke it and what prompt to send. The Go code around it is just orchestration. There is no bespoke RPC layer, no shared state, no custom serialization.

This is how you build a meta-agent that coordinates a heterogeneous fleet: discover the workers, wrap them as tools, let the LLM route. The workers can be Phero agents, Python agents, TypeScript agents, or anything else on the bus. The supervisor does not need to know what runtime they are using.

## Running it

Start NATS (one command), then the server and client in separate terminals:

```bash
# Terminal 1 — NATS
docker run --rm -p 4222:4222 nats

# Terminal 2 — server
go run ./examples/nats-agent/server -owner=alice -name=demo

LLM:     model=gpt-4o-mini
Subject: agents.prompt.phero.alice.demo
Press Ctrl-C to stop.

# Terminal 3 — client
go run ./examples/nats-agent/client

Discovering agents...
Found 1 agent(s):
  [1] agent=phero        owner=alice        name=demo         protocol=0.3

Connected to: phero/alice/demo
> What is NATS?
NATS is a lightweight, high-performance messaging system...
> /exit
Goodbye!
```

Or, without any SDK at all:

```bash
nats req '$SRV.INFO.agents' ''
nats req 'agents.prompt.phero.alice.demo' '{"prompt":"hello"}'
```

Phero agents show up in `nats micro list` alongside TypeScript and Python agents. Same subject pattern. Same response chunks. Same terminator. The spec is the interop contract; the runtime is an implementation detail.

![Phero on NATS Agent Protocol](/images/phero-nats-001.png)


## Why Go, why NATS

Go is already a good fit for production agent systems: static binaries, trivial cross-compilation to any target, sensible concurrency model, fast startup. The gap has been the ecosystem: most agent tooling is Python-first, and connecting Go to a Python-native protocol usually means writing an HTTP adapter and hoping the semantics hold.

The NATS Agent Protocol changes that. It is a NATS micro service spec, and Go has had a mature NATS client since day one. Phero's `nats` package does not wrap a Python SDK or talk to a sidecar. It speaks the protocol directly, is wire-compatible with the TypeScript and Python SDKs, and produces valid response chunks that any compliant caller can consume.

Single binary. No runtime dependency. Deploys to the edge the same way it deploys to the cloud.

## What Phero is

[Phero](https://github.com/henomis/phero) is an open-source Go framework for building multi-agent AI systems. Core primitives: `agent.Agent`, `llm.LLM` (OpenAI, Anthropic, or any OpenAI-compatible endpoint), `memory.Memory`, `llm.Tool`, RAG, MCP, and A2A. The design principle is interfaces over implementations: swap the LLM, swap the memory backend, swap the vector store, none of it changes the agent code.

The NATS package is the latest addition, adding a fourth interoperability story alongside HTTP/A2A, MCP tools, and sub-agent tools. All four are first-class, composable, and use the same `*llm.Tool` primitive as the integration point.

## Getting started

You need Go 1.25.5+ and a NATS server. No JetStream, no clustering required: plain core NATS.

```bash
docker run --rm -p 4222:4222 nats
go get github.com/henomis/phero
```

The complete working example (server, client, flag handling, Ollama fallback) is in the repository under [`examples/nats-agent/`](https://github.com/henomis/phero/tree/main/examples/nats-agent). Run it against a local model via Ollama if you don't want to spend API credits, then point the client at a TypeScript or Python agent from the [synadia-agents](https://github.com/synadia-ai/synadia-agents) repo to verify the interop story for yourself.

---

Phero is open-source on [GitHub](https://github.com/henomis/phero). If you're building on the NATS Agent Protocol, in Go or otherwise, I'd love to hear about it. And if Phero is useful to you, a star on the repo goes a long way.

