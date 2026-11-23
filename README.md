# box

```sh
box new                                    # an empty project in its own VM, named three-random-words; bash opens inside
# ...work: write code, install tools, commit...
exit                                       # unpushed work, so the box is kept and the command to resume it is printed
# in the browser: create the repo and a fine-grained token limited to it
box token add three-random-words gh:push   # paste the token; the box gets it as GH_TOKEN at the next run
box run three-random-words                 # back in, token loaded
# commit, push etc...
exit
box stop three-random-words                # frees CPU and memory; files, tools and tokens stay
```

> A clean box is deleted when you leave it. Run `box build` once per Mac first; see [Install](#install).

## Tokens

A token is a credential a box can use, such as a GitHub token for `git push`. A box gets none unless you give it one.

```sh
# look
box token ls                                                # the shared tokens and the boxes that have them
box token ls three-random-words                             # one box's tokens (names only, never values)

# give a box a token: name it prefix[:label]; the prefix picks the env var
box token add three-random-words gh:push                    # asks for the value if not stored yet; the box gets it as GH_TOKEN (claude: CLAUDE_CODE_OAUTH_TOKEN)
box token add three-random-words --shared gh:read           # --shared: stored once, any box can be given it; without it the token belongs to that box alone
box token add three-random-words --env NPM_TOKEN npm:work   # any other prefix needs --env VAR
box token add --shared gh:read                              # no box: only store a shared token, e.g. a read token for --clone-token
# a new token takes effect at the box's next `box run`

# change
box token replace three-random-words gh:push                # enter a new value, e.g. after expiry
box token rm three-random-words gh:push                     # take it from the box (a box-only token is deleted)
box token rm --shared gh:read                               # delete a shared token and take it from every box
```

Tokens live in the macOS Keychain and are passed in when a session starts, never written into the container's config on disk. Limit a GitHub token to one repo: network access is open, so a session can leak the tokens it holds.

## Claude Code

Claude Code is preinstalled in every box.

```sh
box claude login   # once per Mac: approve in the browser; the token goes into the Keychain as the shared token "claude"
box claude         # like box new, but starts Claude with full permissions (inside the VM only)
```

## Commands

- **`box build`**: build the sandbox image from `Containerfile` and `claude-home/`
- **`box new [--name N] [--clone REPO [--clone-token T]] [--token T]... [--shared-token T]...`**: new project, empty or a clone, then bash; deleted on exit unless work is unpushed. `--clone-token` is a shared token used for the clone only; `--token` is box-only and asks for the value; `--shared-token` uses a shared one
- **`box claude [same options as new]`**: like `new`, but gives the box the shared `claude` token and starts Claude. `box claude login` stores that token
- **`box run NAME`**: bash in the project (starts a stopped VM) with its tokens loaded
- **`box ls`**, **`box stop NAME`**: list boxes; stop one, keeping files, tools and tokens
- **`box token add BOX [--shared] [--env VAR] T`**: give BOX a token (asks for the value if not stored), effective at the next `run`; `box token add --shared T` only stores it
- **`box token rm BOX T`**, **`box token rm --shared T`**: take a token from a box; delete a shared one and take it from every box
- **`box token replace BOX T`**, **`box token replace --shared T`**: enter a new value
- **`box token ls [BOX]`**: a box's tokens, or the shared ones and who has them
- **`box rm [--force] NAME`**: delete the box, its files and its own tokens; refuses unpushed work without `--force`

`REPO` is `owner/repo`, `https://github.com/owner/repo` or `git@github.com:owner/repo.git`.

## Install

You need a Mac with Apple silicon on macOS 26 or later, and [apple/container](https://github.com/apple/container/releases) started with `container system start`. Nothing else: `box` uses only zsh, `security` and `jq`, all built into macOS.

```sh
git clone https://github.com/tonystratum/box ~/box
# ~/.zshrc
path=(~/box $path)
fpath=(~/box $fpath)   # tab completion; must come before compinit
```

```sh
box build   # once per Mac: the sandbox image (Ubuntu, git, gh, Node, tmux, vim, Claude Code)
```

Completion covers every argument: boxes, a box's tokens, shared tokens and the `gh:`/`claude:` prefixes. It shows token names only, never values.

## How it isolates

- **Plain containers, not `container machine`.** A container machine mounts your home directory and forwards your ssh-agent, so `box` doesn't use it.
- **Code lives on a named volume inside the VM.** Work leaves only through `git push`.
- **Secrets come from the Keychain** and are passed with `container exec -e` when a session starts, so they are never written into the container's config on disk.
- **A box holds only the tokens you gave it.** Tokens set in your Mac's shell never reach a box. For GitHub, a fine-grained token limited to one repo keeps a leak to that repo.

**Network access is open.** A session can still leak the tokens it holds. An egress allowlist is on the [deferred list](DESIGN.md#deferred).

> **Status:** early. The full flow is tested on a Mac: creating, entering and removing projects, cloning public and private repos, tokens, Claude signed in inside a box, pushing, and tab completion. See [DESIGN.md](DESIGN.md) for decisions and open questions.

## Customizing

Put your own `CLAUDE.md` and `settings.json` in `claude-home/`, then run `box build` again. The image is defined in `Containerfile`.

## License

[MIT](LICENSE)
