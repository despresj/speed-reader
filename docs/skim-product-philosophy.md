# Skim — Product Philosophy

*A machine for upgrading attention, comprehension, and extraction from text. Not a speed-reading app.*

> The "speed reader" framing is a trap. It puts the product in a category of gimmicks people try once, feel guilty about, and abandon. Speed is a side effect here, not the point. The point is what happens to your *attention* when a machine takes the throttle. This document is the argument for that — and a fence around it.

---

## 1. The core human burden Skim removes

**Generic answer (rejected):** "Reading is slow / there's too much to read."

**The real burden:** When you read, you are doing two jobs at once — *propelling your eyes forward* and *metering your own attention*. You are the engine and the governor simultaneously. On a phone this is brutal: the page is a battlefield. Every line competes with the scroll gesture, the notification, the next tab, the urge to skim ahead and the urge to drift back. Most of your effort goes not into understanding but into the exhausting micro-war of *staying on the line* — keep going, no go back, wait did I get that, how much is left, ugh.

Skim removes the governing. You hold a thumb; the text arrives at a cadence you cannot outrun and cannot fall behind on. There is nothing to scroll, nothing to skim past, no "67% remaining" dread, no escape hatch. The reading surface collapses to a single point, so attention has nowhere to leak.

> The burden removed is **self-pacing under temptation.** You stop having to manufacture discipline. The instrument supplies the cadence; you supply only the looking.

---

## 2. The emotional payoff

**Generic answer (rejected):** "You feel productive. You read faster."

**The real payoff:** the relief of being **carried.** Reading is normally effortful self-propulsion — swimming. Skim is the rare experience of text moving *for* you while you stay still — floating in a current. You are not fighting the page; the page is delivered.

And then the part no phone ever gives you: **completion without residue.** The dominant emotion of reading on a phone is *guilt* — the graveyard of half-read tabs, the article you swore you'd finish, the open loop that never closes. Skim inverts it. You held your thumb, the thing ended, the check said you got it, you let go. Nothing left running in the back of your head.

> Calm while reading. Closure after. The opposite of the anxious, half-attended, never-finished way we read on phones now.

---

## 3. The strongest repeat-use loop

**Generic answer (rejected):** "Copy text → read → repeat." That's the mechanic, not the loop. A loop needs a reward that *compounds.*

**The real loop is: doubt → proof → escalation.**

RSVP has one eternal, fatal suspicion: *"Sure, that was fast — but did I actually absorb it?"* Left unanswered, that doubt quietly erodes every session and the habit dies as a novelty. Skim's comprehension check exists to close that loop — grounded questions about the main thread, not trivia, never punitive, with a gentle speed suggestion at the end.

So the loop becomes:

1. You try it on something low-stakes (a tweet, a message).
2. The check confirms you *got it.*
3. Trust in the instrument ticks up.
4. You hand it something harder next time — the essay, the spec, the dense work email.

Every passed check is **evidence that this strange way of reading works.** That evidence is what converts a curiosity into a daily instrument. The instrument earns increasing responsibility; the user keeps escalating what they'll trust it with. Each session deposits proof, and proof compounds.

> Without the check, the loop is fragile — nagging doubt drains it. With the check, reading becomes *verifiable*, and a verifiable habit is a durable one.

---

## 4. The product philosophy

**Skim is an instrument, not an app.** A metronome, a treadmill, a tuning fork — a machine you *submit to*, which gives back a capability you couldn't summon by willpower alone.

The doctrine, in one line:

> **The instrument supplies the discipline so the mind can supply the attention.**

Three commitments fall out of that:

- **Constraint is the gift.** Most software competes by adding capability and choice. Skim competes by *removing* it. You cannot skim. You cannot skip ahead. You cannot multitask. That removal is the entire feature — it's what hands your attention back to you. Every knob you add is a re-introduction of the burden in §1.
- **The reading surface is sacred.** One word, a faint progress line, an invisible rail. No buttons, no toolbars, no permanent metrics. The app should feel *controlled, not configured.* Controls are physical gestures confirmed by haptics, not chrome.
- **Attention is a muscle the phone has atrophied — and the cure is not more willpower, it's a better instrument.** Skim is not a productivity tool you discipline yourself to use. It is the discipline, made into an object you can hold in your thumb.

---

## 5. The five features that express the philosophy

Each of these already lives in the codebase, and each is a direct expression of the doctrine — not a feature bolted on for completeness.

