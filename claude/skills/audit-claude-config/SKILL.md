---
name: audit-claude-config
description: Scan ~/.claude/ for accidentally stored secrets or PII
allowed-tools: Bash(gitleaks:*) Read Glob Grep
---

Audit the ~/.claude/ directory for sensitive data:

1. Run `gitleaks detect --source ~/.claude -v`
2. Grep memory files for: password=, api_key=, token=, secret=, Bearer, AWS_SECRET
3. Check settings.json files for hardcoded values (should use ${ENV_VAR} references)
4. Flag any memory files containing email addresses or phone number patterns
5. Report findings with file paths and line numbers, grouped by severity
