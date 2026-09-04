# Decisions Log

Every design decision not dictated by the project brief is recorded here.
This file mirrors the tracked decisions in the workspace.

---

## Arena boundary rule: wrap-around
**Outcome:** Arena boundary uses wrap-around. Ships crossing one edge appear at the opposite edge.
**Reasoning:** The official Star Control website explicitly states this behavior. Hard walls would break the gravity-whip mechanic.
**Alternatives rejected:** Hard wall (not original behavior), Bounce (not original behavior).

## SC2 ship properties table as authoritative reference
**Outcome:** Ship stats from the SC2/Ur-Quan Masters table are the authoritative baseline.
**Reasoning:** Only complete, published stat table available. SC1 values not documented anywhere. Differences described as "slight."
**Alternatives rejected:** Guessing SC1 values (violates research mandate), approximate values (forbids fabrication).

## Original names and story under IP guardrail
**Outcome:** All names and story content are original. Kaelen Compact vs Vexari Dominion.
**Reasoning:** Star Control trademark unavailable. Story inspired by source structure, not content.
**Alternatives rejected:** Using source names (trademark risk), thin retelling (violates IP guardrail).

## Unverified items as design decisions
The following items from the research dossier's Unverified section will become tracked decisions as they are resolved:
1. Exact gravity formula -- to be derived from gameplay feel
2. Ship-to-ship collision damage -- to be proportional to relative velocity
3. Camera zoom algorithm -- to be derived from original feel
4. Starting fleet compositions -- to be designed per scenario