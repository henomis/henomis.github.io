---
date: '2026-10-20T08:00:00+02:00'
title: 'Cicoria: the agent works, you watch the pan'
tags: ["go", "ai", "coding-agents", "open-source", "cicoria"]
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
disableHLJS: true
disableShare: false
hideSummary: false
searchHidden: true
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
featuredImage: "/images/cicoria001.jpg"
images: ["/images/cicoria001.jpg"]
code:
  maxShownLines: -1
cover:
    image: "/images/cicoria001.jpg"
    alt: "cicoria: a robot made of chicory leaves and flowers at a keyboard, surrounded by terminal windows"
    caption: ""
    relative: false
    hidden: false
---

Some projects get their names in meetings. This one got its name from a pan of chicory.

It is called **cicoria**, Italian for chicory, and version 0.0.9 is out today. It lets you work with several coding agents at once, in your terminal, and always know which one needs you.

## An idea at 5:15

The idea turned up uninvited at 5:15 on Sunday morning, 11 October. Over the rest of the morning it became a plan an agent could follow.

So I handed the plan to an agent and went to the kitchen to cook chicory.

That is where the name came from. A pan you forget about lets you know. An agent that stops to ask you something just sits there, quiet, waiting.

The agent works and you watch the pan. Only one of the two tells you when it needs you.

cicoria exists to make that two out of two.

## The scarce resource is attention

On my [dark factory](https://simonevellei.com/darkfactory/) page I describe how I build software now: agents write the code, I own the spec and the gates. cicoria is the workbench that way of working runs from.

Once you delegate seriously, the bottleneck moves to you. In my own words from that page: "Delegating hard means several agents working at once, and the scarce resource becomes my attention: which one is waiting for me, and what did the others change."

Terminal tabs don't answer that. A tab looks the same whether the agent behind it is busy, finished, or stuck on a permission prompt it raised a while ago. You find out by checking, one tab at a time.

The key idea of cicoria is simple: it does not replace your agents or wrap them in something new. Claude Code, Copilot CLI and Codex CLI run untouched, each with its own interface in a real terminal pane. cicoria is the space around them, and it looks after your attention: it tells you who needs you and what changed.

It is also not an orchestrator, and that is deliberate. It does not run workflows between agents or keep them going without you, and agents never contact each other on their own. Every message an agent gets is one you wrote or queued. cicoria is an interface for you.

## Built from friction

cicoria was built the way it is meant to be used: agents doing the implementation, me owning the spec and the review, from the idea on that Sunday morning to v0.0.9 nine days later. And because I was running agents to build a tool for running agents, every rough edge showed up immediately.

The commit history reads less like a changelog and more like a diary of those edges.

The very first thing built after the initial commit was a message queue per session. The friction was obvious: the next thing to tell an agent often arrives while it is still in the middle of a turn. Now it waits in line, and cicoria sends it when the turn ends.

By mid-afternoon came the review. Agents commit their own work, which means a plain `git diff` is often empty right when you want to see what happened. So cicoria counts the changes from the commit the session started on. Pointing at exact lines while reviewing was the next itch, so notes on lines arrived, sent back to the agent as one message.

Over the next days came Copilot CLI and Codex CLI, WSL2, the git branch in the title, and a git worktree of its own for a session that would share a directory with another. Then the changes of a busy session started to blur together, so a commits panel now lists what the session committed and lets you look at one commit at a time. I kept missing a waiting agent while I was in another window, so the terminal's title now names the sessions waiting for you.

The last one came straight from the kitchen. Watching the pan was fine, but I still had to walk back to the desk to answer. So v0.0.9 brings the web cockpit: your phone sees the sessions you share, and you answer from there.

Each feature is a small answer to a moment where the tool got in the way.

## What's on the workbench

Before the list, a minute of a real session. Claude Code writes a small Go HTTP server while a README waits in its queue, a second session in a split pane counts the lines of `main.go`, and a note on the diff asks the first one for a new endpoint.

<video controls muted playsinline preload="metadata" poster="https://henomis.github.io/cicoria/demo.jpg" style="width:100%;height:auto;">
  <source src="https://henomis.github.io/cicoria/demo.mp4" type="video/mp4">
  <a href="https://henomis.github.io/cicoria/demo.mp4">Watch the cicoria demo</a>
</video>

Here is what v0.0.9 ships, in one line each. The [documentation](https://henomis.github.io/cicoria/) has the details.

- **Know who needs you without checking.** Every session shows whether it is working, waiting for you, done while you looked away, idle or exited, and for how long.
- **Jump straight there.** One key takes you to the next session that is waiting. A desktop notification tells you when one starts, and the window title names the ones waiting, so even a tab in the background tells you.
- **Your agent, untouched.** Claude Code, Copilot CLI and Codex CLI with full hook integration, given to the agents cicoria launches without touching your settings. Any other CLI agent works too, with its status guessed from terminal activity.
- **Review what it did, commits included.** A changes panel and full screen diffs, counted from the commit the session started on.
- **Walk through its commits.** A commits panel lists what the session committed, and narrows the changes to one commit at a time.
- **Review it like a pull request.** Notes on lines go back to the agent as one message quoting files and lines.
- **Line up what to say next.** A queue per session, sent when the agent ends its turn. Pause it, reorder it, edit it.
- **Ask one session from another.** You ask, and the answer comes back to the session you asked from by itself (Claude Code and Codex).
- **Two agents, one repository, separate trees.** A git worktree per session, offered when it's needed.
- **Watch two at once.** Split the pane.
- **Answer from the kitchen.** One key starts the web cockpit and shows a QR code. Your phone sees the sessions you share, what each agent said last and what it changed, and you can reply, queue a message or press the key a prompt is waiting for.
- **Close it, come back tomorrow.** Sessions, notes and queues are remembered, and conversations resume.

The sessions panel looks like this:

```
1 ● auth-refactor
2 ▲ fix-flaky-test
3 ✓ docs-pass
```

One is working, one is waiting for me, one finished while I was looking somewhere else. That is the whole question answered at a glance.

## Still a little bitter

cicoria is young, and I'd rather say it plainly. It is a `0.0.x` release, nine days old. I develop it on Linux, and it runs on WSL2. There are macOS binaries, but I have not tested them myself, so reports are very welcome. Agents other than the three supported ones get a guessed status and a queue you send by hand. Copilot can't be asked a question by another session yet. The web cockpit speaks plain HTTP, so on a network you don't trust, put it behind a VPN or Tailscale. The roadmap has plenty of open items. I built it for how I work; tell me where it doesn't fit how you work.

## Try it

```sh
curl -fsSL https://henomis.github.io/cicoria/install.sh | sh
```

Or `go install github.com/henomis/cicoria@latest` if you prefer. When it starts, a small chicory flower grows in the agent pane. I'll let you find it.

Documentation is on the [cicoria website](https://henomis.github.io/cicoria/), and the code is on [GitHub](https://github.com/henomis/cicoria).

Like my other projects, cicoria is made by one person, at one desk in Italy, and this is a beginning. If you try it, I'd love to know which agent you want next. Gemini CLI is first on the roadmap: tell me the one after that, and open an issue when something breaks.

Now, when an agent needs me, cicoria tells me. Just like the pan. And I can answer it without leaving the stove.
