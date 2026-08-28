#!/usr/bin/env bash
# PreToolUse(Bash|Read|Grep): refuse commands that could print a credential to stdout.
#
# Written after a probe of the form `echo "${VAR:-UNSET}"` printed two live
# credentials into a session transcript. That probe is safe only when the
# variable is unset, i.e. only when the test passes: a verification whose
# failure mode is disclosure. This hook removes the class, not that instance.
#
# It is NAME-SHAPE based, so it needs no list of secrets and never reads a
# value. A literal mention of a secret name is fine (grep, docs, .env.example
# references); what is blocked is EXPANDING one, or dumping a store wholesale.
#
# THREAT MODEL: this is a guardrail against ACCIDENTAL disclosure, not a sandbox
# against a determined evader. It matches on the surface form of the command, so
# any construction that hides the dangerous token from a text match defeats it BY
# CONSTRUCTION: string concatenation (PS=ps; "$PS" -E), variable indirection, a
# filename literal split across quotes ("/bin/c""at" .env), base64/eval, or a
# child script the hook never sees. Those are out of scope on purpose; chasing
# them would be an arms race a regex cannot win, and the party doing them already
# has the value. The job here is to stop the honest mistake, the probe that
# discloses on the passing path, not to contain an adversary at the keyboard.
#
# Exit 0 = allow. Exit 2 = block, stderr goes back to the model.

set -uo pipefail

deny() { printf 'BLOCKED by block-secret-echo.sh: %s\n\nUse a form that cannot expand the value:\n  printenv "$v" >/dev/null && echo SET || echo UNSET\n  op read <ref> | shasum -a 256 | cut -c1-12\n' "$1" >&2; exit 2; }

payload=$(cat)

# Name shapes that denote a credential. Defined here, above the parse pass, so
# the one definition is passed into python (rule 2b, print-by-name) as argv[1]
# and reused by the bash rules 1 and 2 below. One source, two consumers.
SECRET_RE='[A-Za-z_]*(_PAT|_TOKEN|TOKEN_[A-Z_]*|_KEY|_KEY_[A-Z_]*|_SECRET|PASSWORD|_PASS|WEBHOOK|API_TOKEN|ACCESS_TOKEN|access_key|CREDENTIAL)[A-Za-z0-9_]*'

