# The evaluator-optimizer pattern in Go: iterate until good enough


Ask an LLM to write something once and you get a first draft. Ask it to revise based on specific feedback and the second draft is measurably better. This isn't surprising. It's how human writing works too. What's interesting is that you can automate both sides: one agent writes, another evaluates, and a Go loop connects them.

This is the evaluator-optimizer pattern, described in Anthropic's [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) guide. A generator produces output. An evaluator scores it and gives feedback. If the score is below a threshold, the generator revises. The loop continues until the output is good enough or you run out of attempts.

In this post I'll walk through building an evaluator-optimizer in Go using [Phero](https://github.com/henomis/phero). Two agents, a structured feedback loop, and ~200 lines of code. No tools, no shared memory, no complex orchestration.

## What we're building

A CLI that takes a writing topic and iteratively improves a draft until an evaluator agent is satisfied:

1. A Generator agent writes an explanation on the given topic
2. An Evaluator agent scores the draft (0-10) and provides actionable feedback
3. If the score is below the threshold, the generator revises using the feedback
4. The loop repeats until the threshold is met or the maximum attempts are exhausted

Here's what a run looks like:

```
multi-agent architecture example: evaluator-optimizer
- llm: model=gpt-4o
- topic: Explain how large language models work to a general audience.
- threshold: 8 / 10

--- iteration 1 / 4 ---
draft (842 chars):
Large language models are computer programs that have learned to
understand and generate human language by studying enormous amounts
of text...

score: 6 / 10
feedback: The explanation is decent but could be more engaging. The
opening sentence is too technical. Use an analogy to make the concept
more relatable. The second paragraph jumps to training without
explaining why it matters...

--- iteration 2 / 4 ---
draft (891 chars):
Imagine a student who has read every book in the library, not to
memorize facts, but to learn how language works...

score: 8 / 10
feedback: Much improved. The analogy is effective and the flow is
natural. Minor suggestion: briefly mention that these models can
sometimes produce incorrect information.

threshold reached on iteration 2.

=== final output ===
Imagine a student who has read every book in the library...
```

The first draft scores a 6. The evaluator gives concrete feedback. The second draft incorporates it and scores an 8. The loop stops. Total cost: 4 LLM calls.

## Why iterate instead of prompting harder?

The natural objection: why not just write a better prompt and get it right the first time? Sometimes you can. But there are structural reasons to prefer a feedback loop.

**Separation of concerns.** Writing and editing are different skills. A prompt that says "write clearly for a general audience" produces different output than one that says "score this text on clarity, accuracy, and engagement." When you ask one model to do both simultaneously, it hedges. It writes conservatively to avoid criticism rather than writing boldly and then fixing problems.

**Specificity of feedback.** The evaluator doesn't just say "try again." It returns a score and concrete suggestions: "use an analogy," "explain why training matters," "mention limitations." This targeted feedback gives the generator something specific to work with on the next pass. A single-shot prompt can't do this because it doesn't know what's wrong yet.

**Controllable quality.** The threshold gives you a knob. Set it to 6 for fast, acceptable output. Set it to 9 for polished output that costs more calls. Set `max-attempts` to 1 to disable iteration entirely. The same two agents serve different quality requirements without any prompt changes.

**Observability.** Each iteration produces a visible artifact: a draft, a score, and feedback. When the final output isn't good enough, you can see exactly where the loop stalled. Was the generator ignoring feedback? Was the evaluator scoring too harshly? Was the feedback too vague? With a single-shot approach, you just get a bad result with no decomposition.

## The architecture

```
topic ──► Generator ──► draft
                          │
                          ▼
                      Evaluator ──► { score, feedback }
                          │
             score < threshold?
             yes ──► revise prompt ──► Generator  (next iteration)
             no  ──► done
```

This is a control loop, not a pipeline. The Go code decides when to stop. The agents don't know about each other, don't share state, and don't make that decision. The generator doesn't know it's being evaluated. The evaluator doesn't know its feedback will be fed back. All coordination lives in ~30 lines of Go.

## Setting up the LLM

Both agents share the same LLM client. The evaluator-optimizer pattern works with any provider that implements `llm.LLM`:

```go
import "github.com/henomis/phero/llm/openai"

client := openai.New(apiKey, openai.WithModel("gpt-4o"))
```

Or with a local model via Ollama:

```go
client := openai.New("",
    openai.WithModel("llama3"),
    openai.WithBaseURL(openai.OllamaBaseURL),
)
```

