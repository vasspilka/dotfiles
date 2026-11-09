---
name: workspace-optimization
user-invocable: true
description: Analyze and improve the current workspace to improve coding agent efficiency.
---

Orchestrate an in-depth quality analysis of the agent context and memory in order to improve coding-agent efficiency.
This will be done through an audit of agent context files, skills and chat traces with the goal to reduce token overhead, eliminate silent trial-and-error loops and improve instructions. Favor deleting text over adding text; every new rule proposed must justify its token cost via empirical friction found in the repo or logs.

You will manage a team of agents to perform the following.

1. Evaluate context and memory files to asses their impact.
  *. Identify misinformation, outdated content, contradictions, unessesary fluff
  *. Deconstruct large pieces context to see if indivual parts can provide improved structure
  *. Identify domain-specific or workflow-specific instructions which would better belong in in-app documentation like moduledocs.
  *. Automate invariants: Flag strict formatting or safety rules written in prose that belong in deterministic harness hooks, linters, or CI checks.
  *. Prune what the model can infer: Mark standard language conventions, framework boilerplate, and generic advice ("write clean code") for deletion.
  *. Flag drift: Identify broken commands, stale file paths, deprecated flags, and contradictory rules.
  *. Quantify impact and identify context that is not nessesary (as common knowledge)
2. Investigate prior chat history to detect common issues or errors
  *. Incorrect assumptions that threw the agents off
  *. Failed operations that required additional information
  *. Spot repeated `grep`/`find`/read loops where the agent struggled to locate core entry points.
  *. Note patterns where the user had to override test scope, verbosity, or architectural choices.
3. Cross synthesis: Try to connect the issues in chat history with specific problems or improvements in context

Reference standards:
- https://www.anthropic.com/research/effective-context-engineering-for-ai-agents
- https://code.claude.com/docs/en/best-practices

Use your knowledge and intuition on what makes good context for the latest releases of LLMs with high intelligence. This will require critical thinking, you need the ability to discern valuable text versus things that appear important but are not. 

After the analysis provide a clear summary of the areas that need improvement.
