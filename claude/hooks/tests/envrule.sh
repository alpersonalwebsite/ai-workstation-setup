#!/bin/bash
# Regression suite for the shell-profile and env-file rules of
# ~/.claude/hooks/block-secret-echo.sh. Everything else is in hook-suite.sh.
#
# Run both after ANY edit to the hook:
#     ./hook-suite.sh && ./envrule.sh
#
# The two classes are deliberately different and that is what most of this file
# asserts: a shell profile is a blanket deny, while an env file is denied only
# for commands that could DISPLAY it, because one holds op:// references rather
# than values and is created by copying the committed example.
#
# NO LITERAL THAT ANY DETECTOR HERE WOULD FLAG APPEARS IN THIS FILE, and the
# keyword and its value are never adjacent in the source. The env-file and
# profile names are assembled too. That is the narrow claim and it is the true
# one: a bare value does appear, but nothing here matches gitleaks or the hook
# under test. Written plainly, several lines here are
# blocked on execution by the very hook under test.
#
# Exit 0 = all cases behave. Exit 1 = at least one does not.

set -euo pipefail

HOOK="${1:-$HOME/.claude/hooks/block-secret-echo.sh}"
[ -x "$HOOK" ] || { echo "not executable: $HOOK" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 required" >&2; exit 2; }

pass=0; fail=0

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

E=".en""v"           # env file
EX="${E}.example"
Z="~/.zsh""rc"       # a shell profile

echo "== shell profiles are a blanket deny =="
probe "cat a profile"                    block "cat $Z"
probe "grep a profile"                   block "grep PAT $Z"
probe "head a profile"                   block "head ~/.bash""rc"
probe "source a profile"                 block "source ~/.zpro""file"
probe "an interpreter reading a profile" block "python3 -c 'print(open(\"$Z\").read())'"

echo
echo "== the ONE profile exception: check-ignore never opens the file =="
probe "bare check-ignore on a profile"   allow "git check-ignore $Z"
probe "with a flag"                      allow "git check-ignore -q $Z"
probe "chained with a reader"            block "cat $Z && git check-ignore $Z"
probe "reader first, check-ignore after" block "git check-ignore -q $Z; cat $Z"
probe "substitution hiding a reader"     block "cat $Z \"\$(git check-ignore -q $E)\""

echo
echo "== env files: DISPLAY commands are denied =="
probe "cat"                              block "cat $E"
probe "cat by absolute path"             block "/bin/cat $E"
probe "reader after a sudo prefix"       block "sudo cat $E"
probe "grep"                             block "grep TOKEN $E"
probe "grep by absolute path"            block "/bin/grep TOKEN $E"
probe "less"                             block "less $E"
probe "the source builtin"               block ". $E"
probe "source by name"                   block "source $E"
probe "an interpreter reading one"       block "python3 -c 'print(open(\"$E\").read())'"

echo
echo "== the delimiter must not be a hand-listed set =="
probe "redirection, no space"            block "cat<$E"
probe "redirection with a reader arg"    block "grep pattern<$E"
probe "tab separated"                    block "$(printf 'cat\t%s' "$E")"
probe "with a leading ./"                block "cat ./$E"
probe "under a home path"                block "cat ~/$E"
probe "under a subdirectory"             block "cat src/$E"

echo
echo "== env files: commands that reveal nothing are allowed =="
probe "copy from the example"            allow "cp $EX $E"
probe "chmod"                            allow "chmod 600 $E"
probe "move"                             allow "mv $E $E.bak"
probe "list"                             allow "ls -la $E"
probe "read the committed example"       allow "cat $EX"
# command position: a reader NAME sitting mid-path is a directory component, not a
# command reading the .env. These over-blocked when rule 3 added `/` to a flat
# leading class (the trailing \b was satisfied by the next /); fixed via at_cmd_pos.
probe "reader name mid-path (node)"      allow "ls -la /usr/local/opt/node/$E"
probe "reader name mid-path (head)"      allow "cp vendor/$E vendor/head/x"
probe "reader name mid-path (source)"    allow "mv app/$E app/source/$E.bak"
# a prefix word earlier must not resurrect the mid-path over-block (strict walk)
probe "prefix then mid-path reader"      allow "sudo cp vendor/$E vendor/head/x"
probe "value-flag then a real reader"    block "sudo -u root cat $E"

echo
echo "== the Read and Grep tools carry a path, not a command =="
probe "Read a profile"                   block "" "{\"file_path\": \"/Users/x/.zsh""rc\"}"
probe "Grep a profile, content mode"     block "" "{\"path\": \"/Users/x/.zsh""rc\", \"output_mode\": \"content\"}"
probe "Grep, files_with_matches only"    allow "" "{\"path\": \"/Users/x/.zsh""rc\", \"output_mode\": \"files_with_matches\"}"
probe "Grep, count only"                 allow "" "{\"path\": \"/Users/x/.zsh""rc\", \"output_mode\": \"count\"}"
probe "Read the committed example"       allow "" "{\"file_path\": \"/Users/x/$EX\"}"

echo
# The summary carries the RAN count, so a short run cannot be read as success
# by anything that greps only for failed=0. The exit status is authoritative
# either way, but the line above it should not contradict it.
ran=$((pass + fail))
# ONE source for the expected count. The summary used to interpolate the number
# directly while the guard read EXPECTED, so updating only EXPECTED left the
# summary printing a stale denominator. That is the same count-drift this
# guard exists to catch, introduced by the commit that added the guard.
EXPECTED=40
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
