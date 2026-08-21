#!/bin/bash
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

[[ -z "$CWD" ]] && exit 0

WARNINGS=()

[[ ! -f "$CWD/.gitignore" ]] && WARNINGS+=("No .gitignore found")

# ONE validated cleanup path for the probe directory, used by both exits below.
# `rm -rf` on an interpolated variable is worth gating even when the value comes
# from mktemp: an empty or truncated value must never reach it. Requiring an
# absolute path with at least two components, that exists and is a directory,
# means no plausible failure of mktemp can expand into a destructive command.
PROBE_DIR=
cleanup_probe() {
  [[ -n "$PROBE_DIR" && "$PROBE_DIR" == /*/* && -d "$PROBE_DIR" ]] || return 0
  rm -rf "$PROBE_DIR"
}

if [[ -f "$CWD/.gitignore" ]]; then
  # ASK GIT WHAT IS ACTUALLY IGNORED. Do not grep the .gitignore text.
  #
  # Every earlier version tested whether a pattern was MENTIONED in the file,
  # which is a different question and is defeated by ordinary configs:
  #
  #   `.env.local` + `*.env.local`   satisfied both env substring tests while
  #                                  .env, .envrc and audit.env were all tracked
  #   `.env/` + `.env*/`             trailing slash makes both directory-only, so
  #                                  the .env FILE stays tracked; test passed
  #   `!*.env` alone                 a negation adds no protection, test passed
  #   `.env.local` + kin             create-react-app's set, .env itself tracked
  #
  # A documented false negative is not an acceptable state for a security control
  # that ships in a public template, where the reader has not read this comment.
  #
  # DELIBERATELY ROOT-.gitignore ONLY. Coverage supplied by .git/info/exclude or a
  # global core.excludesFile reads here as uncovered and the hook warns. That is
  # the safe direction and it is intentional: protection that does not travel with
  # the repository is not protection for anyone who clones it.
  PROBE_DIR=$(mktemp -d 2>/dev/null)
  if [[ -z "$PROBE_DIR" ]] || ! command -v git >/dev/null 2>&1 \
     || ! GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
            git -C "$PROBE_DIR" init -q . >/dev/null 2>&1 \
     || ! cp "$CWD/.gitignore" "$PROBE_DIR/.gitignore" 2>/dev/null; then
    # FAIL CLOSED. A control that cannot run must not report success by staying
    # silent, which is the defect this file has had to fix in several places.
    WARNINGS+=("gitignore coverage NOT CHECKED (git or mktemp unavailable)")
    cleanup_probe
  else
    # HERMETIC, AND THE INIT NEEDS IT AS MUCH AS THE QUERY. Without these the
    # verdict depends on who ran it: a global core.excludesFile or a system config
    # could ignore a path this repo does not, and the hook would report protection
    # the repo does not actually have.
    #
    # Guarding only the query is NOT enough, which is why the init above carries the
    # same pair. A global `init.templateDir` copies its info/exclude into every new
    # repository, so an unguarded `git init` plants exclude rules INSIDE the probe
    # .git before any query runs, and no query-side hardening can see past them.
    # Measured with a template holding one line: the probe reported that path
    # ignored; guarding the query alone still reported it ignored; guarding the init
    # with this pair left the injected line out and the probe reported it not
    # ignored. `-c init.templateDir=` also blocks it, but only that one vector,
    # where the env pair blocks whatever else global config could do at init time.
    probe() {
      GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
        git -C "$PROBE_DIR" -c core.excludesFile=/dev/null \
            check-ignore -q --no-index -- "$1" 2>/dev/null
    }
    # `check-ignore -q` returns 1 for "not ignored" AND for a negation match, which
    # is the wanted answer in both cases. Note -v would return 0 on a negation and
    # read as "ignored"; do not switch to it for a friendlier message.
    #
    # EVERY CLASS IS PROBED WITH AT LEAST TWO INDEPENDENT NAMES, and that is not
    # belt-and-braces. With one name per class a .gitignore listing exactly those
    # literals passed every check while leaving credentials-prod.txt, app.log,
    # ca.pem, id_rsa.key, secrets/deep/y, node_modules/pkg/i.js, pkg/__pycache__/y,
    # data/app.sqlite and data/app.db unprotected. Measured: the hook was SILENT.
    # A class passes only if all of its names are ignored, so a single literal rule
    # can no longer stand in for pattern coverage. Second names deliberately differ
    # in shape: nested vs root, different extension, different prefix.
    probe_class() {  # $1 label, then one or more names
      local label=$1 n
      shift
      for n in "$@"; do
        probe "$n" || { WARNINGS+=("$label not ignored"); return 0; }
      done
    }
    # THE ENV CLASS CARRIES A NESTED NAME TOO, and it was the only class without
    # one, against the rule stated three lines up. The four root-level names were
    # all satisfied by a .gitignore holding exactly those four literals, while a
    # nested suffix-glob path stayed unignored: measured, the class reported PASS
    # and that path came back not ignored. So the tracked-file check below, which
    # reports a nested env file as already committed, had no coverage requirement
    # standing behind it. The name used here is the same one that check's comment
    # names as the real secret a substring filter once dropped, so the probe and
    # the report now ask about the same shape. It can only ADD a requirement,
    # since a class passes only when every one of its names passes.
    # check-ignore --no-index answers on the path name alone, so no directory has
    # to exist inside the probe repository.
    ENVMISS=()
    for probe_name in .env .envrc .env.local prod.env examples/audit.env; do
      probe "$probe_name" || ENVMISS+=("$probe_name")
    done
    [[ ${#ENVMISS[@]} -gt 0 ]] && WARNINGS+=("env files not ignored: ${ENVMISS[*]}")
    probe_class "*.log"          debug.log        logs/app.log
    probe_class "*.pem"          server.pem       certs/ca.pem
    probe_class "*.key"          server.key       keys/id_rsa.key
    probe_class "secrets/"       secrets/x        secrets/deep/y
    probe_class "credentials*"   credentials.json credentials-prod.txt
    probe_class "node_modules/"  node_modules/x   node_modules/pkg/index.js
    probe_class "__pycache__/"   __pycache__/x    pkg/__pycache__/y
    probe_class ".DS_Store"      .DS_Store        sub/.DS_Store
    probe_class "*.sqlite"       db.sqlite        data/app.sqlite
    probe_class "*.db"           db.db            data/app.db
    cleanup_probe
  fi
fi

# ALREADY-TRACKED FILES, WHICH IS A DIFFERENT QUESTION FROM THE ONE ABOVE.
# check-ignore answers "would this NAME be ignored". It says nothing about what is
# already committed, and .gitignore never untracks. So a repository that committed
# an env file BEFORE the pattern existed goes silent above the moment the pattern
# is added, while the plaintext blob stays in the tree and in history.
#
# GIT IS TESTED SEPARATELY FROM THE WORK-TREE QUESTION. `rev-parse` returns
# non-zero both when git is missing and when this is simply not a repository, and
# treating those alike let the whole control be skipped in silence when the tool
# was absent. Measured: with git off PATH the hook warned about gitignore coverage
# and said nothing at all about the tracked-file check.
#
# BOTH TESTS ARE SCOPED TO THE BASENAME. Filtering the whole path silently dropped
# a real secret at `examples/audit.env`, because the directory carries the word.
#
# THE EXCLUSION IS A SUFFIX, not a substring. `b !~ /example|sample|template/`
# also swallowed sample.env, myexample.env, template.env and exampleconfig.env,
# which are ordinary environment-file names. Anchoring to a trailing
# [._-]example|sample|template keeps all seven committed-template shapes excluded
# (.env-example, .env-sample, .env.example, .env.template and nested variants)
# while those four are reported again. Measured on both sets.
#
# THE PREFIX IS BOUNDED so `.envelope` and `.envtest` are not reported as env
# files. `(rc)?` is load-bearing and the obvious `^\.env($|[._-])` is wrong: it
# drops `.envrc` and `.envrc.local`, precisely the files this policy exists for.
#
# tolower() keeps the case-insensitivity the original `grep -vi` had. Measured by
# feeding paths straight through the filter, which needs no checkout:
# `x/.env.EXAMPLE` is not flagged, `AUDIT.ENV` is.
if ! command -v git >/dev/null 2>&1; then
  WARNINGS+=("tracked-file check NOT PERFORMED (git unavailable)")
elif git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if TRACKED=$(git -C "$CWD" ls-files 2>/dev/null); then
    TRACKED_ENV=$(printf '%s\n' "$TRACKED" \
      | awk -F/ '{ b = tolower($NF) }
                 (b ~ /^\.env(rc)?($|[._-])/ || b ~ /\.env$/) \
                 && b !~ /[._-](example|sample|template)$/ { print }')
    [[ -n "$TRACKED_ENV" ]] && WARNINGS+=("env file(s) already TRACKED, gitignore will not untrack: $(printf '%s' "$TRACKED_ENV" | tr '\n' ' ')")
  else
    # Same rule as above: could not look is not the same as nothing found.
    WARNINGS+=("tracked-file check NOT PERFORMED (git ls-files failed)")
  fi
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "SECURITY WARNING: ${WARNINGS[*]}" >&2
fi
exit 0
