---
date: '2026-10-20T08:00:00+02:00'
title: 'Cicoria: a workbench for agent-centric development'
tags: ["go", "ai", "coding-agents", "open-source", "cicoria"]
aliases: ["/en/cicoria-the-agent-works-you-watch-the-pan/"]
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

I don't write most of my code anymore. I write the spec, agents write the code, and I own the review.

That changes what you need from your tools. So I built a new workbench for it. It is called **cicoria**, and it is out today.

## From code-centric to agent-centric

For years we were used to working around code. The editor sat at the center, and everything else (the terminal, git, the review) was arranged around it, because the work was typing code into files.

AI-first development moves the center. The unit of work is no longer a file, it's an agent session. I spend my time describing what I want, reading what an agent changed, pointing at the lines that are wrong and sending it back to work. The code is still there, but I meet it as a diff to review, not as a buffer to type into.

On my [dark factory](https://simonevellei.com/darkfactory/) page I describe how I build software this way: agents write the code, I own the spec and the gates. cicoria is the workbench that way of working runs from.

## Several projects at once

There is a second change, and it is just as big. With agents you work on several projects at once.

One agent reworks an API, another fixes a bug in a different repository, a third writes the docs of a side project. None of them needs me all the time, so I don't stay on one. I move between them: steer one, review another, queue the next instruction for a third.

Terminal tabs are a poor fit for that. Every tab looks the same, whatever the agent behind it is doing, and what each one changed is hidden until you go and look.

The key idea of cicoria is simple: it does not replace your agents or wrap them in something new. Claude Code, Copilot CLI and Codex CLI run untouched, each with its own interface in a real terminal pane. cicoria is the bench around them. It shows what every session is doing, what each one changed, and lets you send your review back.

The agents do the work, and you stay in the loop. Every message an agent gets is one you wrote or queued.

## Built from friction

The idea turned up at 5:15 on Sunday morning, 11 October. By the end of the morning it was a plan an agent could follow, and an agent started building it.

From there cicoria was built the way it is meant to be used: agents doing the implementation, me owning the spec and the review, nine days from the first idea to today. And because I was running agents to build a tool for running agents, every rough edge showed up immediately.

The commit history reads less like a changelog and more like a diary of those edges.

The very first thing built after the initial commit was a message queue per session. The next thing to tell an agent often arrives while it is still in the middle of a turn. Now it waits in line, and cicoria sends it when the turn ends.

By mid-afternoon came the review. Agents commit their own work, which means a plain `git diff` is often empty right when you want to see what happened. So cicoria counts the changes from the commit the session started on. Pointing at exact lines while reviewing was the next itch, so notes on lines arrived, sent back to the agent as one message.

Over the next days came Copilot CLI and Codex CLI, WSL2, the git branch in the title, and a git worktree of its own for a session that would share a directory with another. Then the changes of a busy session started to blur together, so a commits panel now lists what the session committed and lets you look at one commit at a time. Sessions also started to pile up in other windows, so the terminal's title now names the ones that need you.

The last one came from being away from the desk. Work doesn't stop when I get up, and I wanted to keep steering it. So cicoria now has a web cockpit: your phone sees the sessions you share, and you can follow and answer them from there.

Each feature is a small answer to a moment where the tool got in the way.

## What's on the workbench

Before the list, a minute of a real session. Claude Code writes a small Go HTTP server while a README waits in its queue, a second session in a split pane counts the lines of `main.go`, and a note on the diff asks the first one for a new endpoint.

<video controls muted playsinline preload="metadata" poster="https://henomis.github.io/cicoria/demo.jpg" style="width:100%;height:auto;">
  <source src="https://henomis.github.io/cicoria/demo.mp4" type="video/mp4">
  <a href="https://henomis.github.io/cicoria/demo.mp4">Watch the cicoria demo</a>
</video>

Here is what is on it today, in one line each. The [documentation](https://henomis.github.io/cicoria/) has the details.

- **Every project on one bench.** A session is one agent in one directory, so one workspace holds sessions from several projects.
- **See what every session is doing.** Working, waiting for you, done while you looked away, idle or exited, and for how long.
- **Jump straight there.** One key takes you to the next session that needs you. A desktop notification and the window title tell you too, even from a tab in the background.
- **Your agent, untouched.** Claude Code, Copilot CLI and Codex CLI with full hook integration, given to the agents cicoria launches without touching your settings. Any other CLI agent works too, with its status guessed from terminal activity.
- **Review what it did, commits included.** A changes panel and full screen diffs, counted from the commit the session started on.
- **Walk through its commits.** A commits panel lists what the session committed, and narrows the changes to one commit at a time.
- **Review it like a pull request.** Notes on lines go back to the agent as one message quoting files and lines.
- **Line up what to say next.** A queue per session, sent when the agent ends its turn. Pause it, reorder it, edit it.
- **Ask one session from another.** You ask, and the answer comes back to the session you asked from by itself (Claude Code and Codex).
- **Two agents, one repository, separate trees.** A git worktree per session, offered when it's needed.
- **Watch two at once.** Split the pane.
- **Steer from your phone.** One key starts the web cockpit and shows a QR code. Your phone sees the sessions you share, what each agent said last and what it changed, and you can reply, queue a message or press the key a prompt is waiting for.
- **Close it, come back tomorrow.** Sessions, notes and queues are remembered, and conversations resume.

The sessions panel looks like this:

```
1 ● auth-refactor
2 ▲ fix-flaky-test
3 ✓ docs-pass
```

One is working, one needs me, one finished while I was looking somewhere else. Three projects, one glance.

## Still a little bitter

Cicoria is Italian for chicory: I was cooking some while an agent wrote its first lines, and the name stuck. Like the vegetable, it is still a little bitter.

It is very young, nine days old. I develop it on Linux, and it runs on WSL2. There are macOS binaries, but I have not tested them myself, so reports are very welcome. Agents other than the three supported ones get a guessed status and a queue you send by hand. Copilot can't be asked a question by another session yet. The web cockpit speaks plain HTTP, so on a network you don't trust, put it behind a VPN or Tailscale. The roadmap has plenty of open items. I built it for how I work; tell me where it doesn't fit how you work.

## Try it

```sh
curl -fsSL https://henomis.github.io/cicoria/install.sh | sh
```

Or `go install github.com/henomis/cicoria@latest` if you prefer. When it starts, a small chicory flower grows in the agent pane. I'll let you find it.

Documentation is on the [cicoria website](https://henomis.github.io/cicoria/), and the code is on [GitHub](https://github.com/henomis/cicoria).

Like my other projects, cicoria is made by one person, at one desk in Italy, and this is a beginning. If you try it, I'd love to know which agent you want next. Gemini CLI is first on the roadmap: tell me the one after that, and open an issue when something breaks.

The editor was the center of the old workbench. On the new one, the center is the agents, and my job is to keep up with them.
