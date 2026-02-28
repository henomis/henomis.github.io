---
title: "How to build an AI agent from scratch in Go"
date: 2026-02-28T13:00:55+01:00
tags: ["go", "ai", "agents", "openai", "ollama"]
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
featuredImage: "/images/goagent001.png"
cover:
    image: "/images/goagent001.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

Hi, I’m Simone Vellei — you might remember me from such Go-and-AI adventures as “[Leveraging Go and Redis for Efficient Retrieval Augmented Generation](https://simonevellei.com/leveraging-go-and-redis-for-efficient-retrieval-augmented-generation/)” and “[Empowering Go: unveiling the synergy of AI and Q&A pipelines](https://simonevellei.com/empowering-go-unveiling-the-synergy-of-ai-and-qa-pipelines/)”

I’m the creator of [LinGoose](https://github.com/henomis/lingoose), an open-source framework built to make developing AI-powered applications in Go clean, modular, and production-friendly. I built it because I love Go’s simplicity and performance, and I wanted the same elegance when working with large language models.

Over the last few years, AI APIs from OpenAI have made it remarkably easy to add powerful reasoning capabilities to applications. At the same time, tools like Ollama allow us to run cutting-edge models locally using an OpenAI-compatible interface.

That combination opens up something exciting:

- Write your agent once
- Run it in the cloud or locally
- Switch endpoints without rewriting your logic

In this tutorial, we won’t rely on heavy abstractions or magic frameworks. Instead, we’ll build a simple but real AI agent from scratch in Go. By the end, you’ll understand:

- What an “agent” actually is (beyond the buzzword)
- How to implement an agent loop
- How to add tool calling
- How to handle multi-step reasoning
- How to switch between OpenAI and Ollama with a single configuration change

If you’ve ever wanted to deeply understand how agents work under the hood — not just call a library and hope for the best — you’re in the right place.

Let’s build one.

# What is an agent (really)?

Before we write a single line of Go, we need to clarify something important:

An **LLM is not an agent**.

A large language model is just a function: `f(prompt) → completion`

You send text in.
You get text out.
That’s it.

An **agent**, on the other hand, is a *system built around* a model.


## The mental model

If you strip away the hype, an agent is just this loop:

1. Receive input
2. Ask the model what to do next
3. If the model wants to use a tool → execute it
4. Feed the result back to the model
5. Repeat until done

That’s it.

No magic.
No consciousness.
Just structured iteration.


## The 4 core components of a minimal agent

Let’s break it down.

### The model

This is the reasoning engine.

We’ll be using the OpenAI-compatible API so our code can work with:

* OpenAI models in the cloud
* Ollama models running locally

From the model’s perspective, it doesn’t “execute” anything. It simply decides:

* Should I respond directly?
* Or should I call a tool?


### Tools

Tools are just functions your program can execute.

For example:

* `web_search(query string)`
* `get_weather(city string)`
* `run_sql(query string)`
* `calculate(expression string)`

The model doesn’t execute these directly.
It emits structured JSON saying:

> “Please call `web_search` with this argument.”

Your Go program parses that, executes the function, and returns the result to the model.

This is how language models gain **real-world capability**.


### Memory

Agents need context.

At minimum, that’s just a slice of messages:

* System prompt
* User messages
* Assistant messages
* Tool results

Every iteration sends the full conversation back to the model.

No memory = no continuity.

In this tutorial, we’ll use in-memory conversation history. Later you can swap that for a database, Redis, or a vector store.


### The loop

This is the part most people skip — but it’s the most important.

A basic agent loop looks like:

```
for not finished {
    call model
    if tool requested:
        execute tool
        append tool result
    else:
        break
}
```

That loop is what turns a one-shot completion into a multi-step reasoning system.


## Why iteration matters

If you only allow a single tool call, you don’t have much of an agent. You have a fancy RPC router.

Real agents often need to:

* Refine a query
* Perform multiple searches
* Compare results
* Summarize findings
* Validate their own output

That requires **multiple passes through the loop**.

And that’s exactly what we’ll implement.

## The minimal architecture

Here’s the high-level flow we’re going to build:

```
User Input
    ↓
Append to Messages
    ↓
Call ChatCompletion API
    ↓
Model decides:
    ├─ Return final answer → DONE
    └─ Request tool call
            ↓
        Execute tool in Go
            ↓
        Append tool result
            ↓
        Loop again
```

Simple. Explicit. Powerful.


## Why we’re building it from scratch

Yes, frameworks exist.
Yes, higher-level abstractions exist.

But when you build the loop yourself:

* You understand exactly what’s happening.
* You can debug it.
* You can extend it.
* You’re not locked into someone else’s opinionated architecture.

As the author of [LinGoose](https://github.com/henomis/lingoose), I care deeply about abstractions — but I also believe you should understand the foundation before using one.

And the foundation of every agent is this loop.


# Let’s build the agent

In the previous section, we defined an agent as:

* A **model**
* A set of **tools**
* Some **memory**
* A **loop**

Now we’ll implement exactly that.

This time, we’ll break the code into meaningful chunks — but every chunk will be shown exactly as it appears in the final file.

At the end, you’ll be able to copy a full working `main.go`.

We are using [go-openai](https://github.com/sashabaranov/go-openai) that supports both OpenAI and Ollama out of the box.

## Imports and entry point

We start with our package and imports.

```go
package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	openai "github.com/sashabaranov/go-openai"
)
```

Nothing special here — just standard Go and the OpenAI SDK.

## Bootstrapping the client

Now we begin `main()` and configure the API client.

```go
func main() {
	ctx := context.Background()

	apiKey := os.Getenv("OPENAI_API_KEY")
	baseURL := os.Getenv("OPENAI_BASE_URL") // e.g. http://localhost:11434/v1 (Ollama)

	config := openai.DefaultConfig(apiKey)

	if baseURL != "" {
		config.BaseURL = baseURL
	}

	client := openai.NewClientWithConfig(config)
```

### What’s happening?

* We read the API key.
* We optionally override the base URL.
* If `OPENAI_BASE_URL` is set, we can talk to Ollama.
* Otherwise, we talk to OpenAI’s cloud API.

This is our **model layer** we defined earlier.

Same code. Different backend.

## Model selection

```go
	model := os.Getenv("MODEL")
	if model == "" {
		// OpenAI: gpt-4o-mini
		// Ollama: llama3
		model = "gpt-4o-mini"
	}
```

We keep the model configurable.

## Memory initialization

Now we define our message history — the agent’s memory.

```go
	messages := []openai.ChatCompletionMessage{
		{
			Role: openai.ChatMessageRoleSystem,
			Content: `You are an assistant that can only help the user by using the available tools provided to you.`,
		},
	}
```

This slice will grow over time:

* User messages
* Assistant responses
* Tool results

This is the **memory component** of our agent.


## Registering tools

Next, we declare which tools the model is allowed to call.

```go
	tools := buildTools()
```

We’ll define `buildTools()` later.


## CLI loop

Now we create a simple REPL so we can interact continuously.

```go
	reader := bufio.NewReader(os.Stdin)

	fmt.Println("Simple Go Agent (type 'exit' to quit)")
	for {
		fmt.Print("\n> ")
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		if input == "exit" {
			return
		}
```

When the user types something, we append it to memory:

```go
		messages = append(messages, openai.ChatCompletionMessage{
			Role:    openai.ChatMessageRoleUser,
			Content: input,
		})
```


## The agent loop

Now comes the core logic — the loop that turns a model into an agent.

```go
		for {
			resp, err := client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
				Model:    model,
				Messages: messages,
				Tools:    tools,
			})
			if err != nil {
				log.Fatal(err)
			}

			msg := resp.Choices[0].Message
			messages = append(messages, msg)
```

We send:

* Full memory
* Tool definitions

The model decides:

* Respond normally
* Or call a tool

## If the model calls a tool

```go
			if len(msg.ToolCalls) > 0 {
				for _, toolCall := range msg.ToolCalls {
					result := handleToolCall(toolCall)

					messages = append(messages, openai.ChatCompletionMessage{
						Role:       openai.ChatMessageRoleTool,
						Content:    result,
						ToolCallID: toolCall.ID,
					})
				}
				continue
			}
```

Important:

* We execute every tool call.
* We append tool results to memory.
* We `continue` the loop.

That means we go back to the model with updated context.

This is the **iteration mechanism** we discussed previously.

## If the model does not call a tool

```go
			fmt.Println("\nAssistant:", msg.Content)
			break
		}
	}
}
```

If there are no tool calls:

* We print the final answer.
* We break the inner loop.
* The outer loop continues waiting for new user input.

That completes `main()`.

## Tool definitions

Now we define the tools exposed to the model.

```go
func buildTools() []openai.Tool {
	return []openai.Tool{
		{
			Type: openai.ToolTypeFunction,
			Function: &openai.FunctionDefinition{
				Name:        "get_time",
				Description: "Returns the current server time",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
	}
}
```

We expose one function:

```
get_time()
```

The model can choose to call it.


## Tool execution logic

Finally, we implement the real Go function that handles tool calls.

```go
func handleToolCall(tc openai.ToolCall) string {
	switch tc.Function.Name {

	case "get_time":
		return fmt.Sprintf(
			"Current server time: %s",
			time.Now().UTC().Format(time.RFC3339),
		)

	default:
		return "unknown tool"
	}
}
```

The model doesn’t execute anything.

It only emits structured intent.

Your Go code performs the actual work.


## Full code
Here’s the complete `main.go` with all the pieces together.

{{< details summary="Click to expand" >}}
```go
package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	openai "github.com/sashabaranov/go-openai"
)

func main() {
	ctx := context.Background()

	apiKey := os.Getenv("OPENAI_API_KEY")
	baseURL := os.Getenv("OPENAI_BASE_URL") // e.g. http://localhost:11434/v1 (Ollama)

	config := openai.DefaultConfig(apiKey)

	if baseURL != "" {
		config.BaseURL = baseURL
	}

	client := openai.NewClientWithConfig(config)

	model := os.Getenv("MODEL")
	if model == "" {
		// OpenAI: gpt-4o-mini
		// Ollama: llama3
		model = "gpt-4o-mini"
	}

	messages := []openai.ChatCompletionMessage{
		{
			Role:    openai.ChatMessageRoleSystem,
			Content: `You are an assistant that can only help the user by using the available tools provided to you.`,
		},
	}

	tools := buildTools()

	reader := bufio.NewReader(os.Stdin)

	fmt.Println("Simple Go Agent (type 'exit' to quit)")
	for {
		fmt.Print("\n> ")
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		if input == "exit" {
			return
		}

		messages = append(messages, openai.ChatCompletionMessage{
			Role:    openai.ChatMessageRoleUser,
			Content: input,
		})

		for {
			resp, err := client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
				Model:    model,
				Messages: messages,
				Tools:    tools,
			})
			if err != nil {
				log.Fatal(err)
			}

			msg := resp.Choices[0].Message
			messages = append(messages, msg)

			// If model calls a tool, execute it
			if len(msg.ToolCalls) > 0 {
				for _, toolCall := range msg.ToolCalls {
					result := handleToolCall(toolCall)

					messages = append(messages, openai.ChatCompletionMessage{
						Role:       openai.ChatMessageRoleTool,
						Content:    result,
						ToolCallID: toolCall.ID,
					})
				}
				continue
			}

			fmt.Println("\nAssistant:", msg.Content)
			break
		}
	}
}

func buildTools() []openai.Tool {
	return []openai.Tool{
		{
			Type: openai.ToolTypeFunction,
			Function: &openai.FunctionDefinition{
				Name:        "get_time",
				Description: "Returns the current server time",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
	}
}

func handleToolCall(tc openai.ToolCall) string {
	switch tc.Function.Name {

	case "get_time":
		return fmt.Sprintf("Current server time: %s", time.Now().UTC().Format(time.RFC3339))

	default:
		return "unknown tool"
	}
}
```
{{< /details >}}

# Seeing the Agent in Action

Now that we have the agent running, let’s take a look at an actual execution round. This helps connect the theory and code from the previous chapters to a tangible experience.

When we start the program, we see a simple CLI prompt using ollama and the `ministral-3:3b` model with tools enabled:

```shell
$ OPENAI_BASE_URL=http://localhost:11434/v1 MODEL=ministral-3:3b go run main.go 

Simple Go Agent (type 'exit' to quit)
> 
```

Here’s an example interaction:

```shell
> what can you do?

Assistant: Since I’m an assistant that operates within specific constraints, here’s what I can do:

1. **Provide General Assistance and Information**
   Answering questions about a wide variety of topics, including current events within reason, explaining concepts, or providing recommendations.

2. **Gather Current Time**
   Inform you of the current server time using the `get_time` function.

**Limitations:**
- I can’t browse the internet or access real-time, external tools beyond what’s allowed.
- I cannot execute code, perform calculations beyond basic math, or access personal/private information without permission.
- I don’t have the ability to browse the web or retrieve live data in real-time due to system constraints.
```

Here, the agent correctly:

* Uses its **memory** to track the user request.
* Explains its **capabilities and limitations**, reflecting the system prompt we defined.
* Highlights the **available tool**, `get_time()`, which it can call.

Next, we ask it to execute the tool:

```shell
> what is the current server time?

Assistant: The current server time is **February 28, 2026, at 12:50 PM**. How else can I assist you today?
```

Notice how:

1. The model emits a structured intent to call the tool (`get_time`).
2. Our Go program executes the function.
3. The result is appended back to memory and displayed to the user.

This round illustrates the **core agent loop** in action:

* Receive input → Decide → Call tool if needed → Append result → Respond.

It’s exactly what we outlined: memory, tools, model, and loop. All working together to produce a multi-step, interactive AI assistant.

## What we’ve built

Let’s map it back to theory:

| Component | Where It Lives         |
| --------- | ---------------------- |
| Model     | `CreateChatCompletion` |
| Tools     | `buildTools()`         |
| Memory    | `messages` slice       |
| Loop      | Inner `for {}`         |

That’s an agent.

Simple.
Explicit.
Extendable.

{{< admonition type=note title="What's next?" open=true >}}
In the next article, we’ll make it more powerful by allowing multiple reasoning and tool iterations before the model reaches a final answer.
{{< /admonition >}}