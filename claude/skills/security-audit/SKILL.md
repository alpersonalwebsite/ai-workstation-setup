---
name: security-audit
description: Full security hygiene check: gitignore, secrets, sensitive files
allowed-tools: Bash(gitleaks:*) Bash(git ls-files:*) Bash(git check-ignore:*) Read Grep Glob
---

Run a full security audit on the current project:

1. Check .gitignore exists and covers: .env*, *.env, *.log, *.key, *.pem,
   secrets/, credentials*, node_modules/, __pycache__/, .DS_Store, *.sqlite, *.db
   Both env globs, since `.env*` misses `audit.env` and `*.env` misses `.envrc`.

2. Run `gitleaks detect --source . -v` if gitleaks is installed

3. Search for hardcoded secrets in tracked files. Grep for:
   password=, api_key=, secret=, token=, AWS_SECRET, private_key, Bearer

4. Check for sensitive files already tracked by git. `.gitignore` never untracks,
   so a file committed before the pattern existed stays in the tree and in history:

   ```
   git ls-files -- '*.env*' '*.key*' '*.pem*' '*.secret*' \
     ':(exclude)*.example' ':(exclude)*.sample' ':(exclude)*.template'
   ```

   Each pattern matches its name anywhere in the path, the same set the older
   `ls-files`-into-`grep` form matched: `server.key.bak`, `cert.pem.old`,
   `app.keystore`, `.envrc`, `.secrets.json` and `config/db.secret.yml` are all
   caught. Exact endings (`*.key`, `*.pem`) missed the first three and the last
   two (found in review, 2026-10-18). The three excludes
   drop `.env.example`, `.env.sample` and `.env.template`, which are meant to be
   tracked; without them every project reports its own committed template as a
   finding.

   Use git's pathspec matching rather than piping `ls-files` into `grep`. A
   `grep -E '\.env...'` pipeline is refused by `block-secret-echo.sh`, which this
   same setup wires as a PreToolUse hook: `grep` sits at command position and the
   pattern carries the `.env` shape, so the guard reads it as a command that could
   print an env file. It is a false positive (the pipe means `grep` reads stdin,
   not a file) but the effect is a skill that cannot run its own step.

   Note `*.key*` also matches Keynote documents (`.key`, `.keynote`) on macOS, so
   treat a `.key` hit as something to look at rather than a finding on its own.

5. Report findings grouped by severity (critical / warning / info) with
   specific remediation steps for each finding
