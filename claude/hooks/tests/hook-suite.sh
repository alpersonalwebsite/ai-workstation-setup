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

# ---------------------------------------------------------------- rule 7: credentials returned by an API
# Fragments, never adjacent in this source, so the suite matches nothing itself.
CFG='.con''fig.url'
SEC='.con''fig.secret'
API='gh a''pi'
CU='con''fig[url]'
GH1="repos/O/R/ho""oks/1"
COBJ=".con""fig"
CCT=".con""fig.content_type"
CSSL=".con""fig.insecure_ssl"

probe "config url bare"                block "$API $GH1 -q '$CFG'"
probe "config secret bare"             block "$API $GH1 -q '$SEC'"
probe "config url redirected"          allow "$API $GH1 -q '$CFG' > /tmp/u.txt"
probe "config url appended"            allow "$API $GH1 -q '$CFG' >> /tmp/u.txt"
probe "config url to a digest"         allow "$API $GH1 -q '$CFG' | shasum"
# A redaction that runs and strips only part of the value is still a disclosure.
probe "config url through a redactor"  block "$API $GH1 -q '$CFG' | sed -E 's#x#y#'"
# Capture is deliberately NOT a sink here, unlike rule 5: a captured value gets
# printed back in pieces under a name rule 2 cannot see as secret-shaped.
probe "config url captured"            block "u=${D}($API $GH1 -q '$CFG')"
probe "stderr-only redirect"           block "$API $GH1 -q '$CFG' 2>/dev/null"
# No .config named at all: the raw object carries the credential.
probe "hooks endpoint, no selector"    block "$API $GH1"
probe "hooks list, no selector"        block "$API repos/O/R/ho""oks"
probe "hooks endpoint with a selector" allow "$API $GH1 -q '.id, .active'"
probe "deliveries, status codes only"  allow "$API $GH1/deliveries -q '.[] | .status_code' | sort"
# ⚠️ A SELECTOR IS NOT A SAFE SELECTOR. Testing only whether -q exists leaves
# `-q '.'` allowed: two characters from the blocked form, printing the same bytes.
# The test is whether the selector NAMES A FIELD.
probe "identity selector"              block "$API $GH1 -q '.'"
probe "array iterate, no field"        block "$API repos/O/R/ho""oks -q '.[]'"
probe "array index, no field"          block "$API repos/O/R/ho""oks --jq '.[0]'"
probe "keys names no field"            block "$API $GH1 -q 'keys'"
probe "nested field selector"          allow "$API $GH1 -q '.last_response.code'"
# ⚠️ jq interpolation is backslash-paren, NOT dollar-paren. This fixture used ${D}
# and so encoded an INVALID jq selector, which the old presence test could not
# tell from a valid one. Corrected to the form real commands use.
# ⚠️ jq interpolation is backslash-paren, NOT dollar-paren. This fixture used ${D}
# and so encoded an INVALID jq selector, which the old presence test could not
# tell from a valid one. Corrected to the form real commands use.
probe "interpolated field"             allow "$API $GH1/deliveries -q '.[] | \"\\(.status_code)\"'"
probe "unquoted selector"              allow "$API $GH1 -q .id"
probe "selector in = form"             allow "$API $GH1 --jq=.id"
probe "no selector but redirected"     allow "$API $GH1 > /tmp/h.json"
probe "no selector but digested"       allow "$API $GH1 | shasum"
# ⚠️ EVERY SPELLING OF THE SAME RESOURCE: the org endpoint and the numeric
# repositories/<id> alias reach the same object as repos/<owner>/<repo>.
probe "orgs hooks endpoint"            block "$API orgs/X/ho""oks/1"
probe "numeric repositories alias"     block "$API repositories/12345/ho""oks/1"
probe "orgs hooks with a field"        allow "$API orgs/X/ho""oks/1 -q '.id'"
# ⚠️ A FIELD BEING PRESENT IS NOT THE SELECTOR EMITTING ONLY FIELDS. All four of
# these carry a field, so the old presence test passed them, and all four emit the
# whole object anyway. A blacklist cannot close it: the reconstruction form
# carries a field and no banned word, which is why the test is an allow-list
# grammar rather than a list of forbidden tokens.
probe "trailing identity term"         block "$API $GH1 -q '.id, .'"
probe "map/del keeps every other key"  block "$API $GH1 -q 'map(del(.id))'"
probe "recursive descent"              block "$API $GH1 -q '.. | .url? // empty'"
probe "object reconstruction"          block "$API $GH1 -q '{id: .id, value: .}'"