Using the same client for both agents keeps things simple. In production you might use a cheaper model for the generator and a stronger one for the evaluator, since the evaluation step benefits more from reasoning quality. Or the reverse, a strong generator and a fast evaluator, depending on where your bottleneck is.

## Building the generator

The generator is a standard `agent.Agent` with a system prompt focused on writing:

```go
generator, _ := agent.New(llmClient, "Generator Agent", strings.TrimSpace(`
You are a skilled technical writer.

Your task: write a clear, accurate, and engaging explanation on the given topic.

Guidelines:
- Target a general (non-expert) audience.
- Use plain language; avoid jargon unless you explain it.
- Aim for 150-250 words.
- Structure: 1-2 short paragraphs. No bullet lists.
- Do not include a title or meta-commentary; output the explanation text only.`))
```

A few things to note about this prompt. The word count constraint (150-250 words) gives the evaluator something concrete to score against. The "no meta-commentary" rule prevents the generator from saying things like "Here's my improved explanation:" which would leak into the final output. And "no bullet lists" forces prose, which is harder to write well but more useful for the use case.

## Building the evaluator

The evaluator is also an `agent.Agent`, but its job is fundamentally different. Instead of producing content, it judges content and returns structured data:

```go
evaluator, _ := agent.New(llmClient, "Evaluator Agent", strings.TrimSpace(`
You are a strict writing evaluator.

You will receive a text on a given topic. Evaluate it and return ONLY valid JSON
- no markdown, no extra text.

Evaluation criteria:
- Clarity (is it easy to understand?)
- Accuracy (is the content correct?)
- Engagement (is it interesting to read?)
- Appropriate length (150-250 words)

Output schema:
{
  "score": <integer 0-10>,
  "feedback": "<concrete, actionable suggestions for improvement>"
}

Score 0-4: poor, 5-7: acceptable, 8-10: good.
If score >= 8 feedback may be brief praise plus minor tips.`))
```

The evaluator prompt does three important things. First, it asks for JSON only, no markdown, no extra text. This makes parsing reliable. Second, it lists explicit criteria. Without them, the evaluator would invent its own, which vary across calls and make scores inconsistent. Third, the scoring rubric (0-4 poor, 5-7 acceptable, 8-10 good) anchors the scale so scores are comparable across iterations.

## Parsing structured output

The evaluator returns JSON, but LLMs sometimes wrap it in markdown code fences or add preamble text. The parsing code handles this by extracting the first `{...}` block:

```go
type EvalResult struct {
    Score    int    `json:"score"`
    Feedback string `json:"feedback"`
}

func parseEvalResult(raw string) (EvalResult, error) {
    cleaned := extractJSONObject(raw)
    var result EvalResult
    if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
        return EvalResult{}, err
    }
    return result, nil
}

func extractJSONObject(s string) string {
    start := strings.Index(s, "{")
    end := strings.LastIndex(s, "}")
    if start == -1 || end == -1 || end < start {
        return s
    }
    return s[start : end+1]
}
```

This is deliberately simple. It doesn't validate the JSON schema or handle nested objects. For a two-field struct, it doesn't need to. The `json.Unmarshal` call catches type mismatches, and if the LLM returns something completely unparseable, the error propagates up.

## The control loop

The orchestration is plain Go. No framework abstractions, no state machines. A `for` loop with an exit condition:

```go
prompt := topic
var lastDraft string

for attempt := 1; attempt <= maxAttempts; attempt++ {
    // Step 1: generate a draft.
    genOut, _ := generator.Run(ctx, llm.Text(prompt))
    lastDraft = strings.TrimSpace(genOut.TextContent())

    // Step 2: evaluate the draft.
    evalPrompt := fmt.Sprintf(
        "Evaluate the following text on the topic %q.\n\nText:\n%s",
        topic, lastDraft,
    )
    evalOut, _ := evaluator.Run(ctx, llm.Text(evalPrompt))
    result, _ := parseEvalResult(evalOut.TextContent())

    if result.Score >= threshold {
        fmt.Printf("threshold reached on iteration %d.\n", attempt)
        break
    }

    // Build a revision prompt for the next attempt.
    prompt = fmt.Sprintf(
        "Improve your text on the topic %q based on the evaluator's feedback.\n\n"+
            "Feedback: %s\n\nPrevious draft:\n%s",
        topic, result.Feedback, lastDraft,
    )
}

fmt.Println(lastDraft)
```

