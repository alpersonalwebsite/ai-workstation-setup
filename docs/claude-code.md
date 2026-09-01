# Claude Code config

Global instructions, skills, hooks, the status line, keeping it in a dotfiles
repo with Stow, cost visibility, and running two accounts side by side.

Part of the [AI Workstation](ai-workstation.md) setup notes.

## Claude Code settings

A couple of keys in `~/.claude/settings.json` are what actually keep sessions
resumable, which is the point of everything below.

```json
{
  "cleanupPeriodDays": 365,
  "tui": "fullscreen",
  "theme": "dark",
  "permissions": { "deny": ["Read(//**/.env*)", "Read(~/.ssh/**)", "..."] }
}
```

- **`cleanupPeriodDays: 365`** is the one that matters. Claude Code prunes
  on-disk session transcripts after this many days (default 30), and
  `claude --resume` / `--continue` can only reload a conversation while its
  transcript still exists. Raising it to a year means a project you set down for
  weeks is still resumable. Trade-off: transcripts sit on disk longer, so keep
  **FileVault** on (already recommended) since they are plaintext.
- **`tui: fullscreen`** runs the TUI full-screen; cosmetic.
- **`theme: dark`** picks the colour scheme, which pairs with the soft-dark
  terminal palette under [Terminal colors](workspace.md#terminal-colors). The settings
  reference documents the key, gives `"dark"` as the **default**, and lists
  `auto`, `dark`, `light`, `dark-daltonized`, `light-daltonized`, `dark-ansi`,
  `light-ansi`, plus a custom theme reference such as `custom:<slug>`. The `-ansi`
  pair is for 16-colour terminals and `-daltonized` for colour-vision deficiency.
  Since `dark` is already the default, setting it is explicitness rather than a
  change; `auto` is the one to use if you want it to follow the system appearance.
- **`attribution` is deliberately NOT set here**, and it is worth saying why, since
  an earlier version of this file shipped it. The key suppresses the AI-assistance
  trailer in commits and PR bodies. That is an editorial preference rather than a
  security property, and it is the one category this template keeps out: everything
  else here is security or reproducibility, and the voice skill ships as a skeleton
  for the same reason.

  The asymmetry decides it. Shipping the key means a reader who copies this file
  silently stops disclosing AI assistance, possibly against a project or employer
  policy, and the whole point of the setting is that nothing appears, so they may
  never notice. Leaving it out means a trailer shows up, which they see at once and
  can remove with three lines. Take the visible, recoverable error.

  So the choice stays with you, which is also what
  [`CLAUDE.example.md`](../claude/CLAUDE.example.md) says: decide your own policy
  and be consistent about it. If yours is "no trailer", add:

  ```json
  "attribution": { "commit": "", "pr": "", "sessionUrl": false }
  ```
- **`permissions.deny`** refuses whole classes of file outright, rather than
  prompting: the dotenv globs, `secrets/**`, `credentials.{json,yml,yaml}`, `*.pem`,
  `*.key`, `.npmrc`, plus the credential stores under `~` (`.ssh/**`,
  `.aws/credentials`, `.aws/sso/cache/**`, `.config/gh/hosts.yml`, `.netrc`,
  `.docker/config.json`, `.kube/config`), each denied for both `Read` and `Edit`.
  The full list is in
  [`claude/settings.example.json`](../claude/settings.example.json).

  **The patterns are anchored with `//`, and that matters more than it looks.** A
  bare pattern like `Read(.env*)` is resolved **relative to the directory the
  session started in**, so it covers that directory and everything under it and
  nothing above it. Start Claude in `repo/services/api` and a relative rule does
  not cover `repo/.env` one level up. Since this file is user-level settings
  (`~/.claude/settings.json`) rather than a per-project file, it should hold
  wherever you launch, so the entries use the `//` absolute anchor, which the
  permissions reference describes as matching anywhere on the filesystem. The `~`
  entries are already absolute and need no anchor.

  ⚠️ **Confirm this on your own machine rather than trusting the file.** Anchor
  syntax is the part of this most likely to be wrong after a version bump, and a
  deny rule that silently matches nothing looks exactly like one that works. From
  a subdirectory of a project that has a `.env` one or more levels up, ask Claude
  to read it: a refusal means the anchor is doing its job, and being shown the
  contents means it is not.

  **Two patterns are deliberately narrower than they look, for the same reason the
  substring globs are omitted below.** `credentials.{json,yml,yaml}` is named
  rather than a `credentials*` prefix, because `credentials.ts` and
  `credentials.service.ts` are ordinary auth-module filenames and a prefix glob
  would make them unreadable in every project with no prompt to override. That is
  the identical argument that keeps `**/*credential*` out of the list, so applying
  it to one shape and not the other would have been incoherent. The cost is real
  and worth naming: the named forms drop `credentials-prod.txt`, which is the very
  filename `validate-gitignore.sh` uses as one of its probes. The two lists are
  deliberately different, and this is one of the places that difference shows.
  `.npmrc` is filesystem-wide rather than home-only, because a project-level
  `.npmrc` carries `_authToken` exactly as the home one does.

  One collision is accepted rather than solved: `*.key` also matches Keynote
  documents, on the platform this setup targets. Denying a `.key` is close to free
  since a Keynote file is a binary bundle the Read tool cannot usefully show
  anyway, so the rule stays broad.

  ⚠️ **`.env*` matches more than `.env`, and `.envrc` is the one that will bite
  you.** `.env.example` is caught, which is mildly annoying; `.envrc` is direnv
  configuration that by convention holds no secret values and that a developer
  edits routinely, and it is now unreadable and unwritable in every project. That
  this setup knows the file is special makes the omission worse, not better:
  `security-audit` lists `*.envrc` as its own pathspec precisely because the other
  globs miss it. Measured in a real session with these deny rules:

  | how you reach the file | `block-secret-echo.sh` | deny rule |
  |---|---|---|
  | `Read` tool | pass | **denied** |
  | `cat .env.example` | pass | **denied** |
  | `sed -n 1p .env.example` | pass | **denied** |
  | `cp .env.example ref.txt` | pass | **denied** |
  | `python3 -c "print(open('.env.example').read())"` | pass | not denied, prompted |
  | `git show HEAD:.env.example` | pass | **succeeds** |
  | `cp .env.example .env` | pass | **denied** |
  | `printf 'A=1\n' > .env2` | pass | **denied** |
  | `git show HEAD:.env.example > .env3` | pass | **denied** |
  | `cat .envrc` | pass | **denied** |
  | `Read` tool on `.envrc` | pass | **denied** |
  | `printf 'x\n' >> .envrc` | pass | **denied** |

  So Bash is **not** an escape hatch: `cat` and `sed` are refused, which is what
  the limits below predict, and `cp` is refused as well even though it displays
  nothing. Read that table as the practical statement of what a deny rule means:
  everything the harness recognises as reaching the file is closed, and the only
  way through on the read side is `git show`, which reads the blob rather than the
  path, plus an indirect subprocess, which is the gap ranked worst below.

  **On the apparent contradiction with the limits list below**, which says to
  assume the shell path is open: both are correct and they answer different
  questions. The table is a **measurement** of the specific commands the
  permissions reference names, and those are closed. The list is a **posture**,
  and it is cautious because the reference's list is open-ended ("such as `cat`,
  `head`, `tail`, and `sed`"), so the next command you reach for may not be on it.
  Measured closed for what is named; treated as open because the naming is not
  exhaustive.

  **The `Edit` half closes creating a `.env` at all**, which is the part most
  likely to surprise you in daily use. `cp .env.example .env` is the normal way a
  project is set up, and under these rules it is refused, as is any redirect that
  writes the file, `git show … > .env` included. There is no route through: unlike
  the read side, `git show` does not help, because the refusal is on the write.
  **So create and edit your `.env` outside Claude** — and the same goes for
  `.envrc`, which is the case you are more likely to hit, since a direnv file gets
  edited as work proceeds rather than once at setup. If that trade is wrong for
  you, the narrower rule is to drop the `*` and deny `//**/.env` plus the specific
  suffixed names you use, at the cost of missing any name you forget. That is the
  gap the substring globs were omitted to avoid, in the other direction.

  That is the intended
  consequence rather than a gap, but it is worth knowing before you adopt the file
  and wonder why project setup stopped working.

  This cannot be patched with an exception: a deny rule carries no allowlist
  carve-out and deny is evaluated first, so an `allow` entry for `.env.example`
  would not win. The alternatives are enumerating real env filenames instead of
  globbing (brittle, unbounded) or accepting the asymmetry. This setup accepts it
  and points the remedy at `git show HEAD:.env.example`, which is also what
  `block-secret-echo.sh` now says when it refuses a command: an earlier wording
  recommended copying or inspecting the committed example, and this table is why
  that advice had to change.

  It resembles the `.gitignore` list and is **deliberately not the same list**, so
  do not sync the two mechanically. A gitignore pattern only decides what git
  tracks; a deny rule decides what can be read at all, so breadth that is free in
  one is expensive in the other. Three differences are load-bearing:

  - **Substring globs are omitted.** `**/*secret*`, `**/*token*`, `**/*password*`
    and `**/*credential*` are fine in a `.gitignore`. As deny rules they would
    block ordinary source files, `token_parser.ts` for instance, with no prompt to
    override.
  - **Every path is listed twice**, once as `Read(...)` and once as `Edit(...)`,
    because a `Read` deny rule does not cover `NotebookEdit`.
  - **The gh rule is narrowed.** A `.gitignore` can carry a bare `**/hosts.yml`;
    the deny rule names `~/.config/gh/hosts.yml` specifically, because `hosts.yml`
    is also an ordinary Ansible inventory filename and a bare-filename deny rule
    matches at any depth.

  So adding a pattern to your `.gitignore` is a prompt to *consider* the deny list,
  not to copy into it.

  ⚠️ **Know what this does not cover, or you will trust it too far.** These rules
  bind the built-in **`Read`** and **`Edit`** tools, and reach some shell commands
  besides. Three gaps, worst first:

  - **Indirect readers are explicitly out of scope, and this one is measured.** The
    reference states the rules do not apply to arbitrary subprocesses that read or
    write files themselves, a Python or Node script that opens a file being the
    example given, and points at the sandbox for OS-level enforcement. Confirmed in
    a real session: on a path where the `Read` tool, `cat`, `sed` and `cp` were all
    refused, `python3 -c "print(open('.env.example').read())"` was **not denied**,
    only prompted. So the deny list is not a barrier to a subprocess, it is a
    barrier to the paths the harness recognises.
  - **Shell commands are partially covered and the boundary is fuzzy.** The
    reference says deny rules apply to file commands Claude Code recognises in
    Bash, "such as `cat`, `head`, `tail`, and `sed`". That is an open example
    list, not an exhaustive one, so whether `grep` is included is **undocumented**
    rather than excluded. Either way the safe posture is the same: assume the
    shell path is open and do not rely on the deny list to close it.
  - **Extension rules miss extensionless files.** `*.pem` and `*.key` match on
    extension, so a key named `id_rsa` is covered only by the `~/.ssh/**` entry.

  The first two are exactly why `block-secret-echo.sh` runs as a `PreToolUse` hook
  on `Bash`: two independent controls, because neither covers the whole surface.

  This is a **deny** list only. The example file still sets no `permissions.allow`,
  for the reason given under [Claude Code config and skills](#claude-code-config-and-skills):
  a grant shipped without its reasoning is worse than no grant.

The hooks that enforce this posture (secret-scanning, gitignore validation) now
ship here too, along with a settings file that wires them, the status line, the
skills, and a subagent: see
[Claude Code config and skills](#claude-code-config-and-skills). What does not
ship is anything personal, my own instructions, examples, and memory, which is
also why the copies here are templates to adapt rather than a mirror of my
machine. Keeping your filled-in versions in a dotfiles repo is covered under
[Keep `~/.claude` in a dotfiles repo with GNU Stow](#keep-claude-in-a-dotfiles-repo-with-gnu-stow).

## Claude Code config and skills

Starting-point Claude Code config lives in [`../claude/`](../claude/), kept
separate from the shell and display config so it can grow as you add skills.
(For the `~/.claude/settings.json` keys that keep sessions resumable, see
[Claude Code settings](#claude-code-settings) above.)

**Copy or Stow, and it is worth choosing before you start.** Each bullet below
says "copy it to `~/.claude/...`", which is the quick way to try something. The
way this setup actually runs is
[GNU Stow](#keep-claude-in-a-dotfiles-repo-with-gnu-stow): the files live in a
git repo and Stow symlinks them into `~/.claude/`, so an edit is version-controlled
the moment you make it. Both end with the same paths in `~/.claude/`, so copying
first costs nothing except moving the same files twice. If you already know you
want the config tracked, read the Stow section first and come back.

**Then confirm it is live, rather than assuming.** A config file in the right
place with a typo in it fails silently:

```bash
# The status line: renders a bar, and needs jq.
echo '{"model":{"display_name":"Opus 5"},"context_window":{"used_percentage":12},"cost":{"total_cost_usd":0.42}}' \
  | ~/.claude/statusline.sh
# -> claude  [Opus 5]  ctx 12%  $0.42  (plus  ⎇ branch  inside a git repo)

# settings.json: valid JSON, status line wired, hooks registered.
python3 -m json.tool ~/.claude/settings.json > /dev/null && echo "settings.json parses"
jq -c '.statusLine' ~/.claude/settings.json      # {"type":"command","command":"~/.claude/statusline.sh",...}
jq -r '.hooks | keys[]' ~/.claude/settings.json  # PreToolUse, SessionStart, PostToolUse, Stop

# Most hooks need jq; block-secret-echo uses python3 and fails closed without it
# (a denied tool call); two also need gitleaks or they no-op silently.
command -v jq python3 gitleaks
```

Inside a session, `/doctor` checks the health of the install; `claude --help`
documents it for that. A skill that never fires is usually a `description` that
does not match what you asked for, or the manual-only flag described below.

- [`claude/CLAUDE.example.md`](../claude/CLAUDE.example.md) is a template for the
  global instructions Claude Code loads every session (writing voice, git
  hygiene, security, memory). It carries the `.example` suffix on purpose: a file
  literally named `CLAUDE.md` in this repo would be loaded as live directives for
  anyone working here. Copy it to `~/.claude/CLAUDE.md` and make the rules yours.
  This is the global config, distinct from the
  [per-project `CLAUDE.md`](#a-claudemd-per-project) that `initclaude` scaffolds.
- [`claude/statusline.sh`](../claude/statusline.sh) is a status-line script:
  Claude Code runs it every turn and it prints the launching command, model,
  context-window use, session cost, and git branch, which renders as:
  ```text
  claude-extension  [Opus 5 (1M context)]  ctx 31%  $26.09  ⎇ main
  ```
  The first field is the command that started the session: `claude` for a plain
  run, or the name of a wrapper, see
  [A second Claude Code account, side by side](#a-second-claude-code-account-side-by-side).
  Everything left of the branch is 60 characters at that model name, so the line
  above is 64 and a **31-character branch is the first to exceed 90**: two of the
  last ten branches merged in this repo would. The branch sits last, so the branch
  is what a narrow pane cuts; drop a field from the script if you work in narrow
  splits. Copy it to `~/.claude/statusline.sh`, `chmod +x`, and add
  the `statusLine` key to `settings.json` (see
  [Cost and usage visibility](#cost-and-usage-visibility)). jq only, no network.
- [`claude/settings.example.json`](../claude/settings.example.json) wires the
  hooks and the status line below, plus the three keys under
  [Claude Code settings](#claude-code-settings). Copy it to
  `~/.claude/settings.json`, or merge the parts you want into a file you already
  have. `.example` for the same reason as `CLAUDE.example.md`: a live
  `settings.json` in this repo would apply to anyone working here.
  It deliberately sets **no `permissions.allow`**, since a permission grant
  shipped without its reasoning is worse than no grant; see
  [Security notes](ai-workstation.md#security-notes) before adding any.
- [`claude/hooks/`](../claude/hooks/) holds five hook scripts. Hooks are where
  security posture stops being advice and starts being enforcement, since they run
  whether or not Claude decides to cooperate. Copy them to `~/.claude/hooks/`,
  `chmod +x`, and wire them with the settings file above.
  - `block-secret-echo.sh` (**PreToolUse** on Bash, Read and Grep) is the only
    hook that runs *before* a tool call, so it prevents disclosure rather than
    reporting it and **exits 2 to block**. It refuses commands that could print a
    credential: expanding or printing a secret-shaped variable, dumping the
    environment, a `ps` environment dump, or reading a shell profile or `.env`
    wholesale. It is name-shape based, so it never reads a value and a literal
    mention of a name (grep, docs, `.env.example`) is fine. Its two regression
    suites are in [`claude/hooks/tests/`](../claude/hooks/tests/).
  - `validate-gitignore.sh` (**SessionStart**) warns when the project's
    `.gitignore` is missing or lacks the patterns that keep secrets and build junk
    out of git. It strips comment lines first, so a comment mentioning `.env` does
    not satisfy the check for it.
  - `gitleaks-check.sh` (**PostToolUse** on Write and Edit) runs `gitleaks` on the
    file just written and **exits 2 to block** on a hit. Skips `.md`, `.toml` and
    lock files, where prose and pattern examples cause false positives.
  - `scan-claude-writes.sh` (**PostToolUse**) scans files written inside
    `~/.claude/` itself, since instructions and memory are a place secrets get
    pasted. Warn-only by default; the script says which line to change to block.
  - `check-uncommitted.sh` (**Stop**) warns at session end when the working tree
    has uncommitted changes, naming the repo and counting modified versus
    untracked. Never blocks.

  All five read their event JSON from stdin. Four parse it with **`jq`**;
  `block-secret-echo.sh` parses it with **`python3`** and, unlike the others,
  **fails closed** if its interpreter is missing (it denies the tool call rather
  than no-opping, since a secret guard that silently passes is worse than none).
  The two scanners need **`gitleaks`** and are guarded with `command -v`, so they
  no-op silently if it is absent. Exit code 2 is the blocking one:
  `gitleaks-check.sh` uses it on a real finding, and `block-secret-echo.sh` uses
  it to refuse a disclosing command.
- [`claude/skills/`](../claude/skills/) holds one folder per skill. Each is a
  `SKILL.md` that Claude invokes when a task matches its description, unless it
  opts out with `disable-model-invocation: true`. That opt-out is what **manual
  only** means below, and it is stronger than the name suggests, so read the note
  that follows the seven skills before copying them.
  - [`writing-voice`](../claude/skills/writing-voice/) captures your writing
    voice across professional and personal registers so drafts sound like you.
    It ships as a template.
  - [`fact-check`](../claude/skills/fact-check/) checks the technical claims in a
    diff, file, commit, or PR against the toolchain before you ship them, so
    unverified statements do not land in durable artifacts. Ready to use as-is:
    manual only, and unable to use the Write or Edit tools (`disallowed-tools`),
    though it can still run shell commands with your approval.
  - [`fill-claude-md`](../claude/skills/fill-claude-md/) fills or updates a
    folder-scoped `CLAUDE.md` from the folder's code, the session, and relevant
    memory, with guardrails (do not invent, verify counts and IDs, show the diff,
    then skim for accuracy and disclosure). Ready to use as-is: manual only.
  - [`rca`](../claude/skills/rca/) drafts an incident root-cause analysis in a
    finding / evidence / fix shape, separating measured from inferred and keeping
    hosts, clients, and incident detail out of anything committed. Manual only.
  - [`sync-config-docs`](../claude/skills/sync-config-docs/) checks whether the
    prose describing your config still matches the config, reporting content
    drift, undocumented files, and docs pointing at files that no longer exist.
    **Ships as a template**: fill in the two paths at the top first, and skip it
    entirely if you keep no separate documentation, since it would have nothing to
    compare.
  - [`security-audit`](../claude/skills/security-audit/) runs a hygiene pass over
    the current project: whether `.gitignore` covers the twelve patterns, a
    `gitleaks` scan, a grep for hardcoded credentials, and a check for sensitive
    files git is **already tracking**, which the gitignore rules cannot undo.
    Reports by severity with remediation. Ready to use as-is, and model-invocable
    rather than manual only.
  - [`audit-claude-config`](../claude/skills/audit-claude-config/) points the same
    idea at `~/.claude/` itself, looking for secrets or PII in memory files and
    settings, plus a `gitleaks` sweep of the whole directory that covers
    transcripts incidentally. Worth running before you push a dotfiles repo
    containing your Claude config anywhere public. Ready to use as-is,
    model-invocable.

  Those two are the only skills here that both run shell commands **and** can be
  invoked by Claude on its own, so their `allowed-tools` are scoped to the exact
  commands they need (`Bash(gitleaks:*)`, `Bash(git ls-files:*)`) rather than a
  bare `Bash`. That distinction is worth understanding before you write your own:
  `allowed-tools` **grants without prompting**, it does not restrict. A bare `Bash`
  on a model-invocable skill means Claude can decide to run the skill and then run
  any shell command inside it with no prompt. Check that line on every skill you
  copy from anyone, including this repo.

  Those last two are why the pattern list is worth keeping in one shape. The same
  twelve patterns appear in three places that **must** agree: the `.gitignore`,
  `validate-gitignore.sh`, and `security-audit`. Change one and change all three,
  or they drift into disagreeing about what counts as a secret. `permissions.deny`
  is a fourth, closely related list that is deliberately **not** a member of that
  set, for the reasons under [Claude Code settings](#claude-code-settings).

  **What "manual only" actually does.**
  Four of the seven skills above carry `disable-model-invocation: true`:
  `fact-check`, `fill-claude-md`, `rca` and `sync-config-docs`. The name reads as
  though it only suppresses *automatic* loading, leaving a deliberate call
  available. It does not. Measured against the loader on Claude Code 2.1.226 with
  two throwaway skills, one flagged and one not:

  | what happens | result |
  |---|---|
  | Asked in prose to use both skills | only the **unflagged** one loads |
  | User types the slash command | the flagged one loads |
  | A model-initiated call, *same session*, after the user already invoked it | **refused** |

  The refusal reads, in full:

  > Skill `<name>` cannot be used with Skill tool due to
  > disable-model-invocation. Ask the user to run `/<name>` themselves — it cannot
  > be invoked via the Skill tool. Do not replicate this skill's workflow by other
  > means — it is reserved for explicit user invocation.

  (Quoted verbatim, so the two em dashes are the tool's own. A style sweep should
  leave them alone.) So the flag blocks the tool call unconditionally, and an
  earlier invocation by the user does not unlock it for the rest of the session.
  Typing `/<name>` is the only way in. Note the last sentence: the intended
  response to the refusal is to ask for the slash command, not to reproduce the
  skill's steps by hand.

  That is the intent for these four, since each is a moment to choose rather than a
  condition to detect: a pre-ship fact check, a `CLAUDE.md` fill, an incident
  write-up, a docs drift check. `writing-voice` carries no flag, so it applies
  whenever a task matches its description, which is the point of a voice skill.

  Two practical consequences. Delete the line from any of the four to make it
  model-invocable. And if a session reports that it *cannot* run one of these, that
  is the flag working rather than a broken setup, so the answer is to type the
  slash command rather than to have the session work around it. Working around it
  also skips the skill's own `allowed-tools` and `disallowed-tools`, which bind an
  invocation rather than the file's text.
- [`claude/agents/`](../claude/agents/) holds subagents: workers Claude delegates
  to that run in their own context and return a summary. The one here,
  [`code-reviewer`](../claude/agents/code-reviewer.md), reviews a diff or PR for
  real defects (correctness and security first, then your `CLAUDE.md` standards),
  on Sonnet. It is read-only for writes, enforced by `permissionMode: plan`, but
  that gates writes, not egress: `Bash` and `WebFetch` stay active, so an injected
  instruction in an untrusted diff could try to exfiltrate through a fetch. The
  gate there is `WebFetch`'s per-domain approval prompt (it is not pre-approved),
  so when reviewing an untrusted PR, check the domain before approving a fetch and
  do not run it from a permission-bypassing session. Copy it into
  `~/.claude/agents/`.

To install a skill, fill in any bracketed placeholders first (`writing-voice` and
`sync-config-docs` are templates to complete; `fact-check`, `fill-claude-md` and
`rca` are ready as-is), then
copy the folder into `~/.claude/skills/`. A template copied with its placeholders
still matches its description, so Claude would load the empty prompts as
guidance, which is worse than not having the skill at all. Both your
`~/.claude/CLAUDE.md` and the skills are good candidates for a dotfiles repo so
they restore on a new machine. The next section is how to do that without copying
anything twice.

### Keep `~/.claude` in a dotfiles repo with GNU Stow

Copying these files into `~/.claude/` works once. The problem is the second
machine, and the fact that `~/.claude/` is where you will keep editing them, so
the copy in your repo goes stale the moment you tune a skill in place.

[GNU Stow](https://www.gnu.org/software/stow/) fixes that by inverting it: the
files live in a git repo and Stow **symlinks** them into `~/`. You edit
`~/.claude/CLAUDE.md`, you are editing the file in the repo, so `git status` sees
it and a new machine is one `stow` away.

```bash
brew install stow
mkdir -p ~/dotfiles/claude
```

Inside the repo, mirror the path the files should take **relative to your home
directory**. That mirroring is the whole trick, Stow reads the directory layout as
the install plan:

```text
~/dotfiles/                 <- a git repo
└── claude/                 <- one "package", named for what it configures
    └── .claude/            <- becomes ~/.claude/
        ├── CLAUDE.md
        ├── settings.json
        ├── statusline.sh
        ├── agents/
        ├── hooks/
        └── skills/
```

Then link it, from the directory that holds the packages:

```bash
cd ~/dotfiles
stow --target="$HOME" claude      # creates the symlinks
stow --target="$HOME" --delete claude   # removes them again
stow --target="$HOME" --restow claude   # after adding new files
```

`--target="$HOME"` is worth passing explicitly. Stow defaults to the *parent* of
the current directory, which is `$HOME` only when the repo sits directly in your
home directory; being explicit means the command behaves the same wherever the
repo lives.

Things worth knowing before you commit to it:

- **Stow refuses to clobber a real file.** If `~/.claude/CLAUDE.md` already
  exists as a regular file, stowing aborts rather than overwriting: *"cannot stow
  ... over existing target ... since neither a link nor a directory and --adopt
  not specified. All operations aborted."* Move your existing config into the
  package first, then stow. `--adopt` exists and does the opposite of what the
  name suggests you want: it pulls the existing file **into your repo**,
  overwriting the repo's version with the one from `~/`. Useful for the initial
  migration, destructive if you reach for it to resolve a conflict later.
- **It folds directories.** If `~/.claude/` does not exist, Stow may symlink the
  whole directory rather than each file in it, which is tidier but means a tool
  writing a *new* file into `~/.claude/` writes it into your repo. That is usually
  what you want here, and it is why `git status` catches config Claude Code adds
  on its own.
- **Not everything belongs in the package.** `~/.claude/projects/` holds session
  transcripts and auto-memory, which are machine-local and often contain pasted
  detail you would not commit. Keep them out, and make sure the repo's
  `.gitignore` says so.
- **The repo is as public as you make it.** A dotfiles repo holding Claude
  instructions, hooks and skills is fine to keep private, and it costs nothing to
  do so. If you publish it, read every file first: instructions accumulate
  examples, and examples accumulate real names, hosts and paths.
- **One package or many.** `claude/` beside `zsh/`, `git/`, `ssh/` keeps each tool
  separable, so you can stow only what a given machine needs.

### Cost and usage visibility

Claude Code charges by token, and there is no `/cost` command, but you can see
spend with no third-party tool for the common cases:

- **Live:** the status line (`claude/statusline.sh`, above) shows the running
  session cost and context use every turn. Wire it up in `~/.claude/settings.json`:

  ```json
  {
    "statusLine": {
      "type": "command",
      "command": "~/.claude/statusline.sh",
      "padding": 2
    }
  }
  ```

  It reads the session JSON Claude Code pipes on stdin (`model.display_name`,
  `context_window.used_percentage`, `cost.total_cost_usd`) and needs only `jq`.
  The leading field is not from that JSON: it names the command that started the
  session, `claude` or a wrapper such as `claude-extension`. See
  [A second Claude Code account, side by side](#a-second-claude-code-account-side-by-side)
  for how a wrapper labels itself.
- **Session, day, week:** `/usage`. It shows the session's token use and a
  locally-estimated cost, and on a subscription plan (Pro, Max, Team, Enterprise)
  a 24h/7d plan-usage breakdown (press `d` / `w`). On API-key auth you get the
  session cost figure but no plan bars. The figures come from local session
  history on this machine only, not other devices or claude.ai.
- **Month and longer:** not covered natively.
  [`ccusage`](https://github.com/ccusage/ccusage) (MIT, zero-dependency) reads the
  same local `~/.claude` logs and aggregates by day, week, month, and session.
  Install a pinned version and run it `--offline` (embedded pricing, no outbound
  request) to keep it company-safe:

  ```bash
  npm i -g ccusage@20.0.19   # current pin; check for a newer release first
  ccusage monthly --offline
  ```

The cost figure everywhere is a client-side estimate at list rates, so it does
not reflect promotional or contracted pricing and is not your bill.

## A second Claude Code account, side by side

Running two Claude Code accounts at once (two seats, or a work login and a
personal one) works by giving the second account its own config directory via the
`CLAUDE_CONFIG_DIR` environment variable. This is the documented, supported path:
the environment-variable reference describes it as overriding the configuration
directory, with "all settings, session history, and plugins" stored under it, and
names running multiple accounts side by side as the use case. Credentials follow
the config dir on Linux and Windows; on macOS they live in the system Keychain,
where each config dir gets its own item, which is what keeps the two logins from
clobbering each other. One detail is not documented and was worked out here: the
**naming of that per-config-dir Keychain item** (the hash below).

**Get the variable name right.** It is `CLAUDE_CONFIG_DIR`. Do not guess
`CLAUDE_CODE_CONFIG_DIR`: the `CLAUDE_CODE_` prefix is the house style for most of
Claude Code's other variables, so the wrong name looks plausible, and it fails
silently rather than erroring, leaving both accounts on one login. Tested on build
2.1.222 by pointing each at an empty directory and running `claude mcp list`:
`CLAUDE_CONFIG_DIR` populated it, `CLAUDE_CODE_CONFIG_DIR` left it empty. If a
config dir ever stops being picked up, re-run that comparison before debugging
anything else. It tests which variable selects the config directory, which is the
step the account isolation rests on, not the isolation itself:

```bash
for v in CLAUDE_CONFIG_DIR CLAUDE_CODE_CONFIG_DIR; do
  d=$(mktemp -d); env "$v=$d" claude mcp list >/dev/null 2>&1
  printf '%s -> %s entries\n' "$v" "$(ls -A "$d" | wc -l | tr -d ' ')"; rm -rf "$d"
done
```

Expect a nonzero count for `CLAUDE_CONFIG_DIR` and zero for the other. Two
nonzero counts would mean the wrong name started working; two zeros mean neither
does, and the wrapper needs a different approach.

1. **Create the config dir.**
   ```bash
   mkdir -p "$HOME/.claude-extension"
   ```
2. **Link your existing config in.** A fresh config dir is empty, so none of your
   CLAUDE.md, settings, skills, hooks, or agents apply until you link them. Point
   each at your primary `~/.claude` config (adjust the list to what you actually
   have):
   ```bash
   cd "$HOME/.claude-extension"
   for f in CLAUDE.md settings.json agents hooks skills statusline.sh; do
     ln -sfn "$HOME/.claude/$f" "$f"
   done
   ```
   If your `~/.claude` config is itself symlinked from a dotfiles repo, point these
   at the dotfiles source directly to avoid a two-hop chain through `~/.claude`;
   either resolves the same.
3. **(Optional) Share sessions and memory.** Link `projects/` (session transcripts
   and auto-memory) and `file-history/` so both accounts see the same history. Do
   this **before** first launching the second account, or it creates real dirs
   there and the link fails:
   ```bash
   ln -sfn "$HOME/.claude/projects"     "$HOME/.claude-extension/projects"
   ln -sfn "$HOME/.claude/file-history" "$HOME/.claude-extension/file-history"
   ```
   **Only if both accounts are yours, in the same trust boundary.** Sharing
   `projects/` shares every session transcript and all auto-memory across both
   logins. Across a **work** seat and a **personal** one that leaks each org's
   context into the other; in that case skip this step and let the second account
   keep its own history.
4. **Use the shell wrapper.** `config/claude-proj.zsh` already ships a
   `claude-extension` function alongside `proj` and `initclaude`, so `setup.sh`
   installs it for you:
   ```bash
   claude-extension() {
     CLAUDE_LAUNCHER=claude-extension \
     CLAUDE_CONFIG_DIR="$HOME/.claude-extension" claude "$@"
   }
   ```
   Open a new shell (or re-source your zsh config) to pick it up. Keeping it in
   that tracked file, rather than an untracked `~/.zshrc`, is what makes it
   restore on a new machine. Use an **absolute path** (`$HOME/...` expands to one);
   do not pass a literal quoted `"~/..."`. The raw string is hashed into the
   keychain service name, so an inconsistent value across shells points at a
   different keychain item and forces a re-login.

   `CLAUDE_LAUNCHER` is not a Claude Code variable, it is the label
   [`claude/statusline.sh`](../claude/statusline.sh) prints as the status line's
   first field, so a glance at the bar says which account the session is on. Both
   accounts run the same binary and the wrapper is a shell function rather than
   its own process, so nothing in the process tree or `$0` distinguishes them;
   the wrapper has to tag itself. The status-line script is a child of the
   session process and therefore sees the session's environment. A session
   started through the wrapper renders `claude-extension  [<model>]  ctx …`, and
   a plain `claude` renders `claude  [<model>]  ctx …`.

   Set `CLAUDE_LAUNCHER` in any other wrapper you add. If you forget, the script
   falls back to deriving the label from `CLAUDE_CONFIG_DIR`, which a
   second-account wrapper sets anyway: `$HOME/.claude-extension` gives
   `claude-extension`, and unset or `$HOME/.claude` gives `claude`. The fallback
   exists because forgetting the tag otherwise fails in the direction that looks
   correct, printing `claude` for a session that is not one. It labels the
   **config dir** rather than the command, so two wrappers sharing one dir stay
   indistinguishable; the explicit tag is what separates those, and wins whenever
   both are set.

   Both signals come from the environment, and nothing in the documentation
   promises that Claude Code passes the session environment to the `statusLine`
   command. If a future build sanitizes it, the field degrades to printing
   `claude` everywhere, which looks exactly like it working. If the label ever
   stops tracking the account, suspect that before suspecting your wrapper.
5. **Log in the second account.**
   ```bash
   claude-extension auth login
   ```
   Browser flow. Your existing `~/.claude` login is untouched: it uses the
   keychain item `Claude Code-credentials`, while this one uses
   `Claude Code-credentials-<hash>`, where `<hash>` is the first eight hex digits
   of the sha256 of the config dir's absolute path. Compute yours:
   ```bash
   printf '%s' "$HOME/.claude-extension" | shasum -a 256 | cut -c1-8
   ```
6. **Verify both are live.**
   ```bash
   claude auth status --text            # account A
   claude-extension auth status --text  # account B, a different email
   ```
   Both should report logged in (`claude.ai`, not `api_key`) with different
   emails. To confirm the two keychain items coexist (attributes only, no secret
   printed), reuse the computed hash so the lookup is copy-paste runnable:
   ```bash
   hash=$(printf '%s' "$HOME/.claude-extension" | shasum -a 256 | cut -c1-8)
   security find-generic-password -s "Claude Code-credentials"
   security find-generic-password -s "Claude Code-credentials-$hash"
   ```
7. **Use them together**, from the same project in two terminals:
   ```bash
   claude              # account A
   claude-extension    # account B, at the same time
   ```

**Gotchas**

| Issue | Detail |
|---|---|
| Auth env vars | `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, and `CLAUDE_CODE_OAUTH_TOKEN` each take precedence over the seat login (documented order), so if any is set, in your shell **or** in the shared `settings.json` `env` block, **both** accounts use it and the split does nothing. Keep them out of the shared `settings.json`, and check non-destructively with `env -u ANTHROPIC_API_KEY claude auth status --text` (expect `claude.ai`, not `api_key`). |
| Trust dialog | `.claude.json` is per config dir, so the second account re-accepts the trust prompt and rebuilds its own allowed-tools, one prompt per project. |
| Same session in both | If you shared `projects/`, do not resume the same session id from both accounts at once: two processes appending one `.jsonl` interleave and corrupt it. Different sessions in the same project are fine. |
| `history.jsonl` | Up-arrow prompt history, and it spans all projects, so link it only if you accept sharing every project's prompt history across accounts. |

If the isolation ever breaks after an upgrade (one login replacing the other),
`claude auth status` on each wrapper is how you catch it. For a scripted or CI
login instead of the browser flow, `claude setup-token` prints an OAuth token you
set as `CLAUDE_CODE_OAUTH_TOKEN`.

## A `CLAUDE.md` per project

- **What it's for:** A memory file the assistant loads automatically every
  session, holding decisions, current state, and TODOs. Update it at the end of
  a session (prompt below) and the project is still resumable three weeks later.
- **Replaces/changes:** Replaces scrolling old chat history to reconstruct what
  was done and why. This, more than tmux, is what makes long-running projects
  work.
- **Per folder, not per repo:** Claude Code loads `CLAUDE.md` by directory, so
  the file lives in the folder you work in (where `initclaude` writes it). Keep a
  subfolder file about that component's specifics; do not restate the whole repo.
  Three behaviors matter (all in the Claude Code memory docs):
  - **Stacking depends on where you launch.** Launch in the subfolder
    (`proj <subfolder>`) and its file loads at startup on top of any at the repo
    root. Launch at the repo root and the subfolder file is on-demand: it loads
    only when Claude reads a file down there.
  - **Subfolder files do not survive `/compact`.** A root `CLAUDE.md` is
    re-injected after compaction; a nested one is not. It reloads only the next
    time Claude reads a file in that subfolder. In the long sessions this page is
    built around, a subfolder file can quietly stop applying mid-session.
  - **Confirm what loaded** with `/context`, then check the list under Memory
    files. That is the check for "did my CLAUDE.md actually load."

### Prompts to fill it

Used by the flows in [Project workflow](terminal.md#project-workflow). The prompt, its
guardrails (folder-scoped, do not invent, verify counts and IDs, show the diff
first), and the after-writing accuracy and disclosure skim now live in the
`/fill-claude-md` skill (`claude/skills/fill-claude-md/SKILL.md`), so filling a
CLAUDE.md is one command instead of a pasted paragraph:

- **Fresh or existing folder:** run `/fill-claude-md` in the folder to populate
  the template from its code, this session, and relevant memory.
- **Ongoing project:** run `/fill-claude-md` at the end of a session to fold in
  what changed. It builds up as you work.
