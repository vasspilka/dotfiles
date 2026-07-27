---
name: qa-check
description: Run a comprehensive QA pass of a Phoenix application end-to-end. Use as an on-demand check to catch bugs, broken features, and edge cases.
argument-hint: [focus-area]
---

# QA Check: Phoenix Application

You are the **QA lead**. Discover the app, run a backend tester and a frontend tester in parallel, then verify and merge their findings into one report.

**Focus area (optional):** $ARGUMENTS — if provided, both testers prioritize it but still do a general sweep.

## Step 1: Discover the app

Gather the context the testers need (don't skip — their prompts depend on it):

- **Routes:** read the router (`lib/*_web/router.ex`) to list the app's pages and auth-gated scopes. If there are dozens of routes, mark a priority set (focus area first, then core flows) — testers cover priorities exhaustively and the rest with a lighter pass.
- **Dev server & credentials:** find the local URL (usually http://localhost:4000) and seed login credentials — check README, CLAUDE.md, and `priv/repo/seeds.exs`. Note whether seeds contain **a second user** (ideally a different role or tenant) — the frontend tester needs it for authorization probing. If the server isn't running, start it in the background (`mix phx.server`) and confirm it responds; if it won't boot or no credentials exist, tell the user what's missing and stop.
- **Data layer:** note whether the app uses Ash or plain Ecto contexts, and whether Oban is present (`mix.exs`).
- **Tooling:** check which MCP tools are available — TideWave (`mcp__tidewave__*`) for backend, Playwright (`mcp__playwright__*`) for frontend. Fall back to `psql`/`mix run`/`iex` snippets via Bash if TideWave is absent. Without Playwright, skip the frontend tester and say so.

## Step 2: Spawn both testers in parallel

Launch two `general-purpose` agents **in a single message**. Fill each prompt's placeholders with what you discovered, plus the focus area. Both testers share one live database, so each prompt carries ground rules that prevent them from tripping over each other — keep those in.

### Backend tester prompt

```
You are QA-testing the backend of a Phoenix app: {APP DESCRIPTION, DATA LAYER, KEY DOMAINS/SCHEMAS}.
Tools: {TideWave MCP — load via ToolSearch "select:mcp__tidewave__..." | or Bash with psql/mix/iex}.
Focus area: {FOCUS or "everything"}. Document each test: what you tested, result, issues found.

Ground rules — a frontend tester is working the same live database in parallel:
- Read-only checks (1, 4, 5, 6) can run freely. For mutation tests (2, 3), only create, update,
  or delete records you created yourself, prefixed "QA-TEST-". Never touch pre-existing or seed
  data; test cascade deletes only on record graphs you built. Delete your QA-TEST- data when done.

1. **Data integrity (SQL, read-only):** orphaned records across foreign keys; NOT NULL on
   required fields; enum/status columns contain only valid values; updated_at >= inserted_at;
   duplicates where uniqueness is expected (ignore QA-TEST- rows); tenant isolation if the app
   is multi-tenant.
2. **Actions/changesets (eval):** for each major resource/context — create with minimal fields,
   create with invalid data (expect errors), read with filters, update, delete + cascade behavior,
   and any custom actions.
3. **Business rules:** probe the domain's invariants — double-submission, self-approval,
   expired/stale records, permission boundaries. Derive these from the code you can read.
4. **Performance (read-only):** check pg_indexes for missing indexes on foreign keys and common
   query columns.
5. **Jobs (if Oban, read-only):** stuck/failed jobs in oban_jobs; cron jobs configured as expected.
6. **Logs (read-only):** check runtime logs for errors and warnings.

Return a report: Summary (X run / Y passed / Z failed) · Critical Issues · Warnings ·
Edge Cases Found · Recommendations. Every issue must include: the exact query or eval snippet
that reproduces it, expected vs. actual, and the responsible file/line when identifiable.
```

### Frontend tester prompt

```
You are QA-testing the frontend of a Phoenix app at {URL}: {APP DESCRIPTION}.
Tools: Playwright MCP — load via ToolSearch "select:mcp__playwright__browser_navigate" etc.
Sign in at {SIGN-IN URL} with {CREDENTIALS}. Second account for authorization tests:
{CREDENTIALS-B or "none"}. Routes to cover: {ROUTE LIST from router, priority set marked}.
Focus area: {FOCUS or "everything"}. Use browser_snapshot before interacting; save screenshots
of visual bugs to {SCRATCHPAD DIR} and reference their paths in your report.

Ground rules — a backend tester is working the same live database in parallel:
- Prefix text you enter in create forms with "QA-TEST-" and only edit or delete records you
  created yourself; never pre-existing or seed data. Unfamiliar QA-TEST- records appearing
  mid-run is the other tester, not a bug. Delete your records when done, where the UI allows.

1. **Auth:** valid sign-in succeeds; sign-out redirects; a protected route without auth redirects.
2. **Authorization (if a second account exists):** as user A, note the ID/slug of a resource
   owned by user B (or another tenant) and request it directly by URL — expect 403/404, never
   the record.
3. **Every route:** page loads without errors; data or a helpful empty state renders; navigation
   and URL match. Cover the priority set exhaustively; lighter pass on the rest.
4. **Forms (each create/edit flow):** submit empty → validation errors; submit valid → record
   appears. Edge-case inputs — verify the outcome, don't just submit:
   - `<script>alert('xss')</script>` → revisit every page that renders the value; it must
     appear escaped as text, with no dialog.
   - emoji + non-latin text → renders intact after save.
   - 500+ chars → not silently truncated; layout doesn't break.
5. **LiveView:** phx-change shows validation feedback while typing; patch navigation updates
   the URL without a full reload; flash messages appear and clear; watch the console for socket
   disconnects or crash-remount loops (a LiveView can crash, remount, and look fine in a snapshot).
6. **Error handling:** visit detail routes with nonexistent IDs and a nonexistent scope/slug —
   expect graceful 404s, not crashes.
7. **Cross-cutting:** browser_console_messages on every page; browser_network_requests for
   4xx/5xx; browser_resize to mobile width on key pages and check layout.

Return a report: Summary (X pages / Y passed / Z issues) · Critical Issues · UI/UX Issues ·
Console/Network Errors · Edge Cases Found · Recommendations. Every issue must include: URL,
exact steps and input to reproduce, expected vs. actual, and a screenshot path for visual bugs.
```

## Step 3: Verify, merge, and report

When both return, **verify before reporting**: reproduce each critical issue yourself — re-run the query, revisit the page. Downgrade or drop anything that doesn't reproduce; single-pass findings often include plausible-but-wrong results (an "orphaned record" that's an intentional soft-delete, a "missing index" that exists).

Then produce a **unified QA report**:

1. **Critical issues** needing immediate attention
2. **Cross-cutting issues** — related frontend + backend failures
3. All findings **priority-ranked**, each keeping its reproduction steps and file pointers
4. **Quick wins** — easy fixes with outsized quality impact
