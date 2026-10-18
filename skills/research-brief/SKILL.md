---
name: research-brief
description: Use when the user needs sourced research before a deliverable.
  Reads provided documents and websites and writes research/brief.md with
  atomic, individually citable findings. Do NOT use for quick lookups, or
  when the user already has a usable brief.
---

# Research Brief

## Process
1. Confirm topic, scope, audience, and time window. Ask at most 3 questions.
2. Read every source the user provided. If the topic is regulatory, go to
   each regulator's own publications page before trusting secondary coverage.
3. Write `research/brief.md` in exactly this shape:

   # Brief: <topic>

   ## Scope
   What is in and out of bounds.

   ## Findings

   ### <short finding title>
   - Claim: <one sentence>
   - Nuance: <jurisdiction, instrument type, and effective date, or any
     qualifier that changes how the claim applies. E.g.
     "Onshore UAE, Federal Decree-Law, effective 1 Jan 2026."
     Write "N/A" only if the claim has no qualifier.>
   - Source: <URL or document path> — <YYYY-MM-DD> — <high|medium|low>

   (repeat per finding; one claim per entry)

   ## Timeline
   - <YYYY-MM-DD> — <event>

   ## Next steps
   - Owner: <named person or role>
   - Date: <YYYY-MM-DD>

   ## Open questions
   - [UNVERIFIED: <what could not be confirmed>]

## Rules
- Every claim carries a source. No source, no claim.
- Atomic findings only. The deck skill cites these individually; a paragraph
  of prose is unusable downstream.
- Do not write slides. Do not suggest deck structure.
- Do not pad. Ten solid findings beat thirty thin ones.
- "Next steps" is required. The deck skill refuses to build without it.
