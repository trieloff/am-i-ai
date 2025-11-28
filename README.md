# am-i-ai - AI Coding Agent Detection Library

[![Part of AI Ecoverse](https://img.shields.io/badge/AI-Ecoverse-blue?style=for-the-badge)](https://github.com/trieloff/ai-ecoverse)

A lightweight, portable shell library for detecting whether code is being executed by an AI coding agent. Used by [ai-aligned-git](https://github.com/trieloff/ai-aligned-git) and [ai-aligned-gh](https://github.com/trieloff/ai-aligned-gh) to provide proper AI attribution.

## Why?

AI coding agents like Claude Code, Gemini, Cursor, and others are increasingly common in development workflows. Detecting when code is running under AI control enables:

- **Proper attribution**: Ensure AI-generated commits are attributed correctly
- **Safety guardrails**: Prevent dangerous operations when AI is in control
- **Transparency**: Track AI involvement in your codebase
- **Different behaviors**: Apply different policies for human vs AI execution

## Quick Start

### As a Script

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/trieloff/am-i-ai/main/am-i-ai.sh -o am-i-ai.sh
chmod +x am-i-ai.sh

# Detect current AI
./am-i-ai.sh
# Output: "claude" (or "none" if not AI)

# Check if AI (exit code 0 = AI, 1 = not AI)
if ./am-i-ai.sh --check; then
    echo "Running under AI control"
fi

# Debug mode to see detection logic
./am-i-ai.sh --debug
```

### As a Library

```bash
# Source the library
source /path/to/am-i-ai.sh

# Simple check
if ami_is_ai; then
    echo "AI detected: $(ami_detect)"
fi

# Get AI tool information
AI_TOOL=$(ami_detect)
if [ "$AI_TOOL" != "none" ]; then
    echo "Name: $(ami_get_name $AI_TOOL)"
    echo "Email: $(ami_get_email $AI_TOOL)"
fi

# See all detected AIs (when multiple tools are nested)
ami_detect_all
```

## Supported AI Tools

| Tool | Detection Method | Environment Variable |
|------|------------------|---------------------|
| [Claude Code](https://claude.ai/claude-code) | Process + env | `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT` |
| [Gemini](https://codeassist.google/) | Process + env | `GEMINI_CLI` |
| [Codex CLI](https://openai.com) | Process + env | `CODEX_CLI`, `CODEX_SANDBOX` |
| [Cursor](https://cursor.com) | Process + env | `CURSOR_AI` |
| [Aider](https://aider.chat) | Process + env | `OR_APP_NAME=Aider` |
| [Amp](https://ampcode.com) | Process + env | `AGENT=amp`, `AMP_HOME` |
| [Qwen Code](https://qwen.ai) | Process + env | `QWEN_CODE` |
| [Droid](https://factory.ai) | Process + env | `DROID_CLI` |
| [OpenCode](https://opencode.ai) | Process + env | `OPENCODE_AI` |
| [Zed AI](https://zed.dev) | Process + env | `ZED_ENVIRONMENT`, `ZED_TERM` |
| [GitHub Copilot](https://copilot.github.com) | Process + env | `GITHUB_COPILOT_CLI_MODE` |
| [Kimi CLI](https://kimi.com) | Process + env | `KIMI_CLI` |
| [OpenHands](https://openhands.ai) | Process + env | `OR_APP_NAME=OpenHands`, `OR_SITE_URL` |
| [Crush](https://charm.sh/tools/crush/) | Process only | (detected via process tree) |
| [Goose](https://github.com/block/goose) | Process + env | `GOOSE_TERMINAL` |
| [Cline](https://cline.bot) | Process + env | `CLINE_TASK_ID` |
| [Roo Code](https://roocode.dev) | Process + env | `ROO_CODE_TASK_ID` |
| [Windsurf](https://codeium.com/windsurf) | Process + env | `WINDSURF_SESSION` |

## Detection Methods

### Two-Phase Detection

am-i-ai uses a robust two-phase detection approach:

1. **Phase 1: Environment Variables** - Fast check for AI-specific environment variables
2. **Phase 2: Process Tree** - Walk up the process tree looking for AI tool signatures

This ensures reliable detection even when AI tools don't set environment variables.

### Zed AI Special Handling

Zed presents a unique challenge because it sets environment variables for all terminals, not just AI-controlled ones. am-i-ai distinguishes between:

- **Human via git panel**: `ZED_ENVIRONMENT` set, `SHLVL=1`, no terminal vars
- **Human via terminal**: Parent process is an interactive shell (bash, zsh, etc.)
- **Zed AI agent**: `ZED_ENVIRONMENT` set, `SHLVL>1`, parent is NOT an interactive shell

### Priority Order

When multiple AI tools are detected (e.g., Claude running inside Cursor), the more specific tool takes precedence:

```
Amp > Codex > Aider > Claude > Gemini > Qwen > Droid > OpenCode >
Cursor > Copilot > Kimi > OpenHands > Cline > Roo > Windsurf >
Crush > Goose > Zed
```

## API Reference

### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `ami_detect` | Detect highest-priority AI tool | Tool name or "none" |
| `ami_is_ai` | Check if any AI is detected | Exit code 0/1 |
| `ami_detect_all` | Get all detected AI tools | Space-separated list |
| `ami_get_name` | Get display name for tool | Human-readable name |
| `ami_get_email` | Get email for tool | Email address |
| `ami_check_env` | Run environment detection only | Space-separated list |
| `ami_check_ps_tree` | Run process tree detection only | Space-separated list |
| `ami_process_contains` | Check if process matches pattern | Exit code 0/1 |
| `ami_version` | Print version info | Version string |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AMI_DEBUG` | Enable debug output | `false` |

## Installation

### Manual Download

```bash
curl -fsSL https://raw.githubusercontent.com/trieloff/am-i-ai/main/am-i-ai.sh \
    -o ~/.local/lib/am-i-ai.sh
```

### With install script

```bash
curl -fsSL https://raw.githubusercontent.com/trieloff/am-i-ai/main/install.sh | sh
```

### For Projects

Add as a git submodule or copy the file directly:

```bash
# Submodule
git submodule add https://github.com/trieloff/am-i-ai.git vendor/am-i-ai

# Or direct download
curl -fsSL https://raw.githubusercontent.com/trieloff/am-i-ai/main/am-i-ai.sh \
    -o lib/am-i-ai.sh
```

## Testing

```bash
# Test environment variable detection
CLAUDECODE=1 ./am-i-ai.sh
# Output: claude

# Test with debug output
AMI_DEBUG=true GEMINI_CLI=1 ./am-i-ai.sh
# Shows detailed detection process

# Test all detection
CLAUDECODE=1 CURSOR_AI=1 ./am-i-ai.sh --all
# Output: claude cursor
```

## Adding New AI Tools

To add detection for a new AI tool:

1. Identify the environment variables and/or process names
2. Add detection in `ami_check_env()` for environment variables
3. Add detection in `ami_check_ps_tree()` for process tree
4. Add the tool to priority order in `ami_detect()`
5. Add name and email in `ami_get_name()` and `ami_get_email()`
6. Submit a pull request

## Related Projects

Part of the **[AI Ecoverse](https://github.com/trieloff/ai-ecoverse)** - tools for AI-assisted development:

- **[ai-aligned-git](https://github.com/trieloff/ai-aligned-git)** - Git wrapper for safe AI commits (uses am-i-ai)
- **[ai-aligned-gh](https://github.com/trieloff/ai-aligned-gh)** - GitHub CLI wrapper for AI attribution (uses am-i-ai)
- **[yolo](https://github.com/trieloff/yolo)** - AI CLI launcher with worktree isolation
- **[as-a-bot](https://github.com/trieloff/as-a-bot)** - GitHub App token broker
- **[vibe-coded-badge-action](https://github.com/trieloff/vibe-coded-badge-action)** - AI contribution badges
- **[gh-workflow-peek](https://github.com/trieloff/gh-workflow-peek)** - GitHub Actions log filtering
- **[upskill](https://github.com/trieloff/upskill)** - Install Claude/Agent skills

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
