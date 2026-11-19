# box design

A general-purpose sandbox suite for the Mac: every project lives in its own
apple/container VM, so no toolchain (Node etc.) is ever installed on the host.
`box run` opens bash with the box's tokens loaded; Claude Code comes preinstalled and
you start it from there with `--dangerously-skip-permissions` (or create a box with `box claude`). Work leaves the VM only through `git push`.

## Goals

- **Zero host software.** Only apple/container plus macOS built-ins (`zsh`, `security`, `jq`, `column`).
- **Isolation from the host.** Nothing on the host is mounted. Claude gets full permissions inside the VM.
- **One VM per project.** A new project is deleted when you leave it clean; once it holds unpushed work it is kept until deleted.

Not a goal (yet): stopping a misbehaving session from exfiltrating the secrets it holds. See Deferred.

## User flows

**Once per Mac**
1. `box build` builds `box:latest` from `Containerfile` and `claude-home/`, inside apple/container's builder VM.
2. `box claude login` runs `claude setup-token` in a throwaway container. You approve in the browser and paste the token; it goes into the Keychain as the shared token `claude` (`box/shared/claude`).
3. Optional: put this directory on `$PATH`, and on `$fpath` (before `compinit`) for completion.

**Per project**
- `box new [--name N]` creates an empty project (`git init`) with a three-word random name unless `--name` is given, then opens it with `box run`. On exit, if the work tree is clean and every commit is on a remote, the project is deleted (an untouched empty project counts as clean); otherwise it is kept and the resume and discard commands are printed. The check is in the script, and it never asks you anything.
- `box new --clone REPO [--clone-token T] [--name N]` clones a GitHub repo and opens it with `box run`, with the same exit check. The name defaults to `owner-repo`, and creation fails if that name is taken, in which case pass `--name`. For a private repo, `--clone-token T` names a shared token (asked for and stored if missing) that is passed to the clone only; the box does not keep it.
- `box claude [same options]` is `box new` that first requires the shared `claude` token (stops before creating anything if it is missing), gives the box that token, and starts `claude --dangerously-skip-permissions` instead of bash. The exit guard runs when Claude exits.
- REPO can be `owner/repo`, `https://github.com/owner/repo(.git)` or `git@github.com:owner/repo.git`. Inside the VM, git rewrites ssh GitHub URLs to https.

**Tokens**
- A box gets no tokens by default. `box token add BOX [--shared] [--env VAR] T` gives it one, asking for the value if it isn't stored yet; it takes effect at the next `box run` (a running shell can't receive new env vars).
- T is `prefix[:label]`. The prefix picks the env var: `gh` → `GH_TOKEN`, `claude` → `CLAUDE_CODE_OAUTH_TOKEN`. Other prefixes need `--env VAR` on every add, with no guarantee the tool reads it.
- Without `--shared` a token belongs to that box alone. With `--shared` it is stored once and can be given to any box. `token add --shared T` with no box only stores it (asking for the value, or saying it is already stored); it checks the name but not the prefix, since the env var belongs to each box's grant, so `--env` there is an error. One env var per box: a box-only token wins over a shared one, and otherwise a later add replaces the earlier one.
- `token rm BOX T` takes a token from a box (deleting it if box-only); `token rm --shared T` deletes a shared token and lists the boxes it was taken from. `token replace` enters a new value; `token ls [BOX]` lists names, never values.
- Pushing a new project: create the repo and a fine-grained token in the browser, `box token add NAME gh:LABEL`, then `git remote add` + `git push` inside the box (or ask Claude).