# 7a precision: only the credential-bearing members of .config are caught.
# ⚠️ These three MUST come from variables. Written inline as '.con''fig…' inside a
# double-quoted probe argument the quotes stay literal, the string never becomes
# the real field name, and all three pass without exercising the rule at all.
probe "config object blocked"          block "$API $GH1 -q '$COBJ'"
probe "config content_type allowed"    allow "$API $GH1 -q '$CCT'"
probe "config insecure_ssl allowed"    allow "$API $GH1 -q '$CSSL'"
# Rotation. The write RESPONSE echoes the object, so it needs silencing too.
probe "literal value on a write"       block "$API --method PATCH $GH1 -f $CU=https://example.com/api/webhooks/1/AAAAAAAAAAAAAAAA"
probe "write from a file, unsilenced"  block "$API --method PATCH $GH1 -f \"$CU=${D}(cat ${D}f)\""
probe "write from a file, silenced"    allow "$API --method PATCH $GH1 -f \"$CU=${D}(cat ${D}f)\" > /dev/null"
# An ordinary path containing "hooks" must not be caught.
probe "git-hooks path not caught"      allow "$API repos/O/R/contents/scripts/git-hooks/operators.txt"
probe "an unrelated api call"          allow "$API repos/O/R/pulls/416"

# ⚠️ SCOPE: EVERY CASE ABOVE IS A SINGLE COMMAND LINE, AND THAT IS WHY THEY ALL
# PASSED WHILE THE RULE HAD FOUR FAIL-OPENS AND ONE FAIL-CLOSED. The first version
# grepped the WHOLE line, so a sink or a -q belonging to ANOTHER command satisfied
# it. 146/146 was green with all of it present. These pin the scope in both
# directions: a sink must be in the gh statement to count, and one that is must
# still work.
SINKCMD='shasum -a 256 /tmp/other'
probe "sink from a preceding && command"   block "$SINKCMD && $API $GH1 -q '$CFG'"
probe "redirect from a preceding command"  block "echo start > /tmp/run.log && $API $GH1 -q '$CFG'"
probe "sink in a trailing ; command"       block "$API $GH1 -q '$CFG' ; $SINKCMD"
probe "sink on the far side of ||"         block "$API $GH1 -q '$CFG' || $SINKCMD"
probe "sink only inside a comment"         block "$API $GH1 -q '$CFG'   # later: $SINKCMD"
# A pipeline is ONE statement, so a digest downstream of the same call still counts.
probe "unrelated cmd, then a real sink"    allow "echo hi && $API $GH1 -q '$CFG' > /tmp/u.txt"
# Comment stripping is quote-aware: these hashes are a sed delimiter, not a comment.
probe "inline sed hashes are not comments" block "$API $GH1 -q '$CFG' | sed -E 's#x#y#'"
# The selector must come from the gh statement too, both ways round.
probe "foreign -q, then identity selector" block "grep -q '.foo' /tmp/f && $API repos/O/R/ho""oks -q '.'"
probe "foreign -q, then array iterate"     block "grep -q '.foo' /tmp/f && $API repos/O/R/ho""oks --jq '.[]'"
probe "foreign -q must not over-block"     allow "grep -q needle /tmp/f && $API repos/O/R/ho""oks -q '.id'"
probe "foreign -q, field on a single hook" allow "grep -q needle /tmp/f && $API $GH1 -q '.active'"

# ⚠️ AND THE STATEMENT WAS STILL TOO COARSE: the sink has to be in the pipeline
# ELEMENT of the gh call, not merely somewhere in the statement. Judging it per
# statement left the same scope bug one level down, fail-open both times. Note the
# DIRECTION: a digest upstream of the call cannot consume its output.
probe "redirect belongs to an upstream echo" block "echo hi > /tmp/log | $API $GH1 -q '$CFG'"
probe "digest is upstream of the call"       block "$SINKCMD | $API $GH1 -q '$CFG'"
probe "upstream digest, nothing downstream"  block "wc -c /tmp/o | $API $GH1 -q '$CFG' | cat"
probe "digest downstream through cat"        allow "$API $GH1 -q '$CFG' | cat | shasum -a 256"
# A pipe-ampersand is ONE pipeline, so it must not be read as a statement break.
probe "pipe-ampersand to a digest"           allow "$API $GH1 -q '$CFG' |& shasum -a 256"
# ...while a background & between two commands still separates them.
probe "background ampersand separates"       block "$SINKCMD & $API $GH1 -q '$CFG'"
# The pipe split is QUOTE-AWARE. A jq selector routinely carries a pipe inside
# quotes; splitting naively cut it in half, so the field test saw a fragment and
# refused the call. "deliveries, status codes only" above is that exact shape and
# is what catches a regression here.

