---
name: security-audit
description: Full security hygiene check: gitignore, secrets, sensitive files
allowed-tools: Bash Read Grep Glob
---

Run a full security audit on the current project:

1. Check .gitignore exists and covers: .env*, *.env, *.log, *.key, *.pem,
   secrets/, credentials*, node_modules/, __pycache__/, .DS_Store, *.sqlite, *.db
   Both env globs, since `.env*` misses `audit.env` and `*.env` misses `.envrc`.

2. Run `gitleaks detect --source . -v` if gitleaks is installed

3. Search for hardcoded secrets in tracked files. Grep for:
   password=, api_key=, secret=, token=, AWS_SECRET, private_key, Bearer

4. Check for sensitive files already tracked by git:
   `git ls-files | grep -E '\.env|\.key|\.pem|\.secret'`

5. Report findings grouped by severity (critical / warning / info) with
   specific remediation steps for each finding
