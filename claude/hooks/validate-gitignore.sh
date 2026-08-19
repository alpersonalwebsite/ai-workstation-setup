#!/bin/bash
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

[[ -z "$CWD" ]] && exit 0

WARNINGS=()

[[ ! -f "$CWD/.gitignore" ]] && WARNINGS+=("No .gitignore found")

if [[ -f "$CWD/.gitignore" ]]; then
  # ASK GIT WHAT IS ACTUALLY IGNORED. Do not grep the .gitignore text.
  #
  # Every earlier version of this hook tested whether a pattern was MENTIONED in
  # the file, which is a different question and is defeated by ordinary configs:
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
  # Names probed for the env policy are the ones `.env*` and `*.env` exist to
  # cover. Measured across 103 real .gitignore files, probing all four warns on 98
  # where the old substring tests warned on 82. That gap is not new breakage; it is
  # the 16 repos leaving .envrc unignored plus the shapes above, which a text test
  # could never see.
  #
  # DELIBERATELY ROOT-.gitignore ONLY. Coverage supplied by .git/info/exclude or a
  # global core.excludesFile reads here as uncovered, and the hook warns. That is
  # the safe direction and it is intentional: protection that does not travel with
  # the repository is not protection for anyone who clones it.
  PROBE_DIR=$(mktemp -d 2>/dev/null)
  if [[ -z "$PROBE_DIR" ]] || ! command -v git >/dev/null 2>&1 \
     || ! git -C "$PROBE_DIR" init -q . >/dev/null 2>&1 \
     || ! cp "$CWD/.gitignore" "$PROBE_DIR/.gitignore" 2>/dev/null; then
    # FAIL CLOSED. A control that cannot run must not report success by staying
    # silent, which is the defect this file has had to fix in three other places.
    WARNINGS+=("gitignore coverage NOT CHECKED (git or mktemp unavailable)")
    [[ -n "$PROBE_DIR" ]] && rm -rf "$PROBE_DIR"
  else
    # HERMETIC. Without these the verdict depends on who ran it: a global
    # core.excludesFile or a system config could ignore a path this repo does not,
    # and the hook would report protection the repo does not actually have.
    probe() {
      GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
        git -C "$PROBE_DIR" -c core.excludesFile=/dev/null \
            check-ignore -q --no-index -- "$1" 2>/dev/null
    }
    # `check-ignore -q` returns 1 for "not ignored" AND for a negation match, which
    # is the wanted answer in both cases. Note -v would return 0 on a negation and
    # read as "ignored"; do not switch to it for a friendlier message.
    ENVMISS=()
    for probe_name in .env .envrc .env.local prod.env; do
      probe "$probe_name" || ENVMISS+=("$probe_name")
    done
    [[ ${#ENVMISS[@]} -gt 0 ]] && WARNINGS+=("env files not ignored: ${ENVMISS[*]}")
    probe debug.log        || WARNINGS+=("*.log not ignored")
    probe server.pem       || WARNINGS+=("*.pem not ignored")
    probe server.key       || WARNINGS+=("*.key not ignored")
    probe secrets/x        || WARNINGS+=("secrets/ not ignored")
    probe credentials.json || WARNINGS+=("credentials* not ignored")
    probe node_modules/x   || WARNINGS+=("node_modules/ not ignored")
    probe __pycache__/x    || WARNINGS+=("__pycache__/ not ignored")
    probe .DS_Store        || WARNINGS+=(".DS_Store not ignored")
    probe db.sqlite        || WARNINGS+=("*.sqlite not ignored")
    probe db.db            || WARNINGS+=("*.db not ignored")
    rm -rf "$PROBE_DIR"
  fi
fi

# ALREADY-TRACKED FILES, WHICH IS A DIFFERENT QUESTION FROM THE ONE ABOVE.
# check-ignore answers "would this NAME be ignored". It says nothing about what is
# already committed, and .gitignore never untracks. So a repository that committed
# an env file BEFORE the pattern existed goes silent above the moment the pattern
# is added, while the plaintext blob stays in the tree and in history. Measured on
# a fixture reproducing exactly that: fully covering .gitignore, hook silent,
# `git ls-files` still listing the file.
#
# Committed *.example / *.sample / *.template files are the intended case and are
# excluded. Measured across 130 repositories: this filter flags the 2 genuine
# offenders and none of the 7 distinct committed-template shapes.
#
# BOTH TESTS ARE SCOPED TO THE BASENAME, and the exclusion especially. Filtering
# the whole path silently dropped a real secret at `examples/audit.env`, because
# the directory carries the word: measured, `sierra/audit.env` was reported and
# `examples/audit.env` was not, from the same commit. examples/, test/samples/ and
# docs/templates/ are ordinary directory names, and this is the check whose entire
# job is finding the file nobody meant to commit.
#
# tolower() keeps the case-insensitivity the previous `grep -vi` had, so a
# committed `.env.EXAMPLE` is still treated as a template. It also makes the match
# side case-insensitive, which is the right default on a case-insensitive
# filesystem such as macOS's.
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if TRACKED=$(git -C "$CWD" ls-files 2>/dev/null); then
    TRACKED_ENV=$(printf '%s\n' "$TRACKED" \
      | awk -F/ '{ b = tolower($NF) }
                 (b ~ /^\.env/ || b ~ /\.env$/) && b !~ /example|sample|template/ { print }')
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
