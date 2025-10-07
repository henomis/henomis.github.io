# Anthropic's Claude Integration with Go and Lingoose


In the ever-changing world of artificial intelligence, a new AI assistant called [Claude](https://claude.ai/) has arrived on the scene, and it's turning heads. Created by a company called [Anthropic](https://anthropic.com/), Claude is incredibly smart and can understand and communicate with humans in very natural, human-like ways.

What makes Claude so special is the way it has been trained. The folks at Anthropic fed Claude a massive amount of data, which allows it to truly grasp how we humans speak and write. So whether you're chatting with Claude casually or asking it to tackle some complex task, it can handle it all with impressive skill.

But Claude isn't just smart, it also has a strong moral code baked into it. Anthropic made sure Claude's responses are good and ethical, and that it is transparent about being an AI. This helps ensure Claude won't be misused in harmful ways.

## Using Claude with Go and Lingoose
Starting from the v0.1.2 version of my project [Lingoose](https://lingoose.io), a Go programming framework for building AI apps, it includes support for Claude. This means developers can tap into Claude's incredible language abilities to create intelligent systems that can understand natural language, analyze data, and much more. With Claude's help, the creative minds building on Lingoose can now push their AI projects even further!

Lingoose provides a simple and easy-to-use API for developers to interact with LLMS (Language Learning Models) like Claude. This makes it easy to integrate Claude into your projects and start building amazing AI applications. Let's take a look at how you can get started with Claude and Lingoose:

```go
package main

import (
	"context"
	"fmt"

	"github.com/henomis/lingoose/llm/antropic"
	"github.com/henomis/lingoose/thread"
)

func main() {
	antropicllm := antropic.New().WithModel("claude-3-haiku-20240307")

	t := thread.New().AddMessage(
		thread.NewUserMessage().AddContent(
			thread.NewTextContent("How are you?"),
		),
	)

	err := antropicllm.Generate(context.Background(), t)
	if err != nil {
		panic(err)
	}

	fmt.Println(t)
}
```

This example shows how simple it is to use Claude with Lingoose. By creating a new Claude instance and passing in the model you want to use, you can start generating responses to user messages in no time. In this case we are generating an assistant answer using chat completion. 

> In order to run this code, the `ANTHROPIC_API_KEY` environment variable must be set with your API key.


### Streaming answers

Lingoose also supports streaming answers from Claude. This is useful when you want to handle partial responses. Here's an example of how you can stream answers from Claude using Lingoose:

```go
...
	antropicllm := antropic.New().WithModel("claude-3-opus-20240229").WithStream(
		func(response string) {
			if response != antropic.EOS {
				fmt.Print(response)
			} else {
				fmt.Println()
			}
		},
	)
...
```

In this example, we're using the `WithStream` method to pass a callback function that will be called each time Claude generates a response. This allows you to handle the responses as they come in, which can be useful for real-time applications or when you want to display partial responses to the user.

## Let's give it a try!

With Claude and Lingoose, the possibilities are endless. Whether you're building a chatbot, a language model, or something entirely new, Claude's language abilities can help you create intelligent systems that can understand and communicate with humans in natural ways. Moreover Lingoose provides many other features that can help you build your AI applications faster and more efficiently such as embeddings, assistants, RAG, and more.
So why not give it a try and see what you can create with [Claude](https://claude.ai/) and [Lingoose](https://lingoose.io)?


