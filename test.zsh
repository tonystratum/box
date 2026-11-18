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

# Guardrail: container machine breaks isolation (see CLAUDE.md).
! grep -n 'container machine' ${0:A:h}/box ${0:A:h}/_box || { print 'FAIL: container machine is prohibited'; fail=1 }

(( fail )) || print ok
exit $fail
