---
date: '2026-03-01T17:30:15+01:00'
title: 'Designing multi-agent architectures in Go'
tags: ["go", "ai", "agents", "openai", "ollama", "multi-agent"]
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
featuredImage: "/images/goagent003.png"
images: ["/images/goagent003.png"]
cover:
    image: "/images/goagent003.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

In the [previous article](https://simonevellei.com/en/building-a-stateful-multi-tool-agent-in-go/), we built a capable agent with multiple tools with real capabilities (Python, HTTP, time). It worked.

But there's a problem with that design.

As you add more tools, the agent needs to:

* Track all tool definitions
* Reason about which tool to use
* Handle all execution contexts
* Maintain one giant conversation history

This doesn't scale well.

In this article, we're going to refactor it into something much more powerful:

**A multi-agent architecture**.

Instead of one agent with many tools, we'll have:

* 🎯 A **planner agent** that orchestrates work
* 🐍 A **Python specialist** that handles computation
* ⏰ A **time specialist** that retrieves server time
* 💬 A **quote specialist** that fetches inspirational quotes

Each specialist:
* Has **one focused capability**
* Maintains **its own conversation context**
* Can be **called like a tool** by the planner

The planner doesn't know *how* to execute Python.
It just knows *who* to delegate to.

This is the pattern you need when building real agent systems.

Let's build it.


## Why multi-agent architecture matters

Before we dive into code, let's understand the problem.

### The monolithic agent problem

In the previous version, our agent had:

```go
tools := []openai.Tool{
	get_time,
	run_python_code,
	get_random_quote,
	// ... imagine 20 more tools here
}
```

Every request required the model to:

1. Parse the user's intent
2. Choose from 20+ tools
3. Execute the tool
4. Reason about the result
5. Decide if it needs another tool
6. Repeat

This creates cognitive load on the model.

More tools = more tokens = higher latency = more errors.


### The multi-agent solution

Now imagine this instead:

```go
planner_tools := []Tool{
	python_agent,  // delegates to Python specialist
	time_agent,    // delegates to time specialist
	quote_agent,   // delegates to quote specialist
}
```

The planner sees **3 high-level operations**.

When it calls `python_agent`:

* The request is routed to a specialist agent
* That agent has *only* the `run_python_code` tool
* It executes with full context
* It returns the result
* The planner continues

Each specialist is **an expert in one domain**.

The planner is **an expert in orchestration**.

This is:

* More scalable
* More maintainable
* More aligned with how LLMs reason


### The mental model

Think of it like a software organization:

* The **planner** is the project manager
* Each **worker agent** is a domain expert
* Communication happens via structured messages
* The PM doesn't write Python — they delegate to the Python expert

Same principle here.


## What changed from the previous version

* ✅ Agent abstraction (`agent/agent.go`)
* ✅ Hierarchical agent system (planner + workers)
* ✅ Per-agent conversation context
* ✅ Agent-as-tool pattern via `AsTool()`
* ✅ Clean separation of concerns

We removed memory to keep the focus on the architecture.

You can add it back later.


## The Agent abstraction

The core of this version is the `Agent` type.

Let's look at it.

### Structure

```go
type Agent struct {
	Client      *openai.Client
	Model       string
	Name        string
	Description string

	tools        []openai.Tool
	toolHandlers map[string]ToolHandler
}
```

Each agent:

* Has a name and description
* Owns a set of tools
* Maintains tool execution logic
* Can run independently

### Creating an agent

```go
func NewAgent(client *openai.Client, model, name, description string) (*Agent, error)
```

Example:

```go
planner, err := agent.NewAgent(
	client,
	"gpt-4o-mini",
	"planner",
	"You are a planning and orchestration agent...",
)
```

The description becomes the system prompt.

This is critical:

* Each agent has its **own personality**.
* The planner thinks about orchestration.
* The Python worker thinks about computation.

Different roles, different prompts.


### Adding tools

```go
func (a *Agent) AddTool(tool Tool) error
```

A tool is:

```go
type Tool struct {
	Definition openai.Tool
	Handler    ToolHandler
}
```

This bundles:

* The OpenAI function definition (schema)
* The actual Go function that executes it

Example:

```go
pythonWorker.AddTool(agent.Tool{
	Definition: openai.Tool{
		Type: openai.ToolTypeFunction,
		Function: &openai.FunctionDefinition{
			Name:        "run_python_code",
			Description: "Executes Python code...",
			Parameters:  ...,
		},
	},
	Handler: runPythonHandler,
})
```

Each agent can have **multiple tools**, but in this architecture, we keep it focused:

* Python worker → 1 tool
* Time worker → 1 tool
* Quote worker → 1 tool

One agent, one purpose.


### Running an agent

```go
func (a *Agent) Run(ctx context.Context, input string, messages []ChatCompletionMessage) ([]ChatCompletionMessage, string, error)
```

This is the core reasoning loop:

1. Append user input to messages
2. Call the model
3. If tool calls → execute them → loop again
4. If no tool calls → return final answer

This is the **same loop from the [first article](https://simonevellei.com/en/how-to-build-an-ai-agent-from-scratch-in-go/)**.

But now it's encapsulated.

Each agent runs this loop independently.


### Exporting an agent as a tool

Here's where it gets interesting.

```go
func (a *Agent) AsTool(name, description string) (Tool, error)
```

This method:

* Takes an agent
* Exports it as an OpenAI tool
* Returns a handler that delegates to the agent

Example:

```go
pythonTool, err := pythonWorker.AsTool(
	"python_agent",
	"Delegates to the Python specialist agent.",
)
```

Now the **planner can call the Python worker like a function**.

From the planner's perspective:

```json
{
  "type": "function",
  "function": {
    "name": "python_agent",
    "parameters": {
      "input": "calculate the square root of 144"
    }
  }
}
```

Behind the scenes:

1. The planner's tool handler is invoked
2. It forwards the input to `pythonWorker.Run()`
3. The Python worker executes its own loop
4. It returns the result
5. The planner receives it as a tool result

**Agents calling agents.**

That's the architecture.


## Building the system

Now let's walk through the actual implementation.

We'll break this into chunks just like the previous articles.


### Imports and setup

```go
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	agpkg "agent/agent"

	agentopenai "github.com/sashabaranov/go-openai"
)
```

Notice:

* We import our custom `agent` package as `agpkg`
* We alias `go-openai` as `agentopenai` to avoid conflicts

This is a clean multi-package Go project now.


### Creating the planner

```go
func main() {
	ctx := context.Background()

	apiKey := os.Getenv("OPENAI_API_KEY")
	baseURL := os.Getenv("OPENAI_BASE_URL")
	model := os.Getenv("MODEL")

	config := agentopenai.DefaultConfig(apiKey)
	if baseURL != "" {
		config.BaseURL = baseURL
	}
	client := agentopenai.NewClientWithConfig(config)

	plannerName := "planner"
	plannerDescription := "You are a planning and orchestration agent. You can delegate work to specialist agents via tools: python_agent (execute Python), time_agent (get current time), quote_agent (fetch a random quote). Decide which to call, call them, then compose the final answer for the user."

	planner, err := agpkg.NewAgent(client, model, plannerName, plannerDescription)
	if err != nil {
		log.Fatal(err)
	}
```

The planner:

* Has no direct tools
* Knows it can delegate
* Is responsible for composing the final answer


### Creating worker agents

```go
	pythonWorker, err := agpkg.NewAgent(client, model, "python-worker", "You are a specialist agent for executing Python code. Use the run_python_code tool when you need to compute something. Return only the result.")
	if err != nil {
		log.Fatal(err)
	}

	timeWorker, err := agpkg.NewAgent(client, model, "time-worker", "You are a specialist agent for retrieving the current time. Use the get_time tool and return it.")
	if err != nil {
		log.Fatal(err)
	}

	quoteWorker, err := agpkg.NewAgent(client, model, "quote-worker", "You are a specialist agent for fetching a random inspirational quote. Use the get_random_quote tool and return it.")
	if err != nil {
		log.Fatal(err)
	}
```

Each agent:

* Has a focused role
* Has a specialized system prompt
* Will receive focused tools next


### Registering worker tools

Now we give each worker its tool:

```go
func registerWorkerTools(pythonWorker, timeWorker, quoteWorker *agpkg.Agent) error {
	if err := timeWorker.AddTool(agpkg.Tool{
		Definition: agentopenai.Tool{
			Type: agentopenai.ToolTypeFunction,
			Function: &agentopenai.FunctionDefinition{
				Name:        "get_time",
				Description: "Returns the current server time",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
		Handler: func(_ context.Context, _ string) (string, error) {
			return fmt.Sprintf("Current server time: %s", time.Now().UTC().Format(time.RFC3339)), nil
		},
	}); err != nil {
		return err
	}

	if err := pythonWorker.AddTool(agpkg.Tool{
		Definition: agentopenai.Tool{
			Type: agentopenai.ToolTypeFunction,
			Function: &agentopenai.FunctionDefinition{
				Name:        "run_python_code",
				Description: "Use this tool to solve calculations, manipulate data, or perform any other Python-related tasks. The code should use print() to print the final result to stdout.",
				Parameters: map[string]any{
					"type": "object",
					"properties": map[string]any{
						"code": map[string]any{
							"type":        "string",
							"description": "Python code that uses print() to print the final result to stdout.",
						},
					},
					"required": []string{"code"},
				},
			},
		},
		Handler: runPythonHandler,
	}); err != nil {
		return err
	}

	if err := quoteWorker.AddTool(agpkg.Tool{
		Definition: agentopenai.Tool{
			Type: agentopenai.ToolTypeFunction,
			Function: &agentopenai.FunctionDefinition{
				Name:        "get_random_quote",
				Description: "Fetches a random inspirational quote from the web.",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
		Handler: fetchRandomQuoteHandler,
	}); err != nil {
		return err
	}

	return nil
}
```

Each worker gets **exactly one tool**.

Focused competency.


### Registering planner tools

Now the critical part:

```go
func registerPlannerTools(planner, pythonWorker, timeWorker, quoteWorker *agpkg.Agent) error {
	pythonTool, err := pythonWorker.AsTool(
		"python_agent",
		"Delegates to the Python specialist agent.",
	)
	if err != nil {
		return err
	}

	timeTool, err := timeWorker.AsTool(
		"time_agent",
		"Delegates to the time specialist agent.",
	)
	if err != nil {
		return err
	}

	quoteTool, err := quoteWorker.AsTool(
		"quote_agent",
		"Delegates to the quote specialist agent.",
	)
	if err != nil {
		return err
	}

	if err := planner.AddTool(pythonTool); err != nil {
		return err
	}
	if err := planner.AddTool(timeTool); err != nil {
		return err
	}
	if err := planner.AddTool(quoteTool); err != nil {
		return err
	}

	return nil
}
```

Each worker is **exported as a tool**.

The planner's tools are **other agents**.

This is the multi-agent pattern in action.


### The main loop

The user-facing loop is now trivial:

```go
	var messages []agentopenai.ChatCompletionMessage
	reader := bufio.NewReader(os.Stdin)

	fmt.Println("Multi-Agent Go CLI (type 'exit' to quit)")
	for {
		fmt.Print("\n> ")
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		if input == "exit" {
			return
		}

		var output string
		messages, output, err = planner.Run(ctx, input, messages)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Println("\nAssistant:", output)
	}
```

Everything happens inside `planner.Run()`.

We don't manage tools.
We don't manage routing.
We don't manage sub-agent execution.

The agent system handles it all.


## The Agent implementation

Now let's look at the core agent logic in `agent/agent.go`.

### The Run method

This is the main loop:

```go
func (a *Agent) Run(ctx context.Context, input string, messages []openai.ChatCompletionMessage) ([]openai.ChatCompletionMessage, string, error) {
	// Ensure system prompt is set
	if a.Description != "" {
		if len(messages) == 0 {
			messages = append(messages, openai.ChatCompletionMessage{
				Role:    openai.ChatMessageRoleSystem,
				Content: a.Description,
			})
		} else if messages[0].Role == openai.ChatMessageRoleSystem {
			messages[0].Content = a.Description
		} else {
			messages = append([]openai.ChatCompletionMessage{{
				Role:    openai.ChatMessageRoleSystem,
				Content: a.Description,
			}}, messages...)
		}
	}

	messages = append(messages, openai.ChatCompletionMessage{
		Role:    openai.ChatMessageRoleUser,
		Content: input,
	})

	for {
		resp, err := a.Client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
			Model:    a.Model,
			Messages: messages,
			Tools:    a.tools,
		})
		if err != nil {
			return messages, "", err
		}

		msg := resp.Choices[0].Message
		messages = append(messages, msg)

		if len(msg.ToolCalls) == 0 {
			return messages, msg.Content, nil
		}

		for _, toolCall := range msg.ToolCalls {
			result := a.executeToolCall(ctx, toolCall)
			messages = append(messages, openai.ChatCompletionMessage{
				Role:       openai.ChatMessageRoleTool,
				Content:    result,
				ToolCallID: toolCall.ID,
			})
		}
	}
}
```

This is the same loop we built in the [first article](https://simonevellei.com/en/how-to-build-an-ai-agent-from-scratch-in-go/).

But now:

* It's reusable
* It's encapsulated
* It's composable


### Tool execution

```go
func (a *Agent) executeToolCall(ctx context.Context, tc openai.ToolCall) string {
	name := tc.Function.Name
	handler, ok := a.toolHandlers[name]
	if !ok {
		return "unknown tool: " + name
	}

	out, err := handler(ctx, tc.Function.Arguments)
	if err != nil {
		if out == "" {
			return "tool error: " + err.Error()
		}
		return out + "\nerror: " + err.Error()
	}
	return out
}
```

Simple dispatch.

But remember:

When the planner calls `python_agent`, the handler is:

```go
pythonWorker.Run(ctx, args.Input, messages)
```

Tool execution = agent delegation.


### AsTool implementation

Here's how we export an agent as a tool:

```go
func (a *Agent) AsTool(name, description string) (Tool, error) {
	if name == "" {
		return Tool{}, errors.New("tool name is empty")
	}
	if description == "" {
		description = "Delegates work to a sub-agent"
	}

	toolDef := openai.Tool{
		Type: openai.ToolTypeFunction,
		Function: &openai.FunctionDefinition{
			Name:        name,
			Description: description,
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"input": map[string]any{
						"type":        "string",
						"description": "Input message for the agent.",
					},
				},
				"required": []string{"input"},
			},
		},
	}

	var messages []openai.ChatCompletionMessage

	h := func(ctx context.Context, arguments string) (string, error) {
		var args struct {
			Input string `json:"input"`
		}
		if err := json.Unmarshal([]byte(arguments), &args); err != nil {
			return "", fmt.Errorf("invalid arguments: %w", err)
		}
		if args.Input == "" {
			return "", errors.New("invalid arguments: missing 'input' string")
		}

		var out string
		var err error
		messages, out, err = a.Run(ctx, args.Input, messages)
		return out, err
	}

	return Tool{Definition: toolDef, Handler: h}, nil
}
```

Critical detail:

```go
var messages []openai.ChatCompletionMessage
```

This is **captured in the closure**.

Each agent-as-tool maintains **its own conversation history**.

So if the planner calls `python_agent` multiple times:

* The Python worker remembers previous interactions
* It can refine its work
* It can reference past results

**Stateful sub-agents.**

This is powerful.


## Tool handlers

The actual tool implementations are unchanged from the previous article.

### run_python_code

```go
func runPythonHandler(_ context.Context, arguments string) (string, error) {
	var args struct {
		Code string `json:"code"`
	}
	err := json.Unmarshal([]byte(arguments), &args)
	if err != nil {
		return "", fmt.Errorf("invalid arguments: %s", err.Error())
	}
	if args.Code == "" {
		return "", fmt.Errorf("invalid arguments: missing 'code' string")
	}

	cmd := exec.Command("python3", "-c", args.Code)
	output, err := cmd.CombinedOutput()
	return string(output), err
}
```

### get_random_quote

```go
func fetchRandomQuoteHandler(_ context.Context, _ string) (string, error) {
	resp, err := http.Get("https://zenquotes.io/api/random")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var data []struct {
		Q string `json:"q"`
		A string `json:"a"`
	}
	err = json.Unmarshal(body, &data)
	if err != nil || len(data) == 0 {
		return "", fmt.Errorf("invalid response from quote API")
	}
	return fmt.Sprintf("%s — %s", data[0].Q, data[0].A), nil
}
```

Same implementation.

Different execution context.

Now they're **isolated inside specialist agents**.


## Full code

Here's the complete `main.go`:

{{< details summary="Click to expand main.go" >}}
```go
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	agpkg "agent/agent"

	agentopenai "github.com/sashabaranov/go-openai"
)

func main() {
	ctx := context.Background()

	apiKey := os.Getenv("OPENAI_API_KEY")
	baseURL := os.Getenv("OPENAI_BASE_URL")
	model := os.Getenv("MODEL")

	config := agentopenai.DefaultConfig(apiKey)
	if baseURL != "" {
		config.BaseURL = baseURL
	}
	client := agentopenai.NewClientWithConfig(config)

	plannerName := "planner"
	plannerDescription := "You are a planning and orchestration agent. You can delegate work to specialist agents via tools: python_agent (execute Python), time_agent (get current time), quote_agent (fetch a random quote). Decide which to call, call them, then compose the final answer for the user."

	planner, err := agpkg.NewAgent(client, model, plannerName, plannerDescription)
	if err != nil {
		log.Fatal(err)
	}

	pythonWorker, err := agpkg.NewAgent(client, model, "python-worker", "You are a specialist agent for executing Python code. Use the run_python_code tool when you need to compute something. Return only the result.")
	if err != nil {
		log.Fatal(err)
	}

	timeWorker, err := agpkg.NewAgent(client, model, "time-worker", "You are a specialist agent for retrieving the current time. Use the get_time tool and return it.")
	if err != nil {
		log.Fatal(err)
	}

	quoteWorker, err := agpkg.NewAgent(client, model, "quote-worker", "You are a specialist agent for fetching a random inspirational quote. Use the get_random_quote tool and return it.")
	if err != nil {
		log.Fatal(err)
	}

	if err := registerWorkerTools(pythonWorker, timeWorker, quoteWorker); err != nil {
		log.Fatal(err)
	}

	if err := registerPlannerTools(planner, pythonWorker, timeWorker, quoteWorker); err != nil {
		log.Fatal(err)
	}

	var messages []agentopenai.ChatCompletionMessage
	reader := bufio.NewReader(os.Stdin)

	fmt.Println("Multi-Agent Go CLI (type 'exit' to quit)")
	for {
		fmt.Print("\n> ")
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		if input == "exit" {
			return
		}

		var output string
		messages, output, err = planner.Run(ctx, input, messages)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Println("\nAssistant:", output)
	}
}

func registerWorkerTools(pythonWorker, timeWorker, quoteWorker *agpkg.Agent) error {
	if err := timeWorker.AddTool(agpkg.Tool{
		Definition: agentopenai.Tool{
			Type: agentopenai.ToolTypeFunction,
			Function: &agentopenai.FunctionDefinition{
				Name:        "get_time",
				Description: "Returns the current server time",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
		Handler: func(_ context.Context, _ string) (string, error) {
			return fmt.Sprintf("Current server time: %s", time.Now().UTC().Format(time.RFC3339)), nil
		},
	}); err != nil {
		return err
	}

	if err := pythonWorker.AddTool(agpkg.Tool{
		Definition: agentopenai.Tool{
			Type: agentopenai.ToolTypeFunction,
			Function: &agentopenai.FunctionDefinition{
				Name:        "run_python_code",
				Description: "Use this tool to solve calculations, manipulate data, or perform any other Python-related tasks. The code should use print() to print the final result to stdout.",
				Parameters: map[string]any{
					"type": "object",
					"properties": map[string]any{
						"code": map[string]any{
							"type":        "string",
							"description": "Python code that uses print() to print the final result to stdout.",
						},
					},
					"required": []string{"code"},
				},
			},
		},
		Handler: runPythonHandler,
	}); err != nil {
		return err
	}

	if err := quoteWorker.AddTool(agpkg.Tool{
		Definition: agentopenai.Tool{
			Type: agentopenai.ToolTypeFunction,
			Function: &agentopenai.FunctionDefinition{
				Name:        "get_random_quote",
				Description: "Fetches a random inspirational quote from the web.",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
		Handler: fetchRandomQuoteHandler,
	}); err != nil {
		return err
	}

	return nil
}

func registerPlannerTools(planner, pythonWorker, timeWorker, quoteWorker *agpkg.Agent) error {
	pythonTool, err := pythonWorker.AsTool(
		"python_agent",
		"Delegates to the Python specialist agent.",
	)
	if err != nil {
		return err
	}

	timeTool, err := timeWorker.AsTool(
		"time_agent",
		"Delegates to the time specialist agent.",
	)
	if err != nil {
		return err
	}

	quoteTool, err := quoteWorker.AsTool(
		"quote_agent",
		"Delegates to the quote specialist agent.",
	)
	if err != nil {
		return err
	}

	if err := planner.AddTool(pythonTool); err != nil {
		return err
	}
	if err := planner.AddTool(timeTool); err != nil {
		return err
	}
	if err := planner.AddTool(quoteTool); err != nil {
		return err
	}

	return nil
}

func runPythonHandler(_ context.Context, arguments string) (string, error) {
	var args struct {
		Code string `json:"code"`
	}
	err := json.Unmarshal([]byte(arguments), &args)
	if err != nil {
		return "", fmt.Errorf("invalid arguments: %s", err.Error())
	}
	if args.Code == "" {
		return "", fmt.Errorf("invalid arguments: missing 'code' string")
	}

	cmd := exec.Command("python3", "-c", args.Code)
	output, err := cmd.CombinedOutput()
	return string(output), err
}

func fetchRandomQuoteHandler(_ context.Context, _ string) (string, error) {
	resp, err := http.Get("https://zenquotes.io/api/random")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var data []struct {
		Q string `json:"q"`
		A string `json:"a"`
	}
	err = json.Unmarshal(body, &data)
	if err != nil || len(data) == 0 {
		return "", fmt.Errorf("invalid response from quote API")
	}
	return fmt.Sprintf("%s — %s", data[0].Q, data[0].A), nil
}
```
{{< /details >}}

And the complete `agent/agent.go`:

{{< details summary="Click to expand agent/agent.go" >}}
```go
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	openai "github.com/sashabaranov/go-openai"
)

type ToolHandler func(ctx context.Context, arguments string) (string, error)

type Tool struct {
	Definition openai.Tool
	Handler    ToolHandler
}

func (t Tool) Name() string {
	if t.Definition.Function == nil {
		return ""
	}
	return t.Definition.Function.Name
}

type Agent struct {
	Client      *openai.Client
	Model       string
	Name        string
	Description string

	tools        []openai.Tool
	toolHandlers map[string]ToolHandler
}

func NewAgent(client *openai.Client, model, name, description string) (*Agent, error) {
	if client == nil {
		return nil, errors.New("openai client is nil")
	}
	if model == "" {
		model = "gpt-4o-mini"
	}
	if name == "" {
		name = "agent"
	}
	if description == "" {
		return nil, errors.New("agent description is required")
	}

	return &Agent{
		Client:       client,
		Model:        model,
		Name:         name,
		Description:  description,
		tools:        nil,
		toolHandlers: map[string]ToolHandler{},
	}, nil
}

func (a *Agent) Tools() []openai.Tool {
	if len(a.tools) == 0 {
		return nil
	}
	copyTools := make([]openai.Tool, len(a.tools))
	copy(copyTools, a.tools)
	return copyTools
}

func (a *Agent) AddTool(tool Tool) error {
	if tool.Handler == nil {
		return errors.New("tool handler is nil")
	}
	if tool.Definition.Type != openai.ToolTypeFunction {
		return fmt.Errorf("unsupported tool type: %s", tool.Definition.Type)
	}
	if tool.Definition.Function == nil || tool.Definition.Function.Name == "" {
		return errors.New("tool.Function.Name is required")
	}

	name := tool.Definition.Function.Name
	a.toolHandlers[name] = tool.Handler

	for i := range a.tools {
		if a.tools[i].Function != nil && a.tools[i].Function.Name == name {
			a.tools[i] = tool.Definition
			return nil
		}
	}
	a.tools = append(a.tools, tool.Definition)
	return nil
}

func (a *Agent) Run(ctx context.Context, input string, messages []openai.ChatCompletionMessage) ([]openai.ChatCompletionMessage, string, error) {
	if a.Description != "" {
		if len(messages) == 0 {
			messages = append(messages, openai.ChatCompletionMessage{
				Role:    openai.ChatMessageRoleSystem,
				Content: a.Description,
			})
		} else if messages[0].Role == openai.ChatMessageRoleSystem {
			if messages[0].Content != a.Description {
				messages[0].Content = a.Description
			}
		} else {
			messages = append([]openai.ChatCompletionMessage{{
				Role:    openai.ChatMessageRoleSystem,
				Content: a.Description,
			}}, messages...)
		}
	}

	messages = append(messages, openai.ChatCompletionMessage{
		Role:    openai.ChatMessageRoleUser,
		Content: input,
	})

	for {
		resp, err := a.Client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
			Model:    a.Model,
			Messages: messages,
			Tools:    a.tools,
		})
		if err != nil {
			return messages, "", err
		}

		msg := resp.Choices[0].Message
		messages = append(messages, msg)

		if len(msg.ToolCalls) == 0 {
			return messages, msg.Content, nil
		}

		for _, toolCall := range msg.ToolCalls {
			result := a.executeToolCall(ctx, toolCall)
			messages = append(messages, openai.ChatCompletionMessage{
				Role:       openai.ChatMessageRoleTool,
				Content:    result,
				ToolCallID: toolCall.ID,
			})
		}
	}
}

func (a *Agent) executeToolCall(ctx context.Context, tc openai.ToolCall) string {
	name := tc.Function.Name
	handler, ok := a.toolHandlers[name]
	if !ok {
		return "unknown tool: " + name
	}

	out, err := handler(ctx, tc.Function.Arguments)
	if err != nil {
		if out == "" {
			return "tool error: " + err.Error()
		}
		return out + "\nerror: " + err.Error()
	}
	return out
}

func (a *Agent) AsTool(name, description string) (Tool, error) {
	if name == "" {
		return Tool{}, errors.New("tool name is empty")
	}
	if description == "" {
		description = "Delegates work to a sub-agent"
	}

	toolDef := openai.Tool{
		Type: openai.ToolTypeFunction,
		Function: &openai.FunctionDefinition{
			Name:        name,
			Description: description,
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"input": map[string]any{
						"type":        "string",
						"description": "Input message for the agent.",
					},
				},
				"required": []string{"input"},
			},
		},
	}

	var messages []openai.ChatCompletionMessage

	h := func(ctx context.Context, arguments string) (string, error) {
		var args struct {
			Input string `json:"input"`
		}
		if err := json.Unmarshal([]byte(arguments), &args); err != nil {
			return "", fmt.Errorf("invalid arguments: %w", err)
		}
		if args.Input == "" {
			return "", errors.New("invalid arguments: missing 'input' string")
		}

		var out string
		var err error
		messages, out, err = a.Run(ctx, args.Input, messages)
		return out, err
	}

	return Tool{Definition: toolDef, Handler: h}, nil
}
```
{{< /details >}}


## Seeing the multi-agent system in action

Now let's see how this actually works in practice.

When we run the program:

```shell
$ OPENAI_BASE_URL=http://localhost:11434/v1 MODEL=ministral-3:3b go run main.go

Multi-Agent Go CLI (type 'exit' to quit)
>
```

### Simple delegation

```shell
> what time is it?
A: The current server time is 2026-03-01T17:30:45Z.
```

What happened behind the scenes:

1. Planner received the question
2. Planner identified it needs the time agent
3. Planner called `time_agent` tool
4. That delegated to `timeWorker.Run()`
5. Time worker called `get_time` tool
6. Result flowed back: worker → planner → user

Two agents.
One tool call.
Clean separation of concerns.


### Multi-agent orchestration

```shell
> calculate 144 * 89 and tell me the current time

A: The result of 144 × 89 is **12,816**.

The current server time is **2026-03-01T17:32:18Z**.
```

Behind the scenes:

1. Planner decided it needs two agents
2. Called `python_agent` with "calculate 144 * 89"
   - Python worker generated: `print(144 * 89)`
   - Executed and returned `12816`
3. Called `time_agent`
   - Time worker returned current time
4. Planner composed final answer

This is the power of the architecture:

* The planner doesn't know *how* to calculate
* The planner doesn't know *how* to get time
* It only knows *who* to ask

Delegation.


### Complex multi-step reasoning

```shell
> get a random quote, calculate its word count, then tell me if it's prime

A: The quote has **14 words**, and **14 is not a prime number** (it's divisible by 1, 2, 7, and 14).

The quote was: "The only way to do a great work is to love what you do." — Steve Jobs
```

Here the planner:

1. Called `quote_agent` → received quote
2. Called `python_agent` with "count words in: [quote]"
   - Generated: `print(len("The only way...".split()))`
   - Returned `14`
3. Called `python_agent` again with "is 14 prime?"
   - Generated primality check code
   - Returned `False`
4. Composed final narrative response

**Three different agent calls.**
**Two calls to the same agent with different tasks.**

Each worker maintained its own context.

The planner orchestrated everything.


### Why this scales

In the monolithic version, this request would require:

* One agent with 3 tools
* One giant conversation history
* One context window juggling all tool definitions

In the multi-agent version:

* Planner sees 3 high-level operations
* Each worker handles focused execution
* Each worker has isolated context
* Tool complexity is hidden

As you add more capabilities:

* Add a new worker
* Give it specialized tools
* Export it to the planner
* Done

The planner doesn't need to change.

The architecture **scales horizontally**.


## What we've achieved

Let's map out the progress across all three articles:

| Feature                     | [Article 1](https://simonevellei.com/en/how-to-build-an-ai-agent-from-scratch-in-go/) | [Article 2](https://simonevellei.com/en/building-a-stateful-multi-tool-agent-in-go/) | Article 3 |
| --------------------------- | --------- | --------- | --------- |
| Agent loop                  | ✅        | ✅        | ✅        |
| Tool calling                | ✅        | ✅        | ✅        |
| Multiple tools              | ❌        | ✅        | ✅        |
| Persistent memory           | ❌        | ✅        | ❌        |
| Agent abstraction           | ❌        | ❌        | ✅        |
| Multi-agent architecture    | ❌        | ❌        | ✅        |
| Hierarchical delegation     | ❌        | ❌        | ✅        |
| Isolated agent context      | ❌        | ❌        | ✅        |
| Horizontal scalability      | ❌        | ❌        | ✅        |

We removed persistent memory to focus on the architecture.

You can add it back by:

* Persisting each agent's message history
* Loading it on startup
* Saving after each interaction

The pattern is orthogonal.


## When to use multi-agent architecture

Not every system needs this.

### Use multi-agent when:

* You have diverse capabilities (computation, web, database, etc.)
* Tool count is growing beyond 5-10
* Different tools require different context
* You want to isolate failure domains
* You need horizontal scaling

### Stick with monolithic when:

* You have 1-3 simple tools
* All tools share the same context
* Speed is critical (each delegation = extra API call)
* You're prototyping




## Conclusion

We've come a long way across three articles.

[Article 1](https://simonevellei.com/en/how-to-build-an-ai-agent-from-scratch-in-go/): The foundation — understanding the agent loop.

[Article 2](https://simonevellei.com/en/building-a-stateful-multi-tool-agent-in-go/): Practical capability — multiple tools, persistent memory.

Article 3: Scalable architecture — multi-agent composition.

You now have:

* A reusable agent abstraction
* A clean separation of concerns
* A scalable pattern for adding capabilities
* Full control over the execution flow

No magic.
No black boxes.
Just composition.

If you're building AI-powered applications in Go, this pattern will serve you well.

And if you want higher-level abstractions, check out [LinGoose](https://github.com/henomis/lingoose) — it provides production-ready implementations of these patterns and many more.

But now you understand what's happening under the hood.

And that's what matters.