# ONE python3 invocation, not three. This runs on every Bash, Read and Grep call
# and used to parse the same payload three separate times: measured 98 ms mean
# over 20 runs, almost all of it interpreter startup. Newline separation rather
# than tab, because a tab delimiter read with `read -r a b` splits on IFS
# whitespace instead, which put the whole command into the path variable and
# made every heredoc mentioning a profile self-block.
#
# file_path (Read/Write/Edit) and path (Grep). The Grep tool defaults to printing
# matching CONTENT, so it has the same hole as bash `grep PAT profile`.
#
# THE PARSED/END SENTINELS EXIST TO MAKE FAILURE DISTINGUISHABLE FROM EMPTINESS.
# A tool call can legitimately carry none of these fields, in which case all
# three lines are empty and command substitution strips them, leaving exactly
# what a total parse failure leaves. Without a marker those two cases are the
# same string, and the script would treat "python3 did not run" as "nothing to
# check".
fields=$(printf '%s' "$payload" | python3 -c 'import json,sys,re
SECRET_RE = sys.argv[1] if len(sys.argv) > 1 else "(?!)"   # passed from bash; (?!) never matches
def flat(s): return (s or "").replace("\n", " ").replace("\r", " ")
try:
    ti = json.load(sys.stdin).get("tool_input", {}) or {}
except Exception:
    # Not JSON at all. Emit NO marker, so the shell below fails closed: a
    # payload that cannot be read is not the same as one carrying no fields,
    # and only the latter is safe to wave through.
    sys.exit(1)
# Rule 6 (ps environment dump) is DECIDED HERE, in the parse pass, over the RAW
# command. Correct detection needs all of: newlines treated as statement
# separators (a multi-line block is not one statement); ps recognised as a
# command word inside sh -c "..." wrappers and after assignment/sudo/path
# prefixes and subshells; a substitution counted as consumption only when it
# captures the ps INTO A VARIABLE (x=$(ps -E)), not when it is printed or passed
# as an argument (echo $(ps -E)); command position required for BOTH branches and
# path-aware, so /bin/ps counts while `cat docs/ps` and `find -name ps -e` do not;
# only a STDOUT redirect to /dev/null consumes, never a 2> stderr discard beside a
# real-file write; and tee treated as a leak even downstream of a count. Not a grep.
# (No literal single quote below: this whole program is a single-quoted -c arg.)
PSL = set("acdefghjlmnopqrstuvwx")
PREFIX = set(["sudo", "command", "nohup", "time", "exec", "env", "xargs", "timeout", "nice", "stdbuf", "doas"])
KEYWORD = set(["do", "then", "else", "in", "if", "while", "until", "elif"])
OPEN = set(";&|(){}\n") | set([chr(96), chr(39), chr(34)])   # operators, backtick, quotes
def subst_spans(st):
    spans = []; i = 0
    while True:
        j = st.find("$(", i)
        if j < 0: break
        d = 1; k = j + 2
        while k < len(st) and d:
            d += (st[k] == "(") - (st[k] == ")"); k += 1
        spans.append((j, k)); i = max(k, j + 2)
    for mm in re.finditer(chr(96) + "[^" + chr(96) + "]*" + chr(96), st):
        spans.append((mm.start(), mm.end()))
    return spans
def at_cmd_pos(before, strict=False):
    b = before.rstrip()
    if not b: return True
    if b[-1] in OPEN: return True
    parts = b.split()
    if strict:
        # STRICT walk, for rules 2b/3/4. The verb is at command position only when
        # every token before it is an assignment, a prefix/keyword word, a flag (or
        # a value-flag and its separate argument), or a duration/number: i.e. the
        # verb is the FIRST real command token. A single real word before it (the
        # `ls` in `sudo ls ./env`) means the verb is an argument, not a command, so
        # it must NOT count. The loose any()-clause below is wrong for these verbs,
        # since `env`/`cat`/`set` need no accompanying flag the way `ps` does, so a
        # prefix word appearing anywhere earlier would drag `sudo ls ./env` into a
        # block.
        #
        # VALUE_OPT_BY is a MAINTAINED TABLE, not a derivation, and it is keyed BY
        # PREFIX because shell option grammar is per-command. The same short flag
        # takes an argument under one prefix and none under another: -s runs a
        # shell for sudo (no argument) but names a signal for timeout (-s KILL);
        # -E preserves the environment for sudo but is the EOF string for xargs;
        # -k invalidates the sudo timestamp but is a duration for timeout. A flat
        # by-flag table gets exactly these wrong: it either eats the real command
        # after sudo -E (over-block) or leaves timeout -s KILL to fail open. So the
        # walk tracks the active prefix and consults only the value options of that
        # prefix. Extend the table per prefix when a new option shows up; do not
        # try to infer it from surface text.
        #
        # THE FLOOR OF THIS APPROACH is a flag with OPTIONAL arity within one
        # command, whose argument depends on the token that follows rather than on
        # the flag: `sudo -h` is help bare but a host with a value, `xargs -i` /
        # `xargs -e` take an optional replstr / eof string. No (prefix, flag) table
        # can decide those, so they are listed as value-taking on purpose: that
        # over-blocks the bare form (`sudo -h ls ./env`, the SAFE direction) but is
        # what keeps the value form from failing open (`sudo -h host env` still
        # blocks). Kept and written down rather than chased. A flag that takes NO
        # argument, by contrast (sudo `-i`/`-H`, time `-a`), must NOT be here, or it
        # eats the real command with no upside.
        DURATION = r"^\d*\.?\d+[smhd]?$"                      # 5, 0.5, 5s, 30m (timeout/nice)
        VALUE_OPT_BY = {
            "sudo": set(["-u","-g","-U","-p","-h","-r","-t","-C","-D","-R","-a",
                         "--user","--group","--host","--prompt","--chdir","--role",
                         "--type","--other-user","--close-from"]),
            "doas": set(["-u","-C","-a"]),
            "env": set(["-u","-S","-C","-P","--unset","--split-string","--chdir"]),
            "xargs": set(["-I","-i","-d","-E","-e","-a","-s","-L","-n","-P",
                          "--replace","--delimiter","--eof","--arg-file",
                          "--max-args","--max-procs","--max-lines","--process-slot-var"]),
            "timeout": set(["-s","-k","--signal","--kill-after"]),
            "nice": set(["-n","--adjustment"]),
            "stdbuf": set(["-i","-o","-e","--input","--output","--error"]),
            "time": set(["-o","-f","--output","--format"]),  # NOT -a: append is a no-arg flag
            "exec": set(["-a"]),
            "command": set(), "nohup": set(),
        }
        cur = None                                           # the active PREFIX whose options are in scope
        i = 0
        while i < len(parts):
            t = parts[i].lstrip("(){}")                      # a subshell/group opener before the run
            if not t: i += 1; continue
            if t in PREFIX: cur = t; i += 1; continue        # sudo, timeout, env, ...: now in scope
            if t in KEYWORD: i += 1; continue                # do, then, ...: carry no options
            if re.match(r"^[A-Za-z_]\w*=\S*$", t): i += 1; continue  # an assignment (FOO=bar)
            if t.startswith("-"):
                if t in VALUE_OPT_BY.get(cur, ()): i += 2    # a value-flag OF THIS prefix + its argument
                else: i += 1                                 # a no-argument flag (or attached value)
                continue
            if re.match(DURATION, t): i += 1; continue       # a duration / bare number
            return False                                     # a real command precedes the verb
        return True
    # a prefix/keyword ANYWHERE in the run, not just the last token: `timeout 5 ps`
    # and `sudo -u root ps` carry their own args, which a last-token test walks past.
    # This is deliberately loose and correct ONLY for rule 6, where a match also
    # requires an env-showing flag; ps as a bare path component is rare, and this
    # is what makes `sudo -u root ps -E` block. Rules 2b/3/4 pass strict=True.
    if any(t in PREFIX or t in KEYWORD for t in parts): return True
    last = parts[-1] if parts else ""
    if last.endswith("/"):                       # a path prefix (/bin/ps): strip it and re-test,
        return at_cmd_pos(b[:len(b) - len(last)]) # so /bin/ps is a command but cat docs/ps is not
    return re.match(r"^[A-Za-z_]\w*=\S*$", last) is not None
def stmt_block(st):
    spans = subst_spans(st)
    for m in re.finditer(r"(?<![A-Za-z0-9_])ps(?![A-Za-z0-9_])", st):
        if not at_cmd_pos(st[:m.start()]): continue            # BOTH branches need command position
        args = re.split(r"[|<>]", st[m.end():], 1)[0]          # ps own args, before a pipe/redirect
        env = re.search(r"(?:^|\s)-[A-Za-z]*[eE][A-Za-z]*(?:\s|$|\)|[\x27\x22\x60])", args) is not None
        if not env:
            bm = re.match(r"\s+([a-z]+)(?:\s|$|\)|[\x27\x22\x60])", args)
            env = bool(bm and "e" in bm.group(1) and set(bm.group(1)) <= PSL)
        if not env: continue
        span = None
        for (a, b) in spans:
            if a <= m.start() < b: span = (a, b); break
        if span is not None:
            if re.match(r"^\s*(?:export\s+|local\s+|declare\s+|readonly\s+|typeset\s+)?[A-Za-z_]\w*=\s*$", st[:span[0]]):
                continue                                                 # substitution IS the assignment RHS -> stored
            return True                                                 # captured but printed/arg -> leak
        if re.search(r"(?:^|\s)(?:1?>|&>)\s*/dev/null", st): continue    # STDOUT to /dev/null, not 2>
        tee = re.search(r"\btee\b", st)                                  # tee writes to disk mid-pipeline
        if not tee and re.search(r"\|\s*(?:[^|]*\s)?(?:shasum|sha256sum|md5|wc)\b", st): continue
        if not tee and re.search(r"\|\s*(?:[^|]*\s)?grep\b[^|]*\s-[A-Za-z]*c\b", st): continue
        return True
    return False
ps_verdict = "OK"
for st in re.split(r";|&&|\|\||&(?!>)|\n", ti.get("command") or ""):  # RAW cmd; newline splits; & but not &>
    if stmt_block(st):
        ps_verdict = "BLOCK"; break
# Rules 2b, 3 and 4 also turn on "command position", and used to re-derive it in
# three separate grep regexes that each got it subtly wrong: a mid-path component
# counted as the verb (so /usr/local/opt/node/.env, `ls ./env`, `cd /a/b/env`,
# `chmod +x /a/bin/set` all blocked), while a bare word after `sudo` could not be
# told from one after `ls`. They now share the SAME at_cmd_pos predicate as rule 6.
# A verb counts as a command only when at_cmd_pos holds for the text before it; an
# optional path prefix ([^space;&|<>]*/) inside the match lets /usr/bin/env count
# while keeping ./env, a mid-path component, and a plain argument out.
ENVFILE = r"(^|[^A-Za-z0-9_.~-])\.env($|[^a-zA-Z.])"
READER_ALT = "cat|bat|less|more|head|tail|open|pbcopy|strings|xxd|od|grep|egrep|fgrep|rg|ag|awk|sed|perl|python3?|ruby|node|deno|php|source"
def verb_at_cmd(st, alt, flags=0):
    for m in re.finditer(r"(?<![A-Za-z0-9_./-])(?:[^\s;&|<>]*/)?(" + alt + r")(?![A-Za-z0-9_])", st, flags):
        if at_cmd_pos(st[:m.start()], strict=True): yield m   # 2b/3/4 need the strict walk
def env_dump(st):        # bare env / printenv / set, or export -p, at command position
    for m in verb_at_cmd(st, "env|printenv|set"):
        if re.match(r"\s*($|[;&|])", st[m.end():]): return True
    for m in verb_at_cmd(st, "export"):
        if re.match(r"\s+-p\s*($|[;&|])", st[m.end():]): return True
    return False
def env_file(st):        # names a .env AND reads it (reader at command position, or the . builtin)
    if not re.search(ENVFILE, st): return False
    if re.match(r"\s*\.\s", st): return True
    for m in verb_at_cmd(st, READER_ALT): return True
    return False
def print_name(st):      # printenv NAME / declare -p NAME / ..., NAME secret-shaped, not redirected away
    for m in verb_at_cmd(st, "printenv|declare|typeset|export", re.I):
        rest = st[m.end():]
        if m.group(1).lower() == "printenv":
            hit = re.match(r"\s+(?:" + SECRET_RE + r")", rest, re.I)
        else:
            hit = re.match(r"\s+-p\s+(?:" + SECRET_RE + r")", rest, re.I)
        if hit and not re.search(r">\s*/dev/null|>[^&]", st): return True
    return False
envdump_v = envfile_v = printname_v = "OK"
for st in re.split(r"[;|&\n]", ti.get("command") or ""):  # finest split (matches the old tr ";|&")
    if env_dump(st): envdump_v = "BLOCK"
    if env_file(st): envfile_v = "BLOCK"
    if print_name(st): printname_v = "BLOCK"
cmd_s = flat(ti.get("command"))
print("PARSED")
print(cmd_s)
print(flat(ti.get("file_path") or ti.get("path")))
print(flat(ti.get("output_mode")))
print(ps_verdict)
print(envdump_v)
print(envfile_v)
print(printname_v)
print("END")' "$SECRET_RE" 2>/dev/null)

# FAIL CLOSED. Measured before this existed: with the shell utilities present and
# only python3 absent from PATH, `echo "${GITHUB_TOKEN:-UNSET}"` was ALLOWED and
# nothing was written to stderr. That is the exact probe this hook was written
# for, passing silently.
#
# The rule this follows: an error path that lets the hook pass when its
# underlying tool is missing or fails is worse than no hook, because it reports
# success. So this denies instead, which blocks every matched tool call until
# python3 is back. That is the intended cost: a control that cannot read its
# input must not report success. The message names the cause so it is one line to
# diagnose: fail closed, but DIAGNOSABLE.
case $fields in
  PARSED*END) : ;;
  *) deny 'cannot parse the tool payload, so nothing can be checked: python3 is missing or failed. Failing closed on purpose' ;;
