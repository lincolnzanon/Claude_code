# Claude_code

Portable global setup for Claude Code (and compatible AI coding assistants).

## Purpose

This repo is the **single source of truth** for my global Claude Code setup — commands,
skills, scripts, and hooks. The goal: on a new device or in a brand-new codebase, I can pull
this repo and instantly have all the skills, commands, and tooling I rely on, with no manual
reconstruction.

## Convention (important)

> **Any change to the global Claude Code setup gets committed and pushed to this repo.**

Whenever something under `~/.claude/` (commands, skills, hooks, settings) or a global helper
script (e.g. `~/.local/bin/begin-session`) is added or changed, that change must be synced
into this repo, committed, and pushed. That is what keeps this repo authoritative and makes
"bootstrap anywhere" actually work. If the change lives only on one machine, it's lost.

## What's inside — and where it maps

| Repo path                | Live location on a machine      |
| ------------------------ | ------------------------------- |
| `.claude/commands/`      | `~/.claude/commands/`           |
| `skills/`                | `~/.claude/skills/`             |
| `Hooks/`                 | `~/.claude/hooks/`              |
| `scripts/begin-session`  | `~/.local/bin/begin-session`    |

## Bootstrap on a new machine

```bash
git clone https://github.com/lincolnzanon/Claude_code.git
cd Claude_code

# Commands, skills, hooks
mkdir -p ~/.claude/commands ~/.claude/skills ~/.claude/hooks
cp -r .claude/commands/* ~/.claude/commands/
cp -r skills/*           ~/.claude/skills/
cp -r Hooks/*            ~/.claude/hooks/

# Global scripts
mkdir -p ~/.local/bin
cp scripts/begin-session ~/.local/bin/begin-session
chmod +x ~/.local/bin/begin-session
# ensure ~/.local/bin is on your PATH
```

After that, restart Claude Code and the skills/commands are available.