Three things make this loop work well.

**The revision prompt includes both the feedback and the previous draft.** The generator doesn't have memory. If you only send the feedback, it starts from scratch and may lose good parts of the previous draft. Including the draft lets it make targeted improvements.

**The original topic stays in every revision prompt.** Without it, the generator can drift off-topic as it optimizes for the evaluator's feedback. Repeating the topic anchors the revision.

**The threshold check happens before building the next prompt.** This means the loop does exactly `2 * iterations` LLM calls, plus zero if the first draft passes. No wasted calls.

## Go-level control, not agent-level

This is the key design decision: the loop lives in Go, not inside an agent's tool calls.

You could build this differently. You could give the generator a "self-evaluate" tool and let it decide when to stop. Or you could put both agents inside a supervisor that manages the iteration. But explicit Go control has advantages.

**Predictable cost.** You know the maximum number of LLM calls before the run starts: `2 * maxAttempts`. No agent can decide to do extra work.

**Easy debugging.** Every draft, score, and feedback is visible in the loop output. You can add logging, metrics, or tracing without modifying any agent.

**Testable.** You can unit test the loop logic with mock agents. You can test the evaluator prompt separately by feeding it known-good and known-bad text and checking the scores.

## Cost and latency

Each iteration makes 2 LLM calls (generate + evaluate), and the calls are sequential because the evaluator needs the draft. Total calls: `2 * iterations`. With GPT-4o and a typical topic, the first draft usually scores 5-7 and the second scores 8+, so most runs complete in 2 iterations (4 calls).

Unlike the debate committee pattern where committee calls can be parallelized, the evaluator-optimizer is inherently sequential. Each iteration depends on the previous one's feedback. The latency floor is `iterations * (generator_latency + evaluator_latency)`.

If latency matters, consider using a faster model for the evaluator. The evaluator's task (scoring and giving feedback) is simpler than the generator's task (producing good prose), so a smaller model often works fine.

## Variations

The evaluator-optimizer pattern adapts to many domains beyond writing.

**Code generation.** The generator writes code. The evaluator checks correctness, style, and edge cases. The revision prompt includes compiler errors or test failures alongside the evaluator's feedback. This is particularly effective because code has objective quality signals.

**Translation.** The generator translates text. The evaluator checks fluency, accuracy, and cultural appropriateness. Each iteration focuses on specific issues rather than re-translating from scratch.

**Multi-evaluator.** Instead of one evaluator, use several: one for accuracy, one for style, one for brevity. Aggregate their scores and feedback into a single revision prompt. This is a hybrid of the evaluator-optimizer and debate committee patterns.

**Adaptive threshold.** Start with a high threshold and lower it after each attempt. This prioritizes quality on early iterations but accepts diminishing returns rather than burning through all attempts.

**Tool-equipped generator.** Give the generator tools (web search, code execution, file reading) so it can ground its output in real data. The evaluator stays tool-free and judges the result. This creates a natural separation between research and quality control.

## What to try next

- **Add tracing** with `trace/text` to see the full message flow and token usage per iteration
- **Try different models** for generator vs. evaluator to optimize cost/quality trade-offs
- **Add domain-specific criteria** to the evaluator prompt for your use case
- **Combine with other patterns**: use evaluator-optimizer as a single step in a larger pipeline, e.g., an orchestrator that fans out topics, evaluator-optimizes each one, then synthesizes
- **Implement early stopping** based on score delta: if the score doesn't improve between iterations, stop early

## Wrapping up

The evaluator-optimizer is one of the most practical multi-agent patterns. It mirrors how humans work: write, get feedback, revise. The LLM does both sides, and Go manages the loop.

The key insight is that generation and evaluation are different tasks that benefit from different prompts. A generator that's told to write boldly produces better raw material than one that's told to be careful. An evaluator that's told to be strict catches problems that a self-critical generator would avoid by not writing them in the first place. Separating the two roles produces better output than either role alone.

Building it in Go with Phero takes ~200 lines. The control loop is explicit, the agents are stateless, and the pattern is straightforward to extend.

The full source is at [`examples/evaluator-optimizer/`](https://github.com/henomis/phero/tree/main/examples/evaluator-optimizer).

*[Phero](https://github.com/henomis/phero) is an open-source Go framework for building multi-agent AI systems. Star the repo if you find it useful.*

