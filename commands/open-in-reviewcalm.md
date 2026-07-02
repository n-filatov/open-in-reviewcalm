---
description: Open a GitHub PR in ReviewCalm
argument-hint: "<github-pr-url|owner/repo#N>"
---

Open the GitHub pull request specified by `$ARGUMENTS` in ReviewCalm.

Run this shell command:

```sh
open-reviewcalm $ARGUMENTS
```

Behavior:

- On a local machine with a browser/URL opener, this opens the `reviewcalm://` deep link.
- On a VPS/headless machine, it prints an `Open in ReviewCalm:` link. Show that link to the user so they can click/copy it on a machine with ReviewCalm installed.
- If that PR is already open in ReviewCalm, the app focuses the existing tab; otherwise it opens the PR.

If the command fails, report the exact error and suggest checking that:

1. ReviewCalm is installed on the machine where the link will be opened and has been launched once so `reviewcalm://` is registered.
2. `open-reviewcalm` is available on `PATH`.
3. The PR reference is one of: full GitHub PR URL, `owner/repo#number`, `owner/repo/pull/number`, `github.com/owner/repo/pull/number`, or `owner repo number`.
