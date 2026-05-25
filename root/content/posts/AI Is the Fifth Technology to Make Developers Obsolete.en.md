---
date: '2026-05-24T20:01:47+02:00'
title: 'AI is the fifth technology to make developers obsolete'
tags: ["ai", "developers", "software", "productivity"]
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
featuredImage: "/images/ai002.png"
images: ["/images/ai002.png"]
code:
  maxShownLines: -1
cover:
    image: "/images/ai002.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

Every decade, like clockwork, someone announces that developers are finished. The script never changes. A new technology promises to make the programmer redundant. Someone writes a triumphalist article. Decision-makers start dreaming about better margins.

## Four times before

### The 1980s: fourth-generation languages

4GLs promised the end of traditional programming. The finance manager would write his own reports. The sales analyst would build her own dashboard. For a while it worked, as long as the systems stayed small. Then the data grew, requirements got messier, performance began to degrade. In the end, developers were called in to rewrite everything in general-purpose languages.

### The 1990s: CASE tools and UML

The idea was seductive: draw the diagram, the machine generates the code. For almost a decade it looked like the right path. Then the structural problem became obvious. The generated code was nearly unreadable, and you couldn't fix a complex bug by redrawing the diagram. Round-trip engineering, perfect in theory, broke down on the first serious attempt. Anyone who had invested in it ended up with two codebases to maintain: the model and the code, forever out of sync.

### The 2000s: CMSs

This was a real success, but a confined one. CMSs genuinely let anyone build a brochure site or a blog. The trouble started when companies tried to extend the idea: e-commerce with specific business rules, integration with internal systems, real traffic at scale, actual security. At that point the stack filled up with plugins fighting each other, vulnerabilities to manage, and developers called in to fix what was supposed to be "three clicks".

### The 2010s: low-code and no-code

The "citizen developer" would take software development into the business units by dragging blocks around. To a point, it worked. For prototypes, internal workflows, small apps, these platforms are great. Then comes the wall. Security requirements the platform doesn't cover. Integration with legacy systems that still needs code. License costs that explode as usage grows. Vendor lock-in that blocks any evolution. When the app becomes critical, you call a developer again. Often to rewrite it somewhere else.

---

Four promises, four disappointments, four waves of developers called back to clean up the mess.

And now we're on the fifth round.

## But this time really is different

I want to pause here, because dismissing AI as "another bubble" would be dishonest. It isn't.

The four previous attempts were rigid abstractions: predefined schemas, configurable blocks, rule-based generators. They were tools, not intelligence. They constrained development to predictable paths and fell apart outside them. They worked in the small space their designers had imagined, and nowhere else.

Generative AI is something else. It's the first technology in sixty years of computing that can write original code, reason about a problem in natural language, debug an error it has never seen before, work inside a codebase that wasn't designed for it. A good agent today does in twenty minutes what an experienced developer needs hours for. It's changing how we work, what productivity means, where value concentrates. If you don't see it, you're not looking.

So yes, this time the technology is on another order of magnitude. Deeply so. But the **conclusion** many people are drawing from it ("we don't need developers anymore") is the same one they drew forty years ago. And that's where the script becomes identical.

## The wrong conclusion from a correct premise

Here's the pattern. Someone on the product team (a sharp PM, a curious designer) opens Claude Code and in one afternoon stands up something that works. They demo it to the team. They demo it to the boss. It looks like magic, and to a real extent it is. The conclusion, though, makes an illogical leap: "See? We can do without them."

Enter Dunning-Kruger, faithful companion of every technological revolution. The more a technology lowers the barrier to entry, the more it amplifies the illusion of competence in people who don't see what's underneath. AI is particularly insidious because it actually works. It produces syntactically perfect code, often conceptually solid too. It looks like a senior's code. Sometimes it is. Sometimes it's a trap dressed up as a senior, and from the outside the difference is invisible.

## Writing code was never the problem

This is the misunderstanding that has been passed down for forty years, unchanged. All these technologies (4GL, CASE, CMS, low-code, and now AI) focus, or focused, on the easy part of the job: writing code.

Except that writing code, by Pareto, is 20% of the problem. The real work is the other 80%:

- Understanding what's actually needed, not what the client says they want.
- Modeling the domain so it holds up to five years of change.
- Thinking about the edge cases that aren't in the spec because nobody thought of them.
- Security: authentication, authorization, input validation, threat modeling.
- Performance under real load, not the three-user demo.
- Data consistency when things go wrong (and sooner or later they go wrong).
- Observability, debugging, error recovery.
- Maintainability: code gets read a hundred times more than it gets written.
- Integration with systems whose rules are unwritten and whose APIs are documented worse.

This is the sneaky part. It doesn't show up in the demo. It doesn't even show up in the first days of production. It shows up two months in, when an important client reports an intermittent bug nobody can reproduce. Or a year in, when you need to add a feature that splits the data model in half. Or on a Saturday night, when the system crashes because someone uploaded a CSV with an unexpected character.

A senior developer doesn't get paid to write `if/else`. They get paid for having seen what happens after the `if/else`. They get paid for the eyebrow that lifts when a spec doesn't quite add up. They get paid to say "hold on" before the train derails.

## AI amplifies the skilled and exposes the unskilled

And precisely because AI is different from what came before, this time the misunderstanding costs more. The previous attempts failed fast: within a few months it was obvious the system didn't scale, and you called the developer. AI doesn't fail like that. AI takes you much further before the cracks show. You build, you deploy, you ship, you get users. And then, when the real problems surface, you're inside a system nobody actually designed.

The problem isn't the quality of the generated code. It's that the generated code answers the question you asked. And asking the right question (recognizing the implicit requirements nobody will tell you) is exactly the skill people are trying to replace.

A good developer with a good agent today is dramatically more productive than six months ago, and that's remarkable. But productivity multiplies the people who know what they're doing. To people who don't know what they're doing, AI offers the chance to produce disasters faster, at greater scale, with more confidence.

## The ending, already written

In the next 12 to 24 months we'll see the same ending as always, only more expensive. Companies that got excited will have applications in production, built "without developers", that now need to be maintained, extended, secured, integrated with the rest of the information system. They'll look for developers. They'll look for the same developers they declared obsolete. And they'll pay much more than they would have paid in the first place to do things right.

Not because AI doesn't work. It works, and it works beautifully. But because software, for the past sixty years, has never been a problem of writing lines of code. It's a problem of understanding a domain, anticipating failure, holding a living system together over time. And those skills, at least for now, AI doesn't replace. It amplifies them in the people who already have them, and it makes their absence painfully obvious in the people who don't.

So yes, let's hold the developers' funeral. We've already held four. This fifth one is different from the others: the technology is real, powerful, transformative. But it will end like the others, with the deceased's family calling someone in to clean up the situation. And the developer will show up. Only this time, with an agent in hand.
