# DARK SECTOR ONLINE — How to keep building until it is complete

The master prompt is the law. It is not the engine. After you paste it once, you do not “ask it to make the game.” You run slices until Phase 8 exists and Phase 7 networking is stable.

## Title
**DARK SECTOR ONLINE**

## What “complete” means
Not infinite content. The first complete game is:

- A player can pick Vesper / Anvil / Kestrel
- Fly top-down with inertia
- Scan and harvest with detachable craft
- Fight NPCs and other players under Green / Amber / Red rules
- Bolt modules that change the ship’s silhouette
- Plant a claim, grow crops, keep animals
- Finish authored + generated quests
- Save, reload, and persist a claim on a server or listen-server
- There is enough content that the loop does not starve (about 12 systems, 40 modules, 15 authored quests)

After that you are in live-ops (Phase 9): add modules, regions, quests. That is post-complete.

---

## The only message you send after the master prompt

Do not re-pitch the game. Do not say “make the whole game.” Paste this:

```text
Continue the DARK SECTOR ONLINE loop.

Rules:
- Do not restart the design or rename systems.
- Implement only the next incomplete slice from LOOP STATE.
- Keep every previous slice working.
- Placeholders are allowed for art. Stubs that only print TODO are not.
- When the slice is playable, rewrite LOOP_STATE.md in the repo root.
- Stop at the end of this slice unless I say "keep going this session."

Current LOOP STATE:
<<paste the latest LOOP_STATE.md here>>

Repo / project path:
<<paste path or say "the open project">>
```

If the agent already has the repo open, you can shorten to:

```text
Continue. Next slice only. Update LOOP_STATE when done.
```

---

## Session rhythm (this is the loop)

1. Open the same project. Never a new blank project.
2. Paste continue + current LOOP STATE.
3. Let it implement one slice.
4. You playtest the checklist for that slice (below).
5. If it is broken, send: `Fix the playtest failures: … Then update LOOP STATE.`
6. If it works, copy the new LOOP STATE out of the reply / file.
7. Start a **new chat** when the context is fat, and paste master prompt + latest LOOP STATE + “the repo is the source of truth.”
8. Repeat until Phase 8.

New chat is normal. New design is not.

---

## Slice order (do not skip)

| Slice | You should be able to do this before you continue |
|---|---|
| 1 Helm | Pick a starter. Fly with inertia. Zoom camera in one system |
| 2 Craft | Probe scans a planet. Drone returns resources. Losing a craft is possible |
| 3 Modules | Install a part. Ship looks different and handles different. Save / load |
| 4 War | Fight pirates. Gain PDO heat. Flee and live |
| 5 Claim | Plant a core. Grow one crop. Keep one animal from dying |
| 6 Quests | Finish one authored beat and one generated contract |
| 7 Online | Green/Amber/Red. Listen-server or dedicated. Second captain can contest a claim |
| 8 Density | ~12 systems, ~40 modules, enough life and quests that the loop holds |
| 9 Tools | Add a module or quest from data files without rewriting code |

You are still before Slice 1 if no Godot/Unity project exists yet.

---

## What to put in the repo and never leave in chat

- `LOOP_STATE.md` at the project root
- `DARK_SECTOR_ONLINE_MASTER_PROMPT.md`
- The game project itself
- A `PLAYTEST.md` the agent updates per slice

Chat is disposable. The repo is the game.

---

## When the agent goes wrong

| It does this | You send |
|---|---|
| Redesigns the fantasy / changes genre | `Reject the redesign. Re-read LOOP STATE. Implement the next slice only.` |
| Writes a design doc instead of code | `No more documents. Open the project and ship the next playable slice.` |
| Jumps to multiplayer before helm works | `Stop. Slice order is mandatory. Finish the current slice.` |
| Leaves TODO stubs | `Replace stubs with a playable substitute. Update LOOP STATE honestly.` |
| Context amnesia | New chat + master prompt + full LOOP STATE + “repo is source of truth.” |

---

## Playtest gate (you run this, not the model)

After every slice, launch the build and tick only what that slice promised. If you cannot tick it, it is not done. Do not continue.

---

## Online-specific rule

“Online” does not mean build the MMO first.

- Slices 1–6 are single-player with **online-shaped data**: ownership, heat, wrecks, claim IDs.
- Slice 7 is listen-server, then dedicated.
- Persistence of claims and ships is the actual online product. Chat and cosmetics are last.

---

## How long this takes in real work

A competent agent + you playtesting:

- Slice 1–3: first playable weekend
- Slice 4–6: a vertical slice people can feel
- Slice 7: real online
- Slice 8: “the game exists”

That is weeks to months, not one prompt. The loop is how you survive that.

---

## Your next action right now

If you already pasted the master prompt into an agent that can write files:

1. Point it at an empty folder that will be the game repo.
2. Send the continue message above with the LOOP STATE in this folder (Slice 1 is next).
3. Confirm engine: Godot 4 unless you already started something else.
4. Do not ask it for another prompt. Ask it for the project.

If that agent cannot create a Godot project, say so and use Cursor / Godot on your machine with the same continue message.
