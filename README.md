# open-in-reviewcalm

A [pi](https://github.com/earendil-works/pi-coding-agent) skill that opens a
GitHub pull request in the **ReviewCalm** desktop app from the terminal — the
entry point an agent calls when the user says *"open this PR in ReviewCalm"*.

> **ReviewCalm** is a private macOS desktop app for reviewing GitHub PRs with
> less cognitive load. This skill ships standalone and **public** so any agent
> or user can install and invoke it; it does not contain any ReviewCalm source.

## What it does

Given a GitHub PR reference, it:

1. Normalizes it to a canonical
   `https://github.com/<lowercased-owner>/<lowercased-repo>/pull/<number>` URL
   (owner/repo are case-insensitive on GitHub; lower-casing guarantees the same
   PR always maps to the same ReviewCalm tab id — this is what makes "focus the
   existing tab" reliable).
2. Validates it (GitHub host, `/pull/<positive integer>`).
3. Delegates to the `reviewcalm` CLI, which builds a
   `reviewcalm://open?url=<encoded>` deep link and hands it to macOS `open`.
   ReviewCalm's deep-link scheme launches the app if it isn't running and
   re-focuses the existing tab if that PR is already open (de-duped by tab id).

### Accepted PR reference forms

```sh
./scripts/open-reviewcalm.sh https://github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner/repo#123
./scripts/open-reviewcalm.sh owner/repo/pull/123
./scripts/open-reviewcalm.sh github.com/owner/repo/pull/123
./scripts/open-reviewcalm.sh owner repo 123
```

`--validate-only` prints the normalized URL + deep link without opening:

```sh
./scripts/open-reviewcalm.sh --validate-only https://github.com/Foo/Bar/pull/7/files
# url=https://github.com/foo/bar/pull/7
# deep_link=reviewcalm://open?url=https%3A%2F%2Fgithub.com%2Ffoo%2Fbar%2Fpull%2F7
```

## Prerequisites (one-time)

1. Install ReviewCalm and launch it once so the `reviewcalm://` URL scheme
   registers with LaunchServices.
2. Put the `reviewcalm` CLI on your PATH (it ships inside a ReviewCalm source /
   release checkout at `reviewcalm/scripts/reviewcalm`):

   ```sh
   ln -sf /path/to/reviewcalm/scripts/reviewcalm /usr/local/bin/reviewcalm
   # or:  ln -sf /path/to/reviewcalm/scripts/reviewcalm ~/.local/bin/reviewcalm
   # or:  export REVIEWCALM_CLI=/path/to/reviewcalm/scripts/reviewcalm
   ```

## Install (as a pi skill)

The repo root **is** the skill directory (it contains `SKILL.md`). Clone it
anywhere and symlink into a pi skills location:

```sh
git clone https://github.com/n-filatov/open-in-reviewcalm.git
ln -sf "$(pwd)/open-in-reviewcalm" ~/.pi/agent/skills/open-in-reviewcalm
# or, per-project: .pi/skills/open-in-reviewcalm
```

Pi loads skills from `~/.pi/agent/skills/`, `~/.agents/skills/`, project
`.pi/skills/` (after trust), and the `skills` setting.

## Run the self-test

```sh
./scripts/test-open-reviewcalm.sh   # exits 0 if all normalization/validation cases pass
```

The self-test uses `--validate-only`, so it runs anywhere without the ReviewCalm
app or `reviewcalm://` scheme being installed.

## Layout

```
open-in-reviewcalm/
├── SKILL.md                      # pi skill frontmatter + instructions (this dir IS the skill)
├── README.md                     # this file
└── scripts/
    ├── open-reviewcalm.sh        # normalize + validate + delegate to `reviewcalm` CLI
    └── test-open-reviewcalm.sh   # self-test
```

## License

MIT. See [LICENSE](LICENSE).