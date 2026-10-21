---
name: commits
description: >
  Commit conventions and workflow for git. Use whenever the user asks to commit, stage and commit,
  or save changes. Commits each changed file separately with a conventional-style message.
  Never pushes.
---

This skill defines how commits are made. Follow it exactly. Do NOT run `git log` to discover
the style; the conventions are stored here.

## Workflow

1. Run `git status --short` to list changed files.
2. For each file, one at a time:
   1. Read its diff (`git diff -- <file>`, or the file itself if untracked).
   2. Stage only that file: `git add -- <file>`.
   3. Commit only that file: `git commit -m "<message>" -- <file>`.
3. Run `git log --oneline -n <count>` at the end to show what was created.

Rules:
- One file per commit. Never use `git add .`, `git add -A`, or `git commit -a`.
- Never run `git push`, `git push --force`, or anything that touches a remote.
- Never amend, rebase, reset, or rewrite history unless explicitly asked.
- Never use `--no-verify`. If a hook fails, fix the cause and make a new commit.
- Only commit files that changed in this session or that the user asked for. Skip files that look
  like secrets (`.env`, keys, credentials) and tell the user.
- Skip large binaries (executables, archives, images over ~1MB) and tell the user instead of
  committing them.
- If a file was renamed, stage both paths and commit them together as one commit.

## Message format

```
<type>: <description>
```

- Single line only. No body, no footer, no scope, no trailing period.
- Type is lowercase, followed by a colon and one space.
- Description is lowercase, short (aim for under 60 characters), and says what changed.
- Use the same verb tense consistently: past tense for removals/cleanups ("removed ..."),
  imperative for additions ("set ...", "add ..."). Prefer imperative when unsure.
- Base the message on the actual diff of that file, not on the filename alone.

## Types

| Type       | Use for                                                    |
|------------|------------------------------------------------------------|
| `feat`     | New feature, new config option, new shortcut, new script   |
| `fix`      | Bug fix or correcting broken behavior                      |
| `chore`    | Maintenance: removing/adding plugins, deps, cleanup, tooling |
| `docs`     | README or documentation-only changes                       |
| `refactor` | Restructuring without behavior change                      |
| `style`    | Formatting or whitespace only                              |
| `perf`     | Performance improvements                                   |
| `test`     | Adding or changing tests                                   |

The first commit of a repo is exactly `initial commit`.

## Examples

```
feat: set workspace switching shortcuts
chore: removed claude auth plugin
docs: add stow usage to readme
fix: correct tmux pane resize width
```
