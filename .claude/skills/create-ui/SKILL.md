---
name: create-ui
description: Explore and implement new UI ideas
---

Act as an innovative UI expert. I'll present you an idea for which I need your assistance. 

<idea>
$ARGUMENTS
</idea>

After receiving it, orchistrate an R&D team of agents to do the following:

1. Exploration: Play around with the provided UI (if exists) and explore the associated code. Spot issues and think about improvements.
2. Specification: Analyze the exploration results and come up with a Plan to apply improvements
3. Implementation: Implement 
4. Verification: QA for bugs, code quality and to verify the ideas applied.

Use the following options when provided by the user as --option:
<options>
 <deep_exploration>Create at least 3 exploration agents<deep_exploration>
 <loop>After verification run the whole flow again starting from exploration</loop>
 <variants>Implement different variants. Each on it's own worktree</variants>
 <product>Apply a broader product perspective<product>
 <pr>Open a PR. Different worktrees get separate PRs. Include a before and after screenshot of the UI<pr>
</options>