1. **The whole surface as controller.** Your body is the controller. Holding *is* the engagement; releasing is an honest pause. Sliding adjusts cadence and a sideways flick recovers meaning without hunting for a control. You are physically holding the discipline. This is the doctrine made literal.
2. **The sacred surface.** One anchored reading unit on a quiet ink-and-paper field, with no persistent toolbar competing for attention. It removes the page-as-battlefield so attention has nowhere to leak (§1).
3. **Semantic recovery — Threadline.** Pause and the surrounding prose rises at the foot of the screen, the active unit marked by the theme's thread color and natively scrollable; flick-left replays the sentence. *Recovery matters more than speed.* You're allowed to fall, because you'll always be caught — which is what makes it safe to let go and be carried (§2).
4. **The grounded comprehension check.** Questions about the main thread, never trivia, never punitive, with a "this seems off" flag so a bad item never reads as *your* failure. This is what turns reading into *verified extraction* and powers the repeat-use loop (§3). It is the single feature that earns the right to drop "speed reader."
5. **Pacing as rhythm.** Punctuation and paragraph multipliers give the stream breath — a comma is a beat, a period a rest, a paragraph an inhale. The instrument reads *with* the meaning, not merely fast. Calm, not frantic.

---

## 6. The five tempting features that should be avoided

Each of these is plausible, requested-sounding, and would quietly kill the thing.

1. **WPM leaderboards, streaks, speed stats.** This is the strongest pull and the most lethal. It turns a calm instrument into a performance test, makes *speed* the goal instead of comprehension, and reintroduces the anxiety Skim exists to remove. The number must stay invisible by default forever.
2. **AI summarization that replaces reading.** The seductive one in an AI world: "let the model read it for you." This destroys the entire premise. Skim *upgrades your* attention; a summary *outsources* it. The AI here may verify comprehension; it must never substitute for it. **Don't let AI read for you. Use AI to prove you read.** (See §8.)
3. **Accounts, cloud library, sync.** Turns a clipboard instrument into a document-management chore. The moment you're *managing* reading instead of reading, the frictionless wedge (§7) is dead. The clipboard is the library.
4. **Infinite settings, custom bands, theme sprawl.** Every knob hands back the self-metering burden you removed. "Controlled, not configured." A handful of speed bands you *feel* (slower/faster), never a 387-WPM slider.
5. **A social feed / vanity sharing / "I read 40 articles" badges.** Reading is not content to produce. The video/gif export must stay a *quiet artifact of a real read* (and a clean demo — §7), never an engine for turning your attention into someone else's metric.

---

## 7. The wedge for distribution

**Generic answer (rejected):** "Make it free, do ASO, hope it goes viral."

**The structural wedge: the clipboard is the universal input.** Every app on the phone produces copyable text. Skim is the universal *consumer* of it — no integration, no import flow, no permission dance. It rides the one gesture every person already performs a dozen times a day: *copy.* Nothing to set up means nothing between intent and value.

That makes the demo sell itself in five seconds, and the demo is inherently *showable*: watch someone consume a dense paragraph in eight seconds with one thumb — **and then correctly answer what it said.** Speed alone is a parlor trick; speed *plus proof of comprehension* is the shareable artifact. (This is the legitimate, narrow role for video export: a clip of a paragraph ingested in seconds is a natively short-form, scroll-native demo.)

**Aim the wedge at the people for whom self-pacing is hardest, not the optimizers.** External pacing is a real, known accommodation: people with ADHD, students drowning in must-read material, researchers and PMs buried in specs, anyone whose attention won't hold the page on its own. Lead with honesty — *"for when your attention won't hold the page by itself"* — not with "read 3x faster." The optimizer churns; the person who finally *finished the article* stays.

> A reading tool whose every public use is a silent advertisement, riding the one input channel shared by every app on the device.

---

## 8. Why this could matter in an AI-native software world

In an AI-native world, machine-generated text explodes past any human's capacity to read it. The reflexive answer is: *have a model read it back to you.* Summarize the thread. TL;DR the doc. Let the agent digest the report.

Follow that to its end and you get a generation that lives on summaries-of-summaries — that never ingests primary text, can't catch the model's lie, can't evaluate the source, can't think *with* the actual words because it never met them. Comprehension gets fully outsourced to a system the user can no longer check.

**Skim is the counter-bet.** The scarce skill in an AI world is not generating text or compressing it — models do both infinitely. The scarce skill is the **human capacity to absorb and verify primary source at high throughput.** A model can write anything; only a person can be *accountable* for having actually understood it. Skim raises your personal *read bandwidth* so you don't have to delegate comprehension to something you then can't audit. It keeps the human in the loop at machine scale.

And it does this with the right posture toward AI — the one most consumer software is getting wrong:

- The fashionable AI-native app is a thin chat over a model; the model *is* the product. Skim is the inverse: a hard, crafted, physical instrument where AI is a quiet, grounded subsystem — bring-your-own-key, off to the side, schema-validated, never logged, used only for what it's genuinely good at (generating grounded questions). **AI as ingredient, not as the dish.**
- It draws the one line that matters: **don't let AI read for you; use AI to prove you read.** In a world where everyone's first instinct is to hand attention to a model, the durable, premium, distinctly human act is *verified first-hand comprehension at speed.*

That is what Skim is for. Not reading faster. Keeping a mind sharp enough to stay accountable in a world writing faster than anyone can think.

---

## The one-line test

Every future feature gets held to this:

> **Does it hand the user's attention back to them — or quietly take it away again?**

Ship the first kind. Refuse the second.
