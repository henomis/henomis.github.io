# Building a stateful multi-tool agent in Go


In the [previous article](https://simonevellei.com/en/how-to-build-an-ai-agent-from-scratch-in-go/), we built a minimal agent:

* One tool
* In-memory conversation
* A clean reasoning loop

Now we’re going to level it up.

This version introduces two major upgrades:

1. **Persistent memory across sessions**
2. **Multiple tools with different capabilities**

We are still using [go-openai](https://github.com/sashabaranov/go-openai) as our client library, compatible with OpenAI and ollama.

But now the agent feels much closer to something you’d actually deploy.


## What’s new in this version?

Compared to the previous article, this `main.go` adds:

* 🧠 Session-based persistent memory (`memory.json`)
* 🧮 A Python execution tool
* 🌍 A live HTTP tool (random quote API)
* 🧰 A multi-tool orchestration layer

Let’s break it down in structured chunks — and as before, if you copy all chunks in order, you’ll get the full working file.

## Persistent memory: Sessions that survive restarts

In the first article, memory lived only inside the `messages` slice.

Once the program stopped, everything was gone.

Now we introduce:

```go
memoryFile := "memory.json"
```

And this logic:

```go
var messages []openai.ChatCompletionMessage
sessionName := os.Getenv("SESSION_NAME")

if sessionName != "" {
	fmt.Printf("Loading conversation for session '%s'...\n", sessionName)
	messages, _ = loadConversation(sessionName, memoryFile)
} else {
	fmt.Println("No session name provided. Starting new conversation with empty history.")
	sessionName = "default"
	messages = []openai.ChatCompletionMessage{
		{
			Role: openai.ChatMessageRoleSystem,
			Content: `You are an assistant that can only help the user by using the available tools provided to you.`,
		},
	}
}
```

### What’s happening?

* If `SESSION_NAME` is set → load past conversation.
* If not → start fresh.
* Conversations are stored in a shared JSON file.

This means:

```bash
export SESSION_NAME=myproject
```

Now your agent remembers everything from previous runs.

This is the first step toward real conversational state.

## Saving and loading conversations

Here’s how persistence works.

### Saving

```go
func saveConversation(messages []openai.ChatCompletionMessage, sessionName, memoryFile string) error {
	sessions := map[string][]openai.ChatCompletionMessage{}

	if data, err := os.ReadFile(memoryFile); err == nil {
		_ = json.Unmarshal(data, &sessions)
	}

	sessions[sessionName] = messages

	data, err := json.MarshalIndent(sessions, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(memoryFile, data, 0644)
}
```

We:

* Load the file (if it exists)
* Update the current session
* Write everything back

Simple key-value persistence.

### Loading

```go
func loadConversation(sessionName, memoryFile string) ([]openai.ChatCompletionMessage, error) {
	sessions := map[string][]openai.ChatCompletionMessage{}

	data, err := os.ReadFile(memoryFile)
	if err != nil {
		return nil, err
	}

	err = json.Unmarshal(data, &sessions)
	if err != nil {
		return nil, err
	}

	messages, ok := sessions[sessionName]
	if !ok {
		return nil, fmt.Errorf("session '%s' not found", sessionName)
	}

	return messages, nil
}
```

Now your agent has durable memory.

Not vector-based.
Not semantic.
Just raw conversation history.

And that’s perfectly fine for many use cases.


## Multiple tools, expanding capability

In the first article, we had:

```go
get_time()
```

Now we have three tools:

```go
func buildTools() []openai.Tool {
	return []openai.Tool{
		// 1. get_time
		// 2. run_python_code
		// 3. get_random_quote
	}
}
```

Let’s break them down.


### get_time

Same as before:

* No parameters
* Returns UTC time


### run_python_code

This one is powerful.

```go
{
	Type: openai.ToolTypeFunction,
	Function: &openai.FunctionDefinition{
		Name:        "run_python_code",
		Description: "Use this tool to solve calculations, manipulate data, or perform any other Python-related tasks.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"code": map[string]any{
					"type": "string",
				},
			},
			"required": []string{"code"},
		},
	},
}
```

This allows the model to:

* Execute math
* Manipulate strings
* Perform structured data operations
* Use Python’s ecosystem

Execution happens here:

```go
cmd := exec.Command("python3", "-c", args.Code)
output, err := cmd.CombinedOutput()
```

⚠️ Important note for readers:
This runs arbitrary code. In production, you **must sandbox this**.

But for learning? It’s perfect.


### get_random_quote

This tool performs a real HTTP request:

```go
resp, err := http.Get("https://zenquotes.io/api/random")
```

The model now has:

* Live internet capability (limited)
* External data fetching
* JSON parsing via Go

We’ve moved from toy agent to something real.


## Tool execution router

All tools are handled centrally:

```go
func handleToolCall(tc openai.ToolCall) string {
	switch tc.Function.Name {

	case "get_time":
		...

	case "run_python_code":
		...

	case "get_random_quote":
		...

	default:
		return "unknown tool"
	}
}
```

This pattern scales cleanly:

* Add a tool definition
* Add a case here
* Done

No magic.
Just routing.

## The agent loop (still the same core idea)

The heart of the agent hasn’t changed:

```go
for {
	resp, err := client.CreateChatCompletion(...)
	msg := resp.Choices[0].Message
	messages = append(messages, msg)

	if len(msg.ToolCalls) > 0 {
		// execute tools
		continue
	}

	fmt.Println(msg.Content)
	break
}
```

What changed?

* Now multiple tools may be called.
* The agent may chain tool calls.
* Memory persists between runs.

The architecture remains:

Model
→ Decide
→ Execute tool
→ Append result
→ Repeat

Exactly what we defined in the first article.

## Full code
Here’s the complete `main.go` with all the pieces together.

{{< details summary="Click to expand" >}}
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

	openai "github.com/sashabaranov/go-openai"
)

func main() {
	ctx := context.Background()
	memoryFile := "memory.json"

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

	var messages []openai.ChatCompletionMessage
	sessionName := os.Getenv("SESSION_NAME")
	if sessionName != "" {
		fmt.Printf("Loading conversation for session '%s'...\n", sessionName)
		messages, _ = loadConversation(sessionName, memoryFile)
	} else {
		fmt.Println("No session name provided. Starting new conversation with empty history.")
		sessionName = "default"
		messages = []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleSystem,
				Content: `You are an assistant that can only help the user by using the available tools provided to you.`,
			},
		}
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

		saveConversation(messages, sessionName, memoryFile)
	}
}

