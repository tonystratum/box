# box

Isolated Linux sandboxes on your Mac, built on [apple/container](https://github.com/apple/container).
Each project gets its own lightweight VM. Nothing is installed on or mounted from the host, and secrets stay in the macOS Keychain.
Claude Code comes preinstalled and runs with `--dangerously-skip-permissions`, inside the VM only.

> **Status:** early. Creating, entering and removing projects, cloning public and private repos, managing tokens and tab completion are tested on a Mac; pushing with a real token and Claude signing in inside a box are not yet. See [DESIGN.md](DESIGN.md) for decisions and open questions.

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

Completion covers every argument: boxes, a box's tokens, shared tokens and the `gh:`/`claude:` prefixes. It shows token names only, never values.

## Quick start

**Once per Mac**

```sh
box build          # build the sandbox image (Ubuntu, git, gh, Node, Claude Code)
box claude login   # approve in the browser; the Claude token goes into the Keychain as shared token "claude"
```

**Per project**

```sh
box claude                         # new empty project with a random name (e.g. brisk-otter-lamp), Claude started
box new --clone apple/container    # clone a public repo, then bash
box new --clone bob/private --clone-token gh:read   # private repo: shared token used for the clone only
```

**A read token for private clones.** At <https://github.com/settings/personal-access-tokens/new> make a fine-grained token: Repository access *All repositories* (or the ones you pick), then under Repositories **+ Add permissions** → *Contents: Read-only* (GitHub adds *Metadata: Read-only*). Store it once:

```sh
box token add --shared gh:read   # paste the token; or let the first --clone-token gh:read ask for it
```

It is passed to the clone only. With *All repositories* it can read every private repo you own, so don't give it to boxes.

Tokens can be given at creation, too: `box claude --clone bob/app --clone-token gh:read --token gh:app`.

**Pushing to GitHub.** Create the repo and a fine-grained token for it in the browser, then give the box the token:

```sh
box token add brisk-otter-lamp gh:lamp   # asks for the token; the box gets it as GH_TOKEN at the next run
box run brisk-otter-lamp                 # inside: git remote add origin …, git push (or ask Claude to)
```

**Daily**

```sh
box run apple-container                 # bash inside the VM with the box's tokens loaded
claude --dangerously-skip-permissions   # then, inside: Claude with full permissions, VM only
box stop apple-container                # leaving bash keeps the VM running; this frees its CPU and memory
```

`stop` keeps everything on disk: files in `/work` (committed or not), installed tools and tokens. Only running processes end. `box run` starts it again.

## Commands

| Command | What it does |
|---|---|
| `build` | Build `box:latest` from `Containerfile` and `claude-home/` |
| `new [--name N]` | Empty project (`git init`), then `run`; deleted on exit unless work is uncommitted or unpushed |
| `new --clone REPO [--clone-token T] [--name N]` | Same, cloning a GitHub repo; the name defaults to `owner-repo`; `T` is a shared token used for the clone only |
| `new … --token T --shared-token T` | Give the new box tokens at creation (repeatable): `--token` is box-only and asks for the value, `--shared-token` uses a shared one; `gh` and `claude` prefixes only. All values are asked for before anything is created |
| `claude [same options as new]` | Same as `new`, but gives the box the shared `claude` token and starts Claude instead of bash |
| `claude login` | Store the shared Claude token |
| `run NAME` | bash inside the project (starts a stopped VM) with the box's tokens and your git identity loaded |
| `token add BOX [--shared] [--env VAR] T` | Give a box a token; asks for the value if it isn't stored; takes effect at the next `run` |
| `token add --shared T` | Store a shared token without giving it to a box (e.g. a read token for `--clone-token`) |
| `token rm BOX T`, `token rm --shared T` | Take a token from a box; delete a shared token and take it from every box |
| `token replace BOX T`, `token replace --shared T` | Enter a new value (e.g. an expired token) |
| `token ls [BOX]` | A box's tokens; without BOX, the shared tokens and the boxes that have them |
| `ls`, `stop NAME`, `rm [--force] NAME` | Housekeeping; `stop` keeps files and tools; `rm` refuses to delete unpushed work, and also deletes the box's own tokens |

`REPO` can be `owner/repo`, `https://github.com/owner/repo`, or `git@github.com:owner/repo.git`.

**Tokens.** A box gets no tokens unless you give it some. A token name is `prefix[:label]`, for example `gh:lamp`; the prefix picks the env var the tool reads:

| Prefix | Env var | Read by |
|---|---|---|
| `gh` | `GH_TOKEN` | `gh`, and `git` over https |
| `claude` | `CLAUDE_CODE_OAUTH_TOKEN` | `claude` |

Any other prefix needs `--env VAR`, with no guarantee the tool reads it. A token belongs to one box unless you pass `--shared`. If a box has a box-only and a shared token for the same env var, the box-only one wins.

## How it isolates

- **Plain containers, not `container machine`.** A container machine mounts your home directory and forwards your ssh-agent, so `box` doesn't use it.
- **Code lives on a named volume inside the VM.** Work leaves only through `git push`.
- **Secrets come from the Keychain** and are passed with `container exec -e` when a session starts, so they are never written into the container's config on disk.
- **A box holds only the tokens you gave it.** Tokens set in your Mac's shell never reach a box. For GitHub, a fine-grained token limited to one repo keeps a leak to that repo.

**Network access is open.** A session can still leak the tokens it holds. An egress allowlist is on the [deferred list](DESIGN.md#deferred).

## Customizing

Put your own `CLAUDE.md` and `settings.json` in `claude-home/`, then run `box build` again. The image is defined in `Containerfile`.

## License

[MIT](LICENSE)
