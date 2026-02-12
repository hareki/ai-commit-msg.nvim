# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Neovim plugin that auto-generates AI-powered commit messages when `git commit` opens COMMIT_EDITMSG. Supports multiple LLM providers (Gemini, OpenAI, Anthropic, GitHub Copilot) via curl-based HTTP calls through `vim.system()`.

## Commands

### Testing
```bash
make test              # Run integration tests (plenary.nvim busted)
```
Tests in `tests/` use plenary.nvim (auto-cloned to `/tmp/plenary.nvim`). Tests in `spec/` are standalone busted-style unit tests.

### Linting / Formatting
```bash
stylua --check lua/    # Check formatting
stylua lua/            # Fix formatting
```

## Code Style

- **Formatter**: StyLua — 120 col, 2-space indent, double quotes, Unix line endings (see `.stylua.toml`)
- **Module pattern**: Every file uses `local M = {} ... return M`
- **Type annotations**: LuaCATS/EmmyLua style (`---@class`, `---@field`, `---@param`)
- **Async pattern**: All HTTP/git calls use `vim.system(cmd, opts, callback)` — never blocking. UI updates from callbacks wrapped in `vim.schedule()`
- **No streaming**: API responses received in full, then parsed

## Architecture

### Entry Flow
1. **`plugin/ai-commit-msg.lua`** — Plugin loader: version guard (≥0.7.0), registers user commands (`:AiCommitMsg`, etc.)
2. **`lua/ai_commit_msg.lua`** — Public API: `setup(opts)` merges config, delegates to autocmds; also holds `calculate_cost()`/`format_cost()`
3. **`lua/ai_commit_msg/autocmds.lua`** — Registers `BufWinEnter` on `COMMIT_EDITMSG`: triggers generation, handles auto-push prompt logic
4. **`lua/ai_commit_msg/generator.lua`** — Runs `git diff --staged`, manages spinner UI, calls provider API, formats cost/duration notification
5. **`lua/ai_commit_msg/providers/init.lua`** — Routes `config.provider` string to the correct provider module
6. **`lua/ai_commit_msg/providers/{openai,anthropic,gemini,copilot}.lua`** — Each builds curl args, parses JSON response, extracts token usage, calls `callback(success, message, usage)`

### Provider Contract
All providers implement: check API key → build curl command → `vim.system()` → parse JSON → strip markdown fences → `callback(ok, msg, usage)`.

### Config System (`lua/ai_commit_msg/config.lua`)
- Defaults defined with LuaCATS annotations
- Provider configs nested under `providers.<name>` (each has `model`, `temperature`, `max_tokens`, `prompt`, `system_prompt`, `pricing`)
- Default provider is `"gemini"`, prompt template uses `{diff}` placeholder

### Prompt System (`lua/ai_commit_msg/prompts.lua`)
- `DEFAULT_SYSTEM_PROMPT` — Full Conventional Commits prompt with body formatting rules
- `SHORT_SYSTEM_PROMPT` — Single-line only, for tiny diffs

### Test Harness (`lua/ai_commit_msg/harness.lua`)
- `run_matrix()` — Benchmarks providers/models against `.diff` files, outputs JSONL
- `run_live_matrix()` — Same but for live staged diff (`:AiCommitMsgAllModels` command)
