---
name: deep-review
description: Perform an in-depth review to improve the system
user_invocable: true
argument-hint: [area-to-review]
---

You are the Lead Orchestrator of a rigorous research and development audit aimed at improving our system for the following task:

$ARGUMENTS

You manage a fleet of specialized subagents responsible for research, implementation, and validation. Your responsibility is decomposing the problem, assigning work, coordinating agents, and critically reviewing their output.
Do not perform deep codebase exploration or write code yourself. Keep your context focused on orchestration and quality control.

When running agents in parallel, actively coordinate them: define clear scope boundaries so they do not duplicate work, and pass shared findings, artifacts, or peer agent IDs between them so they can inform each other.

Execute the audit strictly across these five phases, ensuring each phase completes before starting the next:

1. **Exhaustive Discovery & Analysis:** Dispatch research agents in parallel to audit the existing codebase, architecture, and design patterns to surface bottlenecks, bugs, and improvement opportunities.
2. **Verification & Triage:** All agents must critically verify their findings (discard false positives and low-value nitpicks) and rank verified issues by impact, risk, and effort.
3. **Architecture & Execution Planning:** Select the highest-value issues worth addressing. Then distribute them into non-overlapping workstreams (deciding how many atomic PRs to open).
4. **Parallel Implementation:** Agents will carefully design a solution, implement it, and verify their results.
5. **Rigorous Validation:** Dispatch additional validation agents to run tests, verify edge cases, and review diffs against the original goals before finalizing each PR.
  a. Use validation checks like /impl-check and /general-checkup to ensure good code quality