esac

rest=${fields#PARSED$'\n'}
cmd=${rest%%$'\n'*}
rest=${rest#*$'\n'}
path=${rest%%$'\n'*}
rest=${rest#*$'\n'}
gmode=${rest%%$'\n'*}
rest=${rest#*$'\n'}
ps_verdict=${rest%%$'\n'*}
rest=${rest#*$'\n'}
envdump_verdict=${rest%%$'\n'*}
rest=${rest#*$'\n'}
envfile_verdict=${rest%%$'\n'*}
rest=${rest#*$'\n'}
printname_verdict=${rest%%$'\n'*}

# Reading a profile or env file wholesale displays every value in it. Applies
# to Read/NotebookEdit style tools, which carry file_path rather than command.
if [ -n "${path:-}" ] && printf '%s' "$path" \
     | grep -qE '(\.zshrc[a-z.]*|\.bash_profile|\.bashrc|\.zshenv|\.zprofile|/\.env$|/\.env\.[a-z]*$)'; then
  case "$path" in
    *.env.example|*.env.sample|*.env.template) : ;;   # reference files, no values
    *)
      # files_with_matches / count emit no file content, so they stay allowed.
      case "$gmode" in
        files_with_matches|count) : ;;
        *) deny "reads $path in a mode that would display its values" ;;
      esac
      ;;
  esac
fi

[ -z "${cmd:-}" ] && exit 0

# SECRET_RE is defined above the parse pass so python (rule 2b) and bash (rules
# 1 and 2) share the one definition.

# 1. Name-indirection, in BOTH shells. This is the exact flag that leaked; no
#    legitimate use in this workflow outweighs the risk, so it is blocked
#    outright. bash spells it ${!v} and zsh spells it ${(P)v}; both expand a
#    variable chosen at RUNTIME, so no name-shape rule below can see what they
#    resolve to. The bash form was missed originally even though this script's
#    own shebang is bash: measured, `v=GITHUB_TOKEN; echo "${!v}"` was allowed.
if printf '%s' "$cmd" | grep -qE '\$\{\(P\)|\$\{!'; then
  deny 'name-indirection expands a variable chosen at runtime'
fi

# 2. Expanding a secret-shaped variable: $FOO_TOKEN, ${FOO_TOKEN, ${FOO_TOKEN:-...}
#    CASE-INSENSITIVE, because a shell local is as likely to be $gh_token as
#    $GH_TOKEN and both expand the same value. Measured before this changed:
#    `echo $gh_token` and `echo $api_key` were both allowed.
#    The cost is that expanding an innocent $primary_key is now refused. That
#    is the intended trade: the deny message names a safe form, so a false
#    positive costs one visible retry, while a false negative is a credential
#    in a transcript.
if printf '%s' "$cmd" | grep -qEi '\$\{?'"$SECRET_RE"; then
  deny 'the command expands a secret-shaped variable'
fi

# 2b. Printing a secret BY NAME, without expanding it. These slip between rule
#     2, which needs a `$`, and rule 4, which needs the command to end right
#     after the verb. Measured as allowed before this rule existed: `printenv
#     GITHUB_TOKEN`, `declare -p GITHUB_TOKEN`, `export -p GITHUB_TOKEN`.
#     Note the irony that made it easy to miss: `printenv "$v" >/dev/null` is
#     the SAFE form this script recommends in its own deny message, so the tool
#     was already in the vocabulary as a remedy rather than a hazard. It is a
#     hazard exactly when it carries a bare secret-shaped name unredirected.
# DECIDED in the parse pass (print_name), so the verb is recognised at command
# position by the same at_cmd_pos as rule 6: /usr/bin/printenv TOKEN is caught,
# a mid-path `printenv` component is not. Redirected-away forms stay allowed.
[ "${printname_verdict:-}" = "BLOCK" ] && deny 'prints a secret-shaped variable by name'

# 3. ANY command that reads a shell profile or .env is blocked unless it can
#    only emit counts, filenames or a status. A plain `grep PAT profile` prints
#    the whole matching line, values included, so listing "dumping" commands
#    (cat/head/...) was not enough: the search tools are the bigger hazard.
# Shell profiles and .env files are OFF LIMITS outright, not merely filtered.
# An earlier version allowed -c/-l/-q and a names-only helper; that escape is
# withdrawn. There is rarely a routine reason to open these files, and a blanket
# deny is the only form with no parsing edge to get wrong. Relax deliberately if
# a real need appears.
# Two classes, deliberately different. A SHELL PROFILE is never something a
# session needs to open, so it is a blanket deny. A repo env file under a
# secrets-manager reference pattern (e.g. 1Password's op:// references) holds
# references rather than values and gets created by `cp .env.example .env`, so
# blanket-denying it blocks the setup step itself. For those, deny only commands
# that could DISPLAY the contents; cp, mv and chmod reveal nothing and are allowed.

# The env-file reader detection (which command names count, the "not a filename
# character" delimiter class, the `.env` shape, and the `.` source builtin) now
# lives in the parse pass (env_file), so a reader is recognised at command
# position by the same at_cmd_pos as rule 6. The regexes that used to live here
# each re-derived command position and got it wrong on paths; see env_file above.
# The measured defects they fixed are preserved in the parse-pass comments and in
# the suites: `cat<.env` (delimiter class), `cp .env.example .env` / `chmod 600
# .env` / `mv .env .env.bak` (the `.` builtin vs a `.env` argument), and now the
# path forms /bin/cat .env (fail-open) and /usr/local/opt/node/.env (over-block).

# A segment qualifies for the check-ignore exemption only if it IS a
# check-ignore command, not if it merely contains one.
#
# Containing one was the old test, and it handed out a pass to everything beside
# it. Measured before this: `git check-ignore -q .env && cat .env` and
# `cat .env && git check-ignore -q .env` were both ALLOWED, because the string
# contained a check-ignore somewhere. Per-segment splitting alone does not fix
# it either, since a substitution keeps the reader inside the exempt segment:
# `cat ~/.zshrc "$(git check-ignore -q .env)"` is ONE segment that both names a
# profile and contains a check-ignore.
#
# So the segment must START with git, and must carry no substitution, no
# redirection and no chaining. Anything richer than a literal check-ignore
# invocation is refused, which fails closed.
seg_is_check_ignore() {
    printf '%s' "$1" \
      | grep -qE '^[[:space:]]*git([[:space:]]+-[^[:space:]]+)*[[:space:]]+check-ignore([[:space:]]|$)' \
      || return 1
    printf '%s' "$1" | grep -q '[$`<>]' && return 1
    return 0
}

# Env files: decided in the parse pass (env_file), which splits per statement and
# denies one that names a .env AND could display it. No check-ignore exemption is
# needed: `git` is not a reader, so a check-ignore statement never reaches this.
[ "${envfile_verdict:-}" = "BLOCK" ] && deny 'that command could display the contents of an env file; copy or inspect the committed .env.example instead'

# The PROFILE rule stays in bash: it is a blanket deny of any command that names a
# shell profile, with a single check-ignore exemption, so it needs no command-
# position parsing. NOTE the trailing newline in `printf '%s\n'`: with a bare
# `printf '%s'` the final segment is unterminated, `read` returns nonzero on it,
# the loop body never runs for it, and a single-segment command was ALLOWED. That
# fail-open was found by the suite immediately after the split was introduced.
PROFILE_RE='(\.zshrc[a-z.]*|\.bash_profile|\.bashrc|\.zshenv|\.zprofile)'
if printf '%s' "$cmd" | grep -qE "$PROFILE_RE"; then
  # `git check-ignore` tests a PATH against ignore rules and never opens the
  # file, so it cannot disclose a value. It is also a check the secrets pattern
  # prescribes, so blocking it would make the guard forbid its own doc.
  bad=$(printf '%s\n' "$cmd" | tr ';|&' '\n\n\n' | while IFS= read -r seg; do
          printf '%s' "$seg" | grep -qE "$PROFILE_RE" || continue
          seg_is_check_ignore "$seg" || echo X
        done)
  if [ -n "$bad" ]; then
    deny 'shell profiles are off limits; work in the repo and use .env.example references instead'
  fi
fi

# 4. Whole-environment dumps (bare env / printenv / set, or export -p). DECIDED
#    in the parse pass (env_dump), so a path form /usr/bin/env is caught while
#    `ls ./env`, `cd /a/b/env` and `chmod +x /a/bin/set` are not: the verb only
#    counts at command position, by the same at_cmd_pos as rule 6. `op` in rule 5
#    handles paths via its own \b boundary and is unchanged.
[ "${envdump_verdict:-}" = "BLOCK" ] && deny 'dumps the entire environment'

# 5. op output must be consumed, never printed. Allow it only when piped to a
#    digest/length, redirected, or captured in a variable.
if printf '%s' "$cmd" | grep -qE '\bop (read|item get)\b'; then
  if ! printf '%s' "$cmd" | grep -qE '(shasum|sha256sum|md5|wc -c|wc -m|>[^&]|\$\(|`|--format[= ]json[^|]*\|)'; then
    deny 'op read/item get output is not piped to a digest or redirected'
  fi
fi

# 6. ps can print a process's environment; on macOS -E, -e, any dash bundle
#    containing e (-ef), and the BSD bare bundles (e, eww, axe, auxe) all do
#    (measured on 15.6.1). The verdict is computed in the python parse pass
#    above, PER STATEMENT and seeing through sh -c "..." wrappers and
#    command-position prefixes, and is BLOCK unless the output is consumed (piped
#    to a count/digest, redirected to /dev/null, or captured). Doing it there
#    rather than with grep is deliberate: the per-segment grep this replaced let
#    the incident shape (assignment-prefixed sh -c) and compound commands through,
#    and judged consumption against the whole line rather than the ps pipeline.
[ "${ps_verdict:-}" = "BLOCK" ] && \
  deny 'ps with an environment flag can print process environments; pipe to a count/digest, redirect to /dev/null, or use pgrep / ps -A -o pid,command'

exit 0
