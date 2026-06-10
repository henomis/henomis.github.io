---
date: '2026-06-09T19:00:00+02:00'
title: 'The 80% AI doesn''t demo: a field guide to the hard part of software'
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
featuredImage: "/images/ai003.png"
images: ["/images/ai003.png"]
code:
  maxShownLines: -1
cover:
    image: "/images/ai003.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

A working demo is a promise the system hasn't agreed to keep yet.

In a [previous article]({{< relref "AI Is the Fifth Technology to Make Developers Obsolete.en.md" >}}) I argued that writing code is, by Pareto, about 20% of the job, and that the other 80% is the part AI doesn't replace. I listed that 80% as a string of bullet points and moved on. That was a cheat. Those bullet points are the whole argument, and they deserve more than a list.

So here's the field guide. Nine parts of the job that never show up in a demo, each with the moment it comes back to bite. Because the danger isn't that AI writes bad code. The danger is that it writes code that *works in the demo*, and the demo is exactly where none of this is visible.

## Before a line is written

### Understanding what's needed, not what was asked

A client asks for a button that exports the report to Excel. An agent builds a button that exports the report to Excel. Everyone's happy until you discover what they actually needed was to reconcile that report against the accounting system, and Excel was just the only tool they knew how to do it with. The button was never the requirement. It was the client's guess at a solution, repeated back to you as if it were a need.

This is the first and largest gap, and it's the one AI is worst at, because the agent has no way to know what wasn't said. It builds, faithfully and quickly, the wrong thing. A developer's first job isn't to write the export. It's to ask "what are you going to do with this file once you have it?", and to notice that the answer changes everything.

### Modeling a domain that survives five years

The data model is the one decision you can't refactor your way out of cheaply. Everything else, the UI, the endpoints, the business logic, you can rewrite over a weekend. The schema you can't, because by the time it's wrong it has a million rows in it and four systems reading from it.

An agent will give you a perfectly reasonable model for the feature you described. The problem is that the model has to survive the *next* feature, the one nobody's mentioned yet, the one that turns "a user has an address" into "a user has many addresses, in many countries, some of which are invalid but historically meaningful." A demo never tells you which of your tables are load-bearing. You find out the day a feature splits the model in half, and you're holding both pieces.

### The edge cases that aren't in the spec

The spec describes the happy path, because the happy path is the only one anyone imagined while writing the spec. It doesn't mention the empty list, the duplicate submission, the user whose timezone doesn't legally exist, the name with an apostrophe, the file that's technically valid and semantically insane.

These aren't in the requirements because nobody thought of them, and an agent, asked to implement the requirements, won't think of them either. The spec is the floor, not the ceiling. The skill is knowing that the interesting half of the work begins exactly where the document ends.

## Where production actually breaks

### Security: the part that's invisible until it isn't

Authentication, authorization, input validation, threat modeling. Generated code is, almost always, *syntactically* secure: it parameterizes the query, it hashes the password. It is much less often *structurally* secure, because security isn't a property of a line of code. It's a property of how the whole system handles someone who is actively trying to break it.

The agent doesn't model an adversary unless you tell it to, and you only know to tell it to if you've already been on the wrong end of one. The CSV with an unexpected character that escapes a context three layers down. The endpoint that checks authentication but forgets authorization, so any logged-in user can read any other user's data by changing a number in the URL. None of that shows up in a demo, because in a demo nobody is attacking you.

### Performance under real load

Everything is fast with three users and a hundred rows. The demo is always fast. That's the trap.

The N+1 query that fires once per item in a list is invisible until the list has ten thousand items. The missing index doesn't matter until the table is big enough that the full scan takes eight seconds and the requests start piling up behind each other. The cache that made things faster becomes the thing that serves stale data to your most important customer. "Fast on my machine" is a measurement taken under the most favorable conditions that will ever exist, and production is where those conditions end.

### Data consistency when things go wrong

Two requests arrive at the same moment and both decide the seat is available. A payment succeeds but the write that records it times out, so the customer is charged for something the system insists they never bought. A retry, helpfully, double-applies the operation it was retrying.

This is the category that sooner or later goes wrong, because "sooner or later" is just another way of saying "at scale, over time." Generated code handles the case where everything succeeds in order. Holding a system together when two things happen at once, or when the third step fails after the first two committed, is a different discipline, and it's one you have to design for deliberately, because the demo will never, ever surface it.

## The long tail of ownership

### Observability and debugging

Two months into production, your most important client reports a bug. It happens "sometimes." You can't reproduce it. There is nothing in the logs, because nobody added the log line that would have caught it, because in the demo there was nothing to catch.

You cannot fix what you cannot see, and generated code ships without eyes. Instrumentation, structured logging, traces, the breadcrumb that lets you reconstruct what a request actually did at 2 a.m. on a Saturday: none of it is a feature anyone demos, so none of it gets built until the day you'd give anything to already have it.

### Maintainability: code is read a hundred times more than it's written

An agent answers a question and then goes quiet about *why*. The code it produces is often clean, but it carries no memory of the decision behind it: why this approach and not the obvious one, what constraint made the ugly branch necessary, which line you must never touch.

That silence costs nothing on day one and everything on the day someone else has to change it. Software is read far more often than it's written, and most of that reading is someone trying to safely modify a thing they didn't build. Code optimized to be *generated* is not the same as code optimized to be *lived with*, and the difference doesn't appear until the second person arrives.

### Integration with systems whose rules are unwritten

There's always a legacy system. Its API is documented worse than it behaves, its real constraints are written down nowhere, and the only way to learn them is to violate one and read the error. The field that's nominally optional but breaks everything downstream when it's empty. The endpoint that returns `200 OK` with a failure in the body. The undocumented rate limit you discover by hitting it in production.

This part of the job is archaeology, not engineering, and an agent can only work from what's written. The unwritten rules, the ones that live in a senior colleague's head, or in nobody's, are exactly what integration is made of.

## The pattern underneath

### Why none of this shows up in time

Look at the nine and the shared trait is obvious. Every one of them is invisible at demo, invisible on day one, and expensive on month two. That's not a coincidence. It's the definition. These are precisely the problems that *can't* surface early, because they need scale, time, an adversary, a second developer, or a failure to reveal themselves.

This is what I meant by saying AI doesn't change the timeline. The previous waves of "developers are obsolete" tech failed fast: within months it was obvious the thing didn't scale, and you called someone. AI is different and more dangerous precisely here. It doesn't fail fast. It lets you build much, much further before the cracks show. You ship, you grow, you onboard real users, and *then* the 80% arrives all at once, inside a system nobody actually designed.

## What you're actually paying a developer for

Back to the line from the first article: a senior developer doesn't get paid to write `if/else`. They get paid for having seen what happens after the `if/else`.

The nine sections above aren't really nine separate skills. They're one skill wearing nine costumes: the ability to anticipate failure in a system that doesn't exist yet. To feel, while the demo is still applauding, where this is going to hurt in two months. That instinct is the entire job, and it's the one thing a demo is structurally incapable of testing, because a demo only ever shows you the 20%.

AI is extraordinary at the 20%. It's genuinely transformative there, and pretending otherwise is dishonest. But it doesn't supply the 80%. It amplifies it in the people who already carry it, and it makes its absence catastrophic, and fast, in the people who don't.

So the next time a demo looks like magic, ask the only question that matters: not "does it work?" but "what happens two months after it works?" The answer to that question is still, for now, a person.
