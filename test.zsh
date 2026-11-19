#!/bin/zsh
# Self-check for the pure helpers (no container needed): zsh test.zsh
source ${0:A:h}/box
fail=0
eq() { [[ $1 == $2 ]] || { print "FAIL: got '$1' want '$2'"; fail=1 } }

for u in apple/container https://github.com/apple/container https://github.com/apple/container.git \
         https://github.com/apple/container/ git@github.com:apple/container.git github.com/apple/container; do
  eq "$(repo_of $u)" apple/container
done
eq "$( (repo_of https://gitlab.com/a/b) 2>&1)" "error: not a GitHub repo: https://gitlab.com/a/b"
eq "$( (repo_of apple) 2>&1)" "error: not a GitHub repo: apple"
[[ $(randname) == [a-z]##-[a-z]##-[a-z]## ]] || { print "FAIL: randname $(randname)"; fail=1 }

# Token names: prefix[:label] picks the env var; --env overrides; ':' is the only separator.
eq "$(tok_var gh)" GH_TOKEN
eq "$(tok_var gh:read)" GH_TOKEN
eq "$(tok_var gh:my-repo.v2)" GH_TOKEN
eq "$(tok_var claude:work)" CLAUDE_CODE_OAUTH_TOKEN
eq "$(tok_var npm:ci NPM_TOKEN)" NPM_TOKEN
eq "$(tok_var docker-compose:ci DC_TOKEN)" DC_TOKEN
eq "$( (tok_var npm:ci) 2>&1)" "error: unknown prefix 'npm': known: gh, claude; or pass --env VAR (not guaranteed to work)"
eq "$( (tok_var gh-read) 2>&1)" "error: unknown prefix 'gh-read': known: gh, claude; or pass --env VAR (not guaranteed to work)"
for bad in GH:read gh: gh:a:b :read 'gh read' gh/read; do
  eq "$( (tok_var $bad) 2>&1)" "error: bad token name '$bad' (prefix[:label], lowercase letters, digits, _ . -)"
done
eq "$( (tok_var npm:ci npm_token) 2>&1)" "error: bad env var 'npm_token'"
eq "$( (tok_name npm:ci) 2>&1)" ""  # storing a shared token checks the name, not the prefix
eq "$( (tok_name gh:a:b) 2>&1)" "error: bad token name 'gh:a:b' (prefix[:label], lowercase letters, digits, _ . -)"
eq "$(tok_path box-1 local:gh:push)" local/box-1/gh:push
eq "$(tok_path box-1 shared:gh:read)" shared/gh:read

# Guardrail: container machine breaks isolation (see CLAUDE.md).
! grep -n 'container machine' ${0:A:h}/box ${0:A:h}/_box || { print 'FAIL: container machine is prohibited'; fail=1 }

(( fail )) || print ok
exit $fail
