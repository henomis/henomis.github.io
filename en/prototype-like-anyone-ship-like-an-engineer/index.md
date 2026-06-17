# Prototype like anyone, ship like an engineer: ground rules for the AI-first company


Now that anyone can build the prototype, the rarest skill is knowing which prototypes deserve to live.

In two previous articles I argued that AI does the easy 20% of software, writing code, and leaves the hard 80% untouched. The [first]({{< relref "AI Is the Fifth Technology to Make Developers Obsolete.en.md" >}}) traced the pattern back forty years, the [second]({{< relref "The 80 Percent AI Doesnt Demo.en.md" >}}) catalogued the 80% in nine parts a demo never shows. Both pieces did the same thing: they pointed a finger. At the PM who builds something in an afternoon and declares engineering obsolete. At the leap from "it works in the demo" to "we don't need them anymore."

Pointing at the problem is the cheap 20% of an argument. This is the other 80%: a proposal. Because the answer to "anyone can prototype now" is not "so stop them." It's "so build the rules that let everyone prototype without anyone shipping a disaster." Here are the ground rules I would pin to the wall of a company that wants to be AI-first and stay alive.

## AI-first is the right call

Let me be clear before the rules start, because the previous articles made this easy to misread. Being AI-first is correct. A company where the PM, the designer, and the analyst all open Claude Code and build is faster, sharper, and closer to its problems than one where every idea has to queue for an engineer just to find out whether it's worth having. Lowering the cost of trying something is one of the great unlocks of this decade, and a company that refuses it out of caution will lose to one that doesn't.

The mistake was never being AI-first. The mistake is being AI-*only*: confusing the 20% the machine does brilliantly with the whole job, and letting the thing that answered a question quietly become the thing that runs the business. AI-first is a way of working. AI-only is a way of failing slowly, expensively, and in production. Everything below exists to keep the first from sliding into the second.

## Two kinds of work

Every rule below comes from a single distinction, so it's worth making it explicit first.

There is work where the cost of being wrong is an afternoon, and work where the cost of being wrong is paid by someone else, over months. A throwaway script, an internal dashboard, the first cut of a feature, an analysis you'll read once: get these wrong and you've lost a few hours, and you've usually learned something. A data model with a million rows in it, an authorization boundary, a public API, a payment flow: get these wrong and you find out two months later, inside a system nobody designed, and the bill is enormous.

Amazon calls these two-way doors and one-way doors. AI is a gift at a two-way door and a loaded gun at a one-way door, and the entire job of an AI-first company is keeping the two straight. Be AI-first on the reversible. Be engineering-first on the irreversible. Everything else is detail.

## The ground rules

1. **Everyone prototypes. No one ships alone.** The 20% belongs to everyone now, so hand it over completely: the PM, the designer, the analyst should all open the tool and build. But shipping, putting something where a customer, a payment, or a colleague's data depends on it, is a separate act with a separate bar. The right to build is universal. The right to ship is earned, and it's owned jointly.

2. **A prototype is a question, not an answer.** Name it as one. The demo asks "should this exist?", not "is this done?". The default destiny of a prototype is the bin, and that is a success, not a waste, because the cheap version answered the question before the expensive version got built. A company that can't throw prototypes away will start shipping them instead.

3. **Be AI-first on processes, engineering-first on systems.** Go fully AI-first where the cost of being wrong is your own afternoon: drafts, analyses, internal tools, scripts, the first version of anything. Stay engineering-first where the cost of being wrong is paid by someone else over months: anything customer-facing, money-touching, data-owning, or hard to take back. The dividing line is not how impressive the thing is. It's who pays when it's wrong.

4. **Treat the prototype as the best spec ever written, not the product.** When a PM builds the thing in Claude Code, they haven't replaced engineering. They've handed it the clearest brief it will ever receive: a specification that runs. That is a gift. It ends the endless argument about what to build. But a spec that runs is still a spec, and the value of the prototype is that it tells you what to build, never that it's the thing you build on.

5. **Know your one-way doors.** Some decisions reverse over a weekend: the UI, the copy, an endpoint. Some never reverse cheaply: the data model, the auth model, a public contract, anything other systems integrate against. Let AI run at full speed through the two-way doors. Put a senior human in front of every one-way door, because that is exactly where the invisible 80% gets locked in for years.

6. **The model is a tool, not an alibi.** Whoever's name is on the deploy owns what it does at 2 a.m. "The AI wrote it" explains nothing and excuses less. Accountability does not transfer to the thing that has no pager and feels no consequences. If no human can stand behind a piece of code, that code is not ready to ship, no matter how good it looks.

7. **Make the 80% a checklist, not a hope.** The parts that don't show up in a demo don't show up on their own either. So turn them into an explicit gate that every prototype crosses before it becomes a product. If the gate feels like bureaucracy, that's because it's doing the exact job the demo refused to do: surfacing the cost before it surfaces itself.

8. **End every demo with one question.** Not "does it work?" but "what happens two months after it works?". Say it out loud, every time, until it's a reflex. The question is free. The silence that sometimes follows it is the most valuable signal in the room.

## When a prototype becomes a product

Rule seven only matters if something actually enforces it. Here is what that looks like.

A prototype becomes a product the moment something real starts to depend on it. That is the line. On one side it's one person's afternoon; on the other it's the company's liability. The gate is what you walk through to cross that line, and it is nothing more than the [nine parts of the job a demo never shows]({{< relref "The 80 Percent AI Doesnt Demo.en.md" >}}), turned from observations into questions a *person* has to answer before shipping:

- **The real need.** What is the user actually trying to accomplish, and does this solve that, or only the literal feature they asked for?
- **The data model.** Will this schema still hold when the next feature arrives, the one nobody has planned yet, or will that feature force a rewrite?
- **The edge cases.** Beyond the happy path the demo showed, how does it behave on empty, duplicate, malformed, or extreme input?
- **Security.** If someone actively tries to abuse this, who could they be, and what concretely stops them from reading or changing data that isn't theirs?
- **Performance.** How does it hold up at real production volume, say a hundred times the demo's data and traffic, and not just on a developer's machine?
- **Consistency.** What happens when two requests hit it at the same instant, or when one step fails after the earlier steps were already saved?
- **Observability.** When it breaks in production at 2 a.m., what logs, traces, or metrics will let us work out why?
- **Maintainability.** When someone other than the author has to change this, will the code make clear why it was built this way and what must not be touched?
- **Integration.** What undocumented rules and failure modes do the external or legacy systems we depend on actually impose?

Notice who answers. Not the agent: the agent built the thing, and asking it to certify its own work is asking the demo to grade itself. A human owns each answer, and an honest "we don't know yet" is a valid answer that simply means the gate isn't passed. The gate is slow on purpose. It is slow in exactly the places AI made fast, which is the whole point, because those are the places the speed was an illusion.

## What you actually gain

The instinct, reading the first two articles, was that AI reduces the need for engineering. It does the opposite. When the 20% becomes free, the 80% becomes the entire competitive advantage. The judgment to model a domain that lasts, to see the adversary, to feel where this will hurt in two months: that was always the scarce thing, and now it's the *only* scarce thing, because everything around it just got commoditized.

So an AI-first company is not the one that prototypes the most, and it's not the one that ships the most carefully. It's the one that always knows which of the two it's doing right now. It lets everyone build, because building is cheap and learning is priceless. And it guards the few doors that don't open twice, because that's where sixty years of software have always told us the real work was.

Prototype like anyone. Ship like an engineer. Never confuse the two, and never let a brilliant afternoon talk you out of the difference.