**Daily**
- `box run NAME` starts the VM if it is stopped and loads the box's tokens. If it has `GH_TOKEN` and a GitHub remote, it checks the token with `git ls-remote`; a rejection is a warning with the `token replace` command, and bash still opens. Then it opens bash in `/work/NAME` with the tokens and the git identity in the environment.
- `ls`, `stop NAME`, `rm [--force] NAME`. `rm` runs the same unpushed-work check unless `--force` is given, and deletes the box's own tokens and its links to shared ones.

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Backend | Plain `container create`, never `container machine` | Machines mount `$HOME` read-write, forward the ssh-agent and add every Linux capability (docs/container-machine.md) |
| Code location | Named volume `box-NAME` at `/work`, no host mounts | Full isolation; a rebuilt container keeps the work |
| Persistent mode | Container kept (stop/start) + volume | Tools installed with apt survive between sessions |
| New mode | `box new` opens `box run`, then on exit deletes the project only if clean and pushed (`pushed()`); no separate `fresh` command | Projects you only peek into do not pile up; work is never lost silently |
| Session | `box run` opens bash with the box's tokens loaded; Claude is started by hand, or by `box claude` for a new box; no separate `shell` command | One way in; the same environment for Claude and for anything else |
| Tokens | None by default; `box token add/rm/replace/ls`; box-only unless `--shared`; Keychain `box/local/BOX/T`, `box/shared/T`, and `box/grant/BOX/VAR` = `local:T` or `shared:T` | Least privilege per box; one mechanism for any tool instead of GitHub- and Claude-specific code |
| Token names | `prefix[:label]`; the prefix picks the env var (`gh`, `claude`); `--env` for anything else | You name the token, box knows the variable; `:` because POSIX command names never contain it, while `-` and `.` are common |
| Token priority | One env var per box; box-only beats shared; a later add replaces an earlier one | Predictable which token a tool sees |
| Claude auth | `box claude login`: `claude setup-token` → shared token `claude`; `box claude` gives it to the box it creates | Never stored on disk in plaintext; the box keeps it for later `run`s |
| GitHub auth | A fine-grained token per repo, given to the box as `gh:LABEL` → `GH_TOKEN`, read by a git credential helper over https (also `GITHUB_TOKEN`); ssh URLs rewritten to https | Limited to one repo; allows `gh` and PRs; no repo-creating token exists anywhere |
| Private clones | `--clone-token T`: a shared token passed to the clone only | A read token often spans many repos; the box running Claude never holds it |
| Pushing | No `push` command: give the box a token, then push from inside | Repo creation stays in the browser; inside the box git and `gh` work as usual |
| Cleanup | `delete()` (rm, exit guard, failed create or clone) removes the box's local tokens and grants | A reused box name never inherits an old token |
| Secret injection | `container exec -e NAME` (copies the value from the host environment) at session start, never `create -e` | The `create` config is saved to disk; the `exec` config is not saved by the server (ContainersService.createProcess). Values also stay out of argv |
| Git identity | Host `git config --global user.name/email` → `GIT_AUTHOR_*` and `GIT_COMMITTER_*` | Commits show as you; skipped when Xcode CLT is missing (avoids the installer pop-up) |
| Base image | `ubuntu:rolling` + git, gh, Node, build-essential, sudo, native Claude installer | Newest packages; Node in the VM is fine |
| Claude settings | `claude-home/` baked into the image at `~/.claude` | Same setup everywhere; rebuild after editing |
| Implementation | One zsh script + `_box` completion | Nothing to install or build |
| Names | Container and volume `box-NAME`; empty projects get `adj-animal-thing` | `ls` and completion find projects by the `box-` prefix |

## Deferred

- **General-purpose use beyond Claude.** `run` opens bash, so any program can be started by hand. Possible next steps:
  - `box run NAME -- CMD` to run one program directly with the same secrets and working directory (about 2 lines).
  - Other agents preinstalled.
  - Per-project images (a project's own Containerfile) for stacks that shouldn't share the base image.
  - More known token prefixes (registries, cloud CLIs) once each env var is checked against its tool; until then `--env`.
  - A one-step way to start Claude in an existing box (today: `box run NAME`, then `claude`).
  - `new`/`claude --token T` to give a box tokens at creation (today: exit, `box token add`, `box run`).
- **Dev-server preview.** No ports are published. Options: a fixed `-p` range at create time, or browsing to the container IP.
- **Egress allowlist.** Network access is fully open. Only egress control (a proxy, or vmnet rules) would stop a session from leaking `CLAUDE_CODE_OAUTH_TOKEN` or `GH_TOKEN`.
- **CPU and memory limits.** Not set yet; `-c` and `-m` exist on `container create`.
- **Updating existing projects after `build`.** Persistent containers keep their old rootfs, and with `ubuntu:rolling` they stay on the previous release. A possible `box rebuild NAME` would recreate the container on the same volume.
- **Concurrent sessions** on one project. Not prevented.
- **Pasting images or the clipboard** into Claude inside the VM.
- **`ls` details** (remote, unpushed state). Showing them means exec'ing into every container.

## Unverified

Run on a Mac with apple/container: `new` (empty project), `run`, restarting a stopped project, `ls`, `rm`, the exit guard after `new`, `new --clone` of a public repo with `--clone-token`, every `token` verb and error path with dummy values, the Keychain cleanup in `rm`, the ssh-to-https rewrite, and that a host `GH_TOKEN` doesn't reach a box. The rest:

- Pushing with a real fine-grained token, and `--clone-token` with a real token on a private repo.
- The hidden value prompt in `token add`/`replace` (`security add-generic-password -w`), typed by hand; automated input can't reach it.
- `box claude` and `box claude login` end to end: whether `claude` is signed in through `CLAUDE_CODE_OAUTH_TOKEN`, and whether its onboarding prompts appear in every new container.
- Tab completion in `_box` (only `zsh -n` has been run).