# ⚠️ THE REDIRECT VOCABULARY, pinned as a SET because this rule turns on it and
# two spellings were wrong for three rounds. `>|` broke when the pipe split
# arrived, since the noclobber override contains a pipe; `&>` was never accepted
# at all, while rule 5 in this same file accepts `ps -E &>/dev/null` above. One
# operator, two verdicts in one hook, and the refused spelling sends MORE to the
# file, not less. A bare `2>` must stay refused: stdout keeps printing.
probe "redirect: explicit 1>"                allow "$API $GH1 -q '$CFG' 1> /tmp/u"
probe "redirect: noclobber override"         allow "$API $GH1 -q '$CFG' >| /tmp/u"
probe "redirect: and-redirect both fds"      allow "$API $GH1 -q '$CFG' &> /tmp/u"
probe "redirect: no space before the path"   allow "$API $GH1 -q '$CFG' &>/tmp/u"
probe "redirect: stdout to file, stderr dup" allow "$API $GH1 -q '$CFG' > /tmp/u 2>&1"
probe "redirect: 2>&1 alone is not a sink"   block "$API $GH1 -q '$CFG' 2>&1"
# ⚠️ A REDIRECT IS NOT A SINK UNLESS ITS TARGET IS A FILE, and a DIGEST must be
# the command rather than a word in someone else's arguments. Scanning raw text
# for the operator and the name said otherwise eight ways, all measured ALLOW.
#
probe "redirect to /dev/stdout"        block "$API $GH1 -q '$CFG' > /dev/stdout"
probe "redirect to /dev/stderr"        block "$API $GH1 -q '$CFG' > /dev/stderr"
probe "redirect to /dev/tty"           block "$API $GH1 -q '$CFG' > /dev/tty"
probe "process substitution target"    block "$API $GH1 -q '$CFG' > >(cat)"
probe "digest name is only an argument" block "$API $GH1 -q '$CFG' | grep shasum"
probe "digest name inside xargs args"  block "$API $GH1 -q '$CFG' | xargs -I{} echo shasum"
probe "tee does not consume"           block "$API $GH1 -q '$CFG' | tee /dev/tty | shasum"
probe "a > inside a quoted selector"   block "$API $GH1 -q '.id > 5'"
probe "quoted redirect target works"   allow "$API $GH1 -q '$CFG' > \"/tmp/out file\""
# ⚠️ 7c HAS TO BE QUOTE-AWARE: inside SINGLE quotes nothing expands, so a literal
# credential written that way is a literal, not an expansion. All three of these
# were allowed while the value sat in the command text.
probe "single-quoted dollar literal"   block "$API --method PATCH $GH1 -f '$CU=\$uperSecret123' > /dev/null"
probe "single-quoted brace literal"    block "$API --method PATCH $GH1 -f '$CU=\${notavar}' > /dev/null"
probe "expansion outside single quotes" allow "$API --method PATCH $GH1 -f \"$CU=${D}(cat ${D}f)\" > /dev/null"
# ⚠️ A DESCRIPTOR IS NOT A FILE, AND THE LAST REDIRECT WINS. Bash applies
# redirects left to right, so a later one can restore printing that an earlier one
# removed; and a target beginning with an ampersand duplicates a descriptor rather
# than naming a file, so it prints. The exception closes the descriptor entirely.
probe "redirect to stderr by descriptor" block "$API $GH1 -q '$CFG' >&2"
probe "explicit 1 to stderr descriptor"  block "$API $GH1 -q '$CFG' 1>&2"
probe "closing the descriptor consumes"  allow "$API $GH1 -q '$CFG' >&-"
probe "a later redirect restores output" block "$API $GH1 -q '$CFG' > /dev/null > /dev/stdout"
probe "a later redirect to a real file"  allow "$API $GH1 -q '$CFG' > /dev/stdout > /tmp/u.txt"
# ⚠️ A DIGEST OPTION CAN REPRODUCE THE INPUT. Measured on macOS: md5 -p prints
# stdin before the checksum, so the credential is still in the transcript.
probe "digest option prints its input"   block "$API $GH1 -q '$CFG' | md5 -p"
probe "algorithm selector still works"   allow "$API $GH1 -q '$CFG' | shasum -a 256"
# ⚠️ NOT EVERY DOLLAR IS AN EXPANSION: ANSI-C and locale quoting are literal text.
probe "ANSI-C quoted literal"            block "$API --method PATCH $GH1 -f $CU=${D}'superSecret123' > /dev/null"
probe "locale-quoted literal"            block "$API --method PATCH $GH1 -f $CU=${D}\"superSecret123\" > /dev/null"



echo
# The summary carries the RAN count, so a short run cannot be read as success
# by anything that greps only for failed=0. The exit status is authoritative
# either way, but the line above it should not contradict it.
ran=$((pass + fail))
# ONE source for the expected count. The summary used to interpolate the number
# directly while the guard read EXPECTED, so updating only EXPECTED left the
# summary printing a stale denominator. That is the same count-drift this
# guard exists to catch, introduced by the commit that added the guard.
EXPECTED=194
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
