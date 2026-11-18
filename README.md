# box

Isolated Linux sandboxes on your Mac, built on [apple/container](https://github.com/apple/container).
Each project gets its own lightweight VM. Nothing is installed on or mounted from the host, and secrets stay in the macOS Keychain.
Claude Code comes preinstalled and runs with `--dangerously-skip-permissions`, inside the VM only.

> **Status:** early and not yet tested end to end on a Mac. See [DESIGN.md](DESIGN.md) for decisions and open questions.

## Requirements

- A Mac with Apple silicon, running macOS 26 or later
- [apple/container](https://github.com/apple/container/releases), installed and started with `container system start`
- Nothing else: `box` uses only zsh, `security` and `jq`, all built into macOS

## Install

```sh
git clone https://github.com/tonystratum/box ~/box
# ~/.zshrc
path=(~/box $path)
fpath=(~/box $fpath)   # tab completion; must come before compinit
```

## Quick start

**Once per Mac**

```sh
box build    # build the sandbox image (Ubuntu, git, gh, Node, Claude Code)
box login    # approve in the browser; the Claude token goes into the Keychain
```

**Per project**

```sh
box new --clone apple/container    # clone; asks for a fine-grained PAT for that repo once
box new                            # empty project with a random name, e.g. brisk-otter-lamp
box push brisk-otter-lamp bob/lamp # connect an empty project to a new (empty) GitHub repo
```

**Daily**

```sh
box run apple-container            # Claude, full permissions, inside the VM
box fresh apple/container          # throwaway VM: deleted on exit unless work is unpushed
```

## Commands

| Command | What it does |
|---|---|
| `build` | Build `box:latest` from `Containerfile` and `claude-home/` |
| `login` | Store a Claude token in the Keychain |
| `new [--name N]` | Empty project (`git init`), then bash inside it |
| `new --clone REPO [--name N]` | Clone a GitHub repo, then bash inside it; the name defaults to `owner-repo` |
| `run NAME` | Start Claude in a project |
| `fresh REPO` | Throwaway session; kept only if work is uncommitted or unpushed |
| `push NAME REPO` | Set the GitHub remote and do the first push |
| `token NAME` | Replace an expired GitHub token |
| `shell NAME` | bash inside the project |
| `ls`, `stop NAME`, `rm [--force] NAME` | Housekeeping; `rm` refuses to delete unpushed work |

`REPO` can be `owner/repo`, `https://github.com/owner/repo`, or `git@github.com:owner/repo.git`.

## How it isolates

- **Plain containers, not `container machine`.** A container machine mounts your home directory and forwards your ssh-agent, so `box` doesn't use it.
- **Code lives on a named volume inside the VM.** Work leaves only through `git push`.
- **Secrets come from the Keychain** and are passed with `container exec -e` when a session starts, so they are never written into the container's config on disk.
- **GitHub access is a fine-grained PAT** limited to one repo.

**Network access is open.** A session can still leak the tokens it holds. An egress allowlist is on the [deferred list](DESIGN.md#deferred).

## Customizing

Put your own `CLAUDE.md` and `settings.json` in `claude-home/`, then run `box build` again. The image is defined in `Containerfile`.

## License

[MIT](LICENSE)
