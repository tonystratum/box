# box

A zsh wrapper around apple/container that gives each project its own sandbox VM. Read DESIGN.md before changing any behaviour. It records every decision with its reason, plus the deferred list. When a decision changes, update the Decisions table or the Deferred list in the same commit.

## Invariants

These are the isolation model. Each one stays true after every change:

- **Plain containers only.** Create sandboxes with `container create`. `container machine` mounts `$HOME` and forwards the ssh-agent, which breaks isolation.
- **Zero host mounts.** Project code lives on the `box-NAME` named volume at `/work`.
- **Secrets enter at exec time, by name.** Pass them as `container exec -e NAME`, which copies the value from the script's environment and skips unset names. Whatever goes into `container create -e` is saved to disk with the container. A `NAME=value` argument is visible to `ps`.
- **Secrets live in the Keychain.** Read them with `security`, under `box/claude` and `box/github/OWNER/REPO`.
- **Zero host dependencies.** Use only macOS built-ins (zsh, `security`, `jq`, `column`) and the `container` CLI.
- **The unpushed-work guard is code.** `fresh` and `rm` decide with `pushed()` and never prompt.

## Conventions

- **One script.** New behaviour goes into `box` as a subcommand in `main`. Every new subcommand or flag also goes into `_box` (completion), the README command table and `usage`.
- **Errors go through `die`.** The message says what to run next.
- **Values from `$(...)` that can fail are assigned on their own line.** For example `x=$(f) || exit 1`, or `|| die`. `local x=$(f)` and `export x=$(f)` hide the failure, so they're never used for these.
- **The script runs `main` only when executed.** It has to stay safe to `source`, because `test.zsh` sources it.

## Verify

- Run `zsh -n box && zsh -n _box && zsh test.zsh`.
- Add a case to `test.zsh` when you change a pure helper (`repo_of`, `randname`).
- Anything that calls `container` can only be checked on a Mac with apple/container running. When you can't run it, say so in your summary and add the item under "Unverified" in DESIGN.md.
