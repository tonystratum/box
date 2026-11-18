# box design

A general-purpose sandbox suite for the Mac: every project lives in its own
apple/container VM, so no toolchain (Node etc.) is ever installed on the host.
Claude Code comes preinstalled and is the default thing `box run` starts, with
`--dangerously-skip-permissions`. Work leaves the VM only through `git push`.

## Goals

- **Zero host software.** Only apple/container plus macOS built-ins (`zsh`, `security`, `jq`, `column`).
- **Isolation from the host.** Nothing on the host is mounted. Claude gets full permissions inside the VM.
- **One VM per project.** Each project is kept until deleted; `fresh` gives a throwaway one.

Not a goal (yet): stopping a misbehaving session from exfiltrating the secrets it holds. See Deferred.

## User flows

**Once per Mac**
1. `box build` builds `box:latest` from `Containerfile` and `claude-home/`, inside apple/container's builder VM.
2. `box login` runs `claude setup-token` in a throwaway container. You approve in the browser and paste the token; it goes into the Keychain as `box/claude`.
3. Optional: put this directory on `$PATH`, and on `$fpath` (before `compinit`) for completion.

**Per project**
- `box new [--name N]` creates an empty project (`git init`) with a three-word random name unless `--name` is given.
- `box new --clone REPO [--name N]` clones a GitHub repo. The name defaults to `owner-repo`, and creation fails if that name is taken, in which case pass `--name`. If no PAT for that repo is in the Keychain, it prints the token-creation link and asks you to paste one.
- `box push NAME REPO` connects an empty project to a GitHub repo you created (empty) and pushes. The first push is the check that the repo exists and the token can write to it.
- REPO can be `owner/repo`, `https://github.com/owner/repo(.git)` or `git@github.com:owner/repo.git`. The remote is always stored as https.

**Daily**
- `box run NAME` starts the VM and checks the PAT. If the token is rejected, it says to run `box token NAME`. Then it starts `claude --dangerously-skip-permissions` in `/work/NAME`.
- `box fresh REPO` clones into a throwaway VM. On exit, if the work tree is clean and every commit is on the remote, the VM is deleted; otherwise it is kept and the resume and discard commands are printed. The check is in the script, and it never asks you anything.
- `shell NAME`, `ls`, `stop NAME`, `rm [--force] NAME`. `rm` runs the same unpushed-work check unless `--force` is given.

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Backend | Plain `container create`, never `container machine` | Machines mount `$HOME` read-write, forward the ssh-agent and add every Linux capability (docs/container-machine.md) |
| Code location | Named volume `box-NAME` at `/work`, no host mounts | Full isolation; a rebuilt container keeps the work |
| Persistent mode | Container kept (stop/start) + volume | Tools installed with apt survive between sessions |
| Fresh mode | Container without a volume, deleted only if clean and pushed | Disposable, but work is never lost silently |
| Claude auth | `claude setup-token` → Keychain `box/claude` | Never stored on disk in plaintext |
| GitHub auth | Fine-grained PAT per repo → Keychain `box/github/OWNER/REPO`, used by a git credential helper over https | Limited to one repo; allows `gh` and PRs; `fresh` reuses the same token |
| Secret injection | `container exec -e NAME` (copies the value from the host environment) at session start, never `create -e` | The `create` config is saved to disk; the `exec` config is not saved by the server (ContainersService.createProcess). Values also stay out of argv |
| Git identity | Host `git config --global user.name/email` → `GIT_AUTHOR_*` and `GIT_COMMITTER_*` | Commits show as you; skipped when Xcode CLT is missing (avoids the installer pop-up) |
| Base image | `ubuntu:rolling` + git, gh, Node, build-essential, sudo, native Claude installer | Newest packages; Node in the VM is fine |
| Claude settings | `claude-home/` baked into the image at `~/.claude` | Same setup everywhere; rebuild after editing |
| Implementation | One zsh script + `_box` completion | Nothing to install or build |
| Names | Container and volume `box-NAME`; empty projects get `adj-animal-thing` | `ls` and completion find projects by the `box-` prefix |

## Deferred

- **General-purpose use beyond Claude.** v1 is a rename only: `run` always starts Claude, and `shell` is the way to do anything else. Possible next steps:
  - `box run NAME -- CMD` to run any program with the same secrets and working directory (about 2 lines).
  - A configurable default command, or other agents preinstalled.
  - Per-project images (a project's own Containerfile) for stacks that shouldn't share the base image.
  - Credentials that aren't GitHub or Claude (registries, cloud CLIs), using the same Keychain + `exec -e` pattern.
- **Dev-server preview.** No ports are published. Options: a fixed `-p` range at create time, or browsing to the container IP.
- **Egress allowlist.** Network access is fully open. Only egress control (a proxy, or vmnet rules) would stop a session from leaking `CLAUDE_CODE_OAUTH_TOKEN` or `GH_TOKEN`.
- **CPU and memory limits.** Not set yet; `-c` and `-m` exist on `container create`.
- **Updating existing projects after `build`.** Persistent containers keep their old rootfs, and with `ubuntu:rolling` they stay on the previous release. A possible `box rebuild NAME` would recreate the container on the same volume.
- **Concurrent sessions** on one project. Not prevented.
- **Pasting images or the clipboard** into Claude inside the VM.
- **`ls` details** (remote, unpushed state). Showing them means exec'ing into every container.

## Unverified (written on Linux, check on first run on the Mac)

- The whole flow against a real apple/container install. Only `zsh -n` and `test.zsh` (URL parsing, random names) have been run.
- Whether Claude Code's first-run onboarding prompts appear in every new container, even with `CLAUDE_CODE_OAUTH_TOKEN` set.
- Whether `/usr/bin/jq` is present (it ships with macOS 15 and later).
