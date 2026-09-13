# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Browse Alias is a collection of tools for managing bash aliases in `~/.bashrc`:

1. **alias_manager.py** - A Textual TUI app for browsing, adding, editing, and deleting aliases
2. **ba** - A bash/fzf-based alias browser with quick actions (run, edit, add, remove)

## Development Commands

```bash
# Setup
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run the TUI
.venv/bin/python alias_manager.py
```

## Architecture

### alias_manager.py (Textual TUI)
- Uses Textual framework for terminal UI
- Parses aliases from `~/.bashrc` using regex pattern `^alias\s+([^=]+)=['\"]?(.+?)['\"]?\s*$`
- Modal screens for edit (`EditModal`) and delete confirmation (`ConfirmModal`)
- Keybindings: a=add, e=edit, d=delete, s=save, r=reload, q=quit
- Changes are batched in memory; must press 's' to save to disk

### ba (Bash/fzf tool)
- Designed to be sourced into shell: `source ~/code/browse_alias/ba`
- Provides `ba` function with subcommands: run, edit, add, rm (default: copy command)
- Uses fzf for interactive selection
