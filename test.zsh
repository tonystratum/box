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

# Completion (_box): type a line + Tab into a real interactive zsh in a pty (zsh/zpty ships with zsh).
# container and security are stubbed: boxes t1 (running), t2 (stopped); t1 has box-only gh:own and shared claude,
# t2 has shared npm:ci as NPM_TOKEN; shared gh:read is on no box. compinit -D writes no ~/.zcompdump.
zmodload zsh/zpty zsh/zselect zsh/datetime
export BOX_TEST_INIT='
PS1= PROMPT= RPROMPT=
fpath=('${0:A:h}' $fpath); autoload -Uz compinit; compinit -u -D
container() { [[ $1 == ls ]] && print -r -- '"'"'[{"configuration":{"id":"box-t1"},"status":{"state":"running"}},{"configuration":{"id":"box-t2"},"status":{"state":"stopped"}},{"configuration":{"id":"other"},"status":{"state":"running"}}]'"'"' }
typeset -gA KC=(box/local/t1/gh:own v box/shared/gh:read v box/shared/claude v box/shared/npm:ci v
  box/grant/t1/GH_TOKEN local:gh:own box/grant/t1/CLAUDE_CODE_OAUTH_TOKEN shared:claude box/grant/t2/NPM_TOKEN shared:npm:ci)
security() { local k; case $1 in
  dump-keychain) for k in ${(k)KC}; do print -r -- "    \"svce\"<blob>=\"$k\""; done ;;
  find-generic-password) k=${@[${@[(i)-s]}+1]}; (( ${+KC[$k]} )) || return 44; print -r -- $KC[$k] ;;
esac }
compadd() {  # print each match instead of adding it; filtering calls (-O -A -D) pass through
  if [[ ${@[1,(i)(-|--)]} == *-(O|A|D)\ * ]]; then builtin compadd "$@"; return; fi
  local -a h; builtin compadd -A h "$@"; (( $#h )) || return 1
  local x; for x in $h; do print -rn -- $'"'"'\nHIT:'"'"'$x; done; return 0
}
zle -C box-comp complete-word _main_complete
box-tab() { zle box-comp; print -rn -- $'"'"'\nCOMP'"'"'END }  # marker: completion has finished
zle -N box-tab; bindkey "^I" box-tab
'
pty_until() {  # read pty output into $out until it contains $1 (10s limit)
  local chunk t0=$EPOCHREALTIME; out=
  while [[ $out != *$1* ]] && (( EPOCHREALTIME - t0 < 10 )); do zpty -r -t comp chunk && out+=$chunk || zselect -t 2 || :; done
}
ceq() {  # line, expected matches (sorted, space-separated)
  local cr=$'\r'; local -a hits
  zpty -w -n comp "$1"$'\t'; pty_until COMPEND
  hits=(${(o)${(u)${${(M)${(f)out}:#HIT:*}#HIT:}%$cr}})
  zpty -w -n comp $'\C-u'
  eq "complete '$1': ${(j: :)hits}" "complete '$1': $2"
}
zpty comp zsh -f -i
zpty -w comp 'eval "$BOX_TEST_INIT"; print IN''IT-OK'; pty_until $'\n'INIT-OK
ceq 'box '                              'build claude ls new rm run stop token'
ceq 'box run '                          't1 t2'
ceq 'box stop '                         't1'
ceq 'box rm '                           't1 t2'
ceq 'box rm -'                          '--force'
ceq 'box new '                          '--clone --name --shared-token --token'
ceq 'box claude '                       'login'
ceq 'box claude -'                      '--clone --name --shared-token --token'
ceq 'box claude login '                 ''
ceq 'box new --clone x '                '--clone-token --name --shared-token --token'
ceq 'box new --token '                  'claude: gh:'
ceq 'box new --shared-token '           'claude gh:read npm:ci'
ceq 'box new --token gh:a -'            '--clone --name --shared-token --token'
ceq 'box new --clone x --clone-token '  'gh:read'
ceq 'box token '                        'add ls replace rm'
ceq 'box token add '                    't1 t2'
ceq 'box token add -'                   '--env --shared'
ceq 'box token add t1 '                 'claude: gh:'
ceq 'box token add --shared '           'claude claude: gh: gh:read npm:ci t1 t2'
ceq 'box token add --shared t1 '        'claude: gh: gh:read npm:ci'
ceq 'box token add t1 --env '           'CLAUDE_CODE_OAUTH_TOKEN GH_TOKEN NPM_TOKEN'
ceq 'box token rm '                     't1 t2'
ceq 'box token rm t1 '                  'claude gh:own'
ceq 'box token replace t1 '             'gh:own'
ceq 'box token rm --shared '            'claude gh:read npm:ci'
ceq 'box token replace --shared '       'claude gh:read npm:ci'
ceq 'box token ls '                     't1 t2'
zpty -d comp

# Guardrail: container machine breaks isolation (see CLAUDE.md).
! grep -n 'container machine' ${0:A:h}/box ${0:A:h}/_box || { print 'FAIL: container machine is prohibited'; fail=1 }

(( fail )) || print ok
exit $fail