// saveConversation saves the conversation history for a session name in a shared memory file (JSON map)
func saveConversation(messages []openai.ChatCompletionMessage, sessionName, memoryFile string) error {
	sessions := map[string][]openai.ChatCompletionMessage{}
	// Load existing sessions if file exists
	if data, err := os.ReadFile(memoryFile); err == nil {
		_ = json.Unmarshal(data, &sessions)
	}

	sessions[sessionName] = messages

	data, err := json.MarshalIndent(sessions, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(memoryFile, data, 0644)
}

// loadConversation loads the conversation history for a session name from the shared memory file (JSON map)
func loadConversation(sessionName, memoryFile string) ([]openai.ChatCompletionMessage, error) {
	sessions := map[string][]openai.ChatCompletionMessage{}
	data, err := os.ReadFile(memoryFile)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(data, &sessions)
	if err != nil {
		return nil, err
	}
	messages, ok := sessions[sessionName]
	if !ok {
		return nil, fmt.Errorf("session '%s' not found", sessionName)
	}
	return messages, nil
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
		{
			Type: openai.ToolTypeFunction,
			Function: &openai.FunctionDefinition{
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
		{
			Type: openai.ToolTypeFunction,
			Function: &openai.FunctionDefinition{
				Name:        "get_random_quote",
				Description: "Fetches a random inspirational quote from the web.",
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
		fmt.Println("Calling get_time...")
		return fmt.Sprintf("Current server time: %s", time.Now().UTC().Format(time.RFC3339))

	case "run_python_code":
		fmt.Println("Calling run_python_code...")
		out, err := runPython(tc.Function.Arguments)
		if err != nil {
			return "Python error: " + err.Error() + "\nOutput: " + out
		}
		return out

	case "get_random_quote":
		fmt.Println("Calling get_random_quote...")
		quote, err := fetchRandomQuote()
		if err != nil {
			return "Failed to fetch quote: " + err.Error()
		}
		return quote

	default:
		return "unknown tool"
	}
}

// fetchRandomQuote fetches a random quote from zenquotes.io
func fetchRandomQuote() (string, error) {
	resp, err := http.Get("https://zenquotes.io/api/random")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	// Response is a JSON array with one object: [{"q":"...","a":"..."}]
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

// runPython executes the provided Python code and returns the output or error.
func runPython(arguments string) (string, error) {
	// Arguments are a JSON string
	var args struct {
		Code string `json:"code"`
	}

	err := json.Unmarshal([]byte(arguments), &args)
	if err != nil {
		return "", fmt.Errorf("Invalid arguments: %s", err.Error())
	}

	if args.Code == "" {
		return "", fmt.Errorf("Invalid arguments: missing 'code' string.")
	}

	cmd := exec.Command("python3", "-c", args.Code)
	output, err := cmd.CombinedOutput()

	return string(output), err
}
```
{{< /details >}}

## Seeing the agent in action

Now that we have the agent running, let’s take a look at an actual execution round. This helps connect the theory and code from the previous chapters to a tangible experience.

When we start the program, we see a simple CLI prompt using ollama and the `ministral-3:3b` model with tools enabled:

```shell
$ OPENAI_BASE_URL=http://localhost:11434/v1 MODEL=ministral-3:3b SESSION=session1 go run main.go 
```

The agent remembers everything inside memory.json, including tool calls and intermediate results.

Below is the reconstructed shell interaction derived directly from the stored message array.

```shell
Simple Go Agent (type 'exit' to quit)

> get a random quote and join it with the current server time.
Calling get_random_quote...
Calling get_time...

Assistant:
Here is your random quote combined with the current server time:

---
"If you want something, then you lose everything. If you don't want anything, then you already have everything." — Seungsahn
Time: February 28, 2026 at 14:56:52 (UTC)
---
```

### What just happened?

1. The model decided it needed two tools.
2. It emitted two tool calls in the same response:
	- `get_random_quote`
	- `get_time`
3. The Go runtime executed both.
4. Their results were appended as tool messages.
5. The model received both outputs and composed the final response.

This is already more advanced than the single-tool example from the previous article.

The agent orchestrated multiple capabilities in one reasoning cycle.


### Now it gets interesting

```shell
> now convert it to base64
Calling run_python_code...

Assistant:
The quote and time have been converted to base64 format:

IklmIHlvdSB3YW50IHNvbWV0aGluZywgdGhlbiB5b3UgbG9zZSBldmVyeXRoaW5nLiBJZiB5b3UgZG9uJ3Qgd2FudCBhbnl0aGluZywgdGhlbiB5b3UgYWxyZWFkeSBoYXZlIGV2ZXJ5dGhpbmcuIiDigJQgU2V1bmdzYWhuClRpbWU6IEZlYnJ1YXJ5IDI4LCAyMDI2IGF0IDE0OjU2OjUyIChVVEMp
```

Here the agent:

- Reused conversation memory.
- Extracted the previous output.
- Generated Python code dynamically.
- Called run_python_code.
- Returned the encoded string.

No hardcoded logic.
The model wrote the Python snippet itself.

### One more step

```shell
> awesome! Can you give me the md5 of that?
Calling run_python_code...

Assistant:
The MD5 hash of the base64 string is:

966fc7d1baa87cd8caedc8884968800b
```

What’s important here:

- The model understood that hashing is computational.
- It chose the Python tool again.
- It generated new code using `hashlib`.
- It returned the final result.

## What we’ve achieved

With just this file, we now have:

- ✅ Multi-tool orchestration
- ✅ Persistent session memory
- ✅ Python execution capability
- ✅ Live HTTP integration
- ✅ Cloud/local model compatibility

This is no longer just a demo.

It’s the skeleton of a production-capable AI backend.


{{< admonition type=note title="What's next?" open=true >}}
In the next article, we’ll make it more powerful by adding a multi-agent approach.
{{< /admonition >}}

