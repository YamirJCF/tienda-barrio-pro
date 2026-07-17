# BRIEFING — 2026-07-17T02:53:08Z

## Mission
Coordinate the implementation, review, and verification of two critical fixes in Tienda Barrio Pro (database reconciliation and customer editing).

## 🔒 My Identity
- Archetype: orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\orchestrator
- Original parent: main agent
- Original parent conversation ID: fabb451b-f00e-4560-9d42-8b6cc1037707

## 🔒 My Workflow
- **Pattern**: Project Pattern
- **Scope document**: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\orchestrator\PROJECT.md
1. **Decompose**: Decompose the requirements into logical milestones based on architectural boundaries (e.g. database schema/RPC first, then frontend repositories/stores, then UI components).
2. **Dispatch & Execute** (pick ONE):
   - **Delegate (sub-orchestrator)**: Spawn a sub-orchestrator for each milestone.
3. **On failure** (in this order):
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
   - Escalate: report to parent (sub-orchestrators only, last resort)
4. **Succession**: Self-succeed at 16 spawns. Spawn successor, write handoff.md, cancel crons, and exit.
- **Work items**:
  1. Initialize scope and PROJECT.md [pending]
  2. Implement database migrations and RPC (Milestone 1) [pending]
  3. Implement frontend repository and store updates (Milestone 2) [pending]
  4. Implement frontend UI edits and bug fixes (Milestone 3) [pending]
- **Current phase**: 1
- **Current focus**: Decompose requirements and initialize PROJECT.md

## 🔒 Key Constraints
- CODE_ONLY network mode: No external websites or services, no curl/wget/etc.
- Never write, modify, or create source code files directly. All code edits must be done by subagents (e.g., worker).
- Forensic Auditor is NON-SKIPPABLE.
- Binary veto on Forensic Auditor failure (failure = milestone fails).

## Current Parent
- Conversation ID: fabb451b-f00e-4560-9d42-8b6cc1037707
- Updated: not yet

## Key Decisions Made
- Use Project Pattern to structure implementation.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| sub_orch_db | self | Milestone 1 DB Migration | in-progress | 246ce8c8-7824-40fc-87cc-b59c4fee1132 |
| sub_orch_ui | self | Milestone 3 UI Changes | in-progress | e39b6a8d-5e6c-478d-acae-d3c9a1cdedea |

## Succession Status
- Succession required: no
- Spawn count: 2 / 16
- Pending subagents: 246ce8c8-7824-40fc-87cc-b59c4fee1132, e39b6a8d-5e6c-478d-acae-d3c9a1cdedea
- Predecessor: none
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: task-15
- Safety timer: none

## Artifact Index
- c:\Users\Windows 11\OneDrive\Desktop\prueba\PROJECT.md — Global project index and milestones
- c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\orchestrator\progress.md — Execution heartbeat and progress tracking
