---
name: browser-qa
user-invocable: true
description: Perform a QA check that everything works using a browser
argument-hint: "[focus-area] [--fix]"
---

Let's do a quality and functionality check.

Arguments: `$ARGUMENTS`
- Any text other than `--fix` is the focus area. With none, check the app broadly.
- `--fix`: also fix the bugs and issues you find, then commit and push (see "Fix mode"). Without it, only report what you find.

Use playwright to open the browser and check that everything works. You also have access to the backend using Tidewave, you can inspect logs and perform anything else you might need.

## Fix mode (only with `--fix`)

1. Finish the QA pass first and list everything you found.
2. Fix each issue at its root cause and add a regression test where one fits.
4. Re-check every fix in the browser.
5. Run the project's pre-commit checks (e.g. `mix precommit`) and make them pass.
6. Commit the files you changed.
7. Push the current branch, setting the upstream if needed. Never force-push.
8. Report what you fixed (with commit SHAs) and what you left alone and why.
