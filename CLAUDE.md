# box

A zsh wrapper around apple/container that gives each project its own sandbox VM. Read DESIGN.md before changing any behaviour. It records every decision with its reason, plus the deferred list. When a decision changes, update the Decisions table or the Deferred list in the same commit.

## Invariants

These are the isolation model. Each one stays true after every change:

- **Plain containers only. `container machine` is prohibited** in any code, script, or docs example: it mounts `$HOME` read-write, forwards the ssh-agent, and adds all capabilities. Create every sandbox with `container create`. `test.zsh` fails if `box` or `_box` mention it.
- **Zero host mounts.** Project code lives on the `box-NAME` named volume at `/work`.
- **Secrets enter at exec time, by name.** Pass them as `container exec -e NAME`, which copies the value from the script's environment and skips unset names. Whatever goes into `container create -e` is saved to disk with the container. A `NAME=value` argument is visible to `ps`.
- **Secrets live in the Keychain.** Read them with `security`: values under `box/local/BOX/NAME` and `box/shared/NAME`, and which token a box gets as which env var under `box/grant/BOX/VAR`. A box gets only the tokens it was given; nothing from the host environment.
- **Deleting a box deletes its tokens.** Every removal goes through `delete()`, which also removes `box/local/BOX/*` and `box/grant/BOX/*`.
- **Zero host dependencies.** Use only macOS built-ins (zsh, `security`, `jq`, `column`) and the `container` CLI.
- **The unpushed-work guard is code.** `new` (on exit) and `rm` decide with `pushed()` and never prompt.

## Conventions

- **One script.** New behaviour goes into `box` as a subcommand in `main`. Every new subcommand or flag also goes into `_box` (completion), the README command table and `usage`.
- **Errors go through `die`.** The message says what to run next.
- **Values from `$(...)` that can fail are assigned on their own line.** For example `x=$(f) || exit 1`, or `|| die`. `local x=$(f)` and `export x=$(f)` hide the failure, so they're never used for these.
- **The script runs `main` only when executed.** It has to stay safe to `source`, because `test.zsh` sources it.

## Verify

- Run `zsh -n box && zsh -n _box && zsh test.zsh`.
- Add a case to `test.zsh` when you change a pure helper (`repo_of`, `randname`, `tok_var`, `tok_path`), and a `ceq` line when you change what `_box` completes.
- The main path is verified end to end on a Mac (2026-11-19). It runs `box new`, work, exit (box kept), `token add BOX gh:LABEL`, `run`, push, exit, then `rm` with no prompt. Keep it working, and re-run it by hand after changing any step of it.
- Anything that calls `container` can only be checked on a Mac with apple/container running. When you can't run it, say so in your summary and add the item under "Unverified" in DESIGN.md.
