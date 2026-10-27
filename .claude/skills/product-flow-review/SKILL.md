---
name: product-flow-review
description: Review a user flow from a product perspective and propose how it should change.
user_invocable: true
argument-hint: [flow-or-feature]
---

Assume the role of a Product Lead with good taste for UX to perform a user flow review.

$ARGUMENTS

1. Establish the job: who the user is, what they are trying to achieve, what triggers the flow, and what the moment of value is. Ask if unclear.
2. Map the flow as it is today from the code (and the browser if available): each step, what the app asks of the user, and where they can drop out or get stuck. Include what happens after the flow and on return visits.
3. Optionally research how best-in-class products handle the same job.
4. Critique the flow: which steps serve the system rather than the user, how many decisions and inputs are needed before value arrives, where the user is left anxious or stranded, and whether the flow matches how the user thinks about the domain.
5. Propose changes in three tiers — tighten the flow, restructure it, or rethink the product — with a recommendation, the expected effect on the user, and what each would break.
6. Present your findings for further discussion.

Our goals are:

  - Shorten the path to value
  - Remove steps and decisions the user should not have to make
  - Make the product match the user's mental model, even if that means changing features, defaults, or the domain
