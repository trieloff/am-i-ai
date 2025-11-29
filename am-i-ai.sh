#!/bin/bash
# am-i-ai.sh - A shared shell library for detecting AI coding agents
# Part of the AI Ecoverse: https://github.com/trieloff/ai-ecoverse
#
# This library provides functions to detect whether the current execution context
# is being driven by an AI coding agent (Claude, Gemini, Cursor, etc.)
#
# Usage:
#   source /path/to/am-i-ai.sh
#   if ami_is_ai; then
#       echo "Running under AI control: $(ami_detect)"
#   fi
#
# Or for simple detection:
#   AI_TOOL=$(ami_detect)
#   if [ "$AI_TOOL" != "none" ]; then
#       echo "AI detected: $AI_TOOL"
#   fi

# Version of the am-i-ai library
AMI_VERSION="1.1.0"

# Debug mode - set AMI_DEBUG=true to enable
AMI_DEBUG="${AMI_DEBUG:-false}"

# Internal debug logging function
_ami_debug() {
    if [ "$AMI_DEBUG" = "true" ]; then
        echo "[am-i-ai] $*" >&2
    fi
}

# Function to check if a process name contains a pattern (case-insensitive)
# Arguments: $1 = pid, $2 = pattern
# Returns: 0 if pattern found, 1 otherwise
ami_process_contains() {
    local pid=$1
    local pattern=$2

    # Get process command and name
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ps -p "$pid" -o comm= 2>/dev/null | grep -qi "$pattern" || \
        ps -p "$pid" -o command= 2>/dev/null | grep -qi "$pattern"
    else
        # Linux
        ps -p "$pid" -o comm= 2>/dev/null | grep -qi "$pattern" || \
        ps -p "$pid" -o cmd= 2>/dev/null | grep -qi "$pattern"
    fi
}

# Phase 1: Environment variable detection
# Returns space-separated list of detected AI tools
ami_check_env() {
    local detected=""

    # Claude Code detection
    # Detect via CLAUDECODE or CLAUDE_CODE_ENTRYPOINT env vars
    # ACP mode sets CLAUDECODE=1 without CLAUDE_CODE_ENTRYPOINT
    # CLI/SDK mode sets both CLAUDECODE and CLAUDE_CODE_ENTRYPOINT
    if [ -n "$CLAUDECODE" ] || [ "$CLAUDE_CODE_ENTRYPOINT" = "cli" ] || [ "$CLAUDE_CODE_ENTRYPOINT" = "sdk-ts" ]; then
        detected="$detected claude"
        _ami_debug "Detected Claude via environment variable"
    fi

    # Gemini detection
    if [ -n "$GEMINI_CLI" ]; then
        detected="$detected gemini"
        _ami_debug "Detected Gemini via environment variable"
    fi

    # Qwen detection
    if [ -n "$QWEN_CODE" ]; then
        detected="$detected qwen"
        _ami_debug "Detected Qwen via environment variable"
    fi

    # Cursor detection - use CURSOR_AGENT to avoid false positives in Cursor IDE terminals
    if [ -n "$CURSOR_AGENT" ]; then
        detected="$detected cursor"
        _ami_debug "Detected Cursor via environment variable"
    fi

    # OpenCode detection
    if [ -n "$OPENCODE_AI" ]; then
        detected="$detected opencode"
        _ami_debug "Detected OpenCode via environment variable"
    fi

    # Codex CLI detection
    # Detect via CODEX_CLI env var or CODEX_SANDBOX (set in sandboxed ACP sessions)
    if [ -n "$CODEX_CLI" ] || [ -n "$CODEX_SANDBOX" ]; then
        detected="$detected codex"
        _ami_debug "Detected Codex via environment variable"
    fi

    # Aider detection
    if [ "$OR_APP_NAME" = "Aider" ]; then
        detected="$detected aider"
        _ami_debug "Detected Aider via environment variable"
    fi

    # Zed detection - complex logic to distinguish human from AI
    # Observed patterns:
    # 1. Human via git panel: ZED_ENVIRONMENT + NO terminal vars + SHLVL=1
    # 2. Human via terminal: ZED_ENVIRONMENT + parent is interactive shell (elvish, zsh, bash, fish)
    # 3. Zed's native agent: ZED_ENVIRONMENT + HAS terminal vars + SHLVL>1 + parent NOT interactive shell
    # 4. ACP integrations: Have their own tool markers (handled above)
    #
    # Key insight: If the direct parent process is an interactive shell,
    # the user is typing commands manually, not the Zed agent.
    local term_program_lower
    term_program_lower=$(echo "$TERM_PROGRAM" | tr '[:upper:]' '[:lower:]')
    if [ -n "$ZED_ENVIRONMENT" ]; then
        if { [ "$term_program_lower" = "zed" ] || [ -n "$ZED_TERM" ]; } && [ "${SHLVL:-1}" -gt 1 ]; then
            # Has terminal vars and SHLVL>1 - could be agent or human in terminal
            # Check if parent process is an interactive shell (human typing)
            local parent_comm
            parent_comm=$(ps -p "$PPID" -o comm= 2>/dev/null | tr '[:upper:]' '[:lower:]')
            case "$parent_comm" in
                bash|elvish|zsh|fish|ksh|tcsh|dash|-bash|-elvish|-zsh|-fish|-ksh|-tcsh|-dash)
                    # Parent is interactive shell - human typing in terminal
                    _ami_debug "Zed detected but parent is interactive shell ($parent_comm) - human typing"
                    ;;
                *)
                    # Parent is not an interactive shell - likely Zed agent
                    detected="$detected zed"
                    _ami_debug "Detected Zed AI agent via environment (parent: $parent_comm)"
                    ;;
            esac
        fi
        # else: Human git panel (SHLVL=1, no terminal vars)
    fi

    # Copilot detection
    if [ "$GITHUB_COPILOT_CLI_MODE" = "true" ]; then
        detected="$detected copilot"
        _ami_debug "Detected Copilot via environment variable"
    fi

    # Droid detection (Factory AI)
    if [ -n "$DROID_CLI" ]; then
        detected="$detected droid"
        _ami_debug "Detected Droid via environment variable"
    fi

    # Amp detection (Sourcegraph)
    if [ "$AGENT" = "amp" ] || [ -n "$AMP_HOME" ]; then
        detected="$detected amp"
        _ami_debug "Detected Amp via environment variable"
    fi

    # Kimi CLI detection
    if [ -n "$KIMI_CLI" ]; then
        detected="$detected kimi"
        _ami_debug "Detected Kimi CLI via environment variable"
    fi

    # OpenHands detection
    if [ "$OR_APP_NAME" = "OpenHands" ] || [ -n "$OR_SITE_URL" ]; then
        detected="$detected openhands"
        _ami_debug "Detected OpenHands via environment variable"
    fi

    # Goose detection (Block)
    if [ -n "$GOOSE_TERMINAL" ]; then
        detected="$detected goose"
        _ami_debug "Detected Goose via environment variable"
    fi

    # Auggie detection (Augment Code)
    if [ -n "$AUGMENT_API_TOKEN" ]; then
        detected="$detected auggie"
        _ami_debug "Detected Auggie via environment variable"
    fi

    # Cline detection (VS Code extension)
    if [ -n "$CLINE_TASK_ID" ]; then
        detected="$detected cline"
        _ami_debug "Detected Cline via environment variable"
    fi

    # Roo Code detection (VS Code extension)
    if [ -n "$ROO_CODE_TASK_ID" ]; then
        detected="$detected roo"
        _ami_debug "Detected Roo Code via environment variable"
    fi

    # Windsurf/Cascade detection
    if [ -n "$WINDSURF_SESSION" ] || [ "$TERM_PROGRAM" = "windsurf" ]; then
        detected="$detected windsurf"
        _ami_debug "Detected Windsurf via environment variable"
    fi

    echo "$detected"
}

# Phase 2: Process tree detection
# Returns space-separated list of detected AI tools
ami_check_ps_tree() {
    local detected=""
    local current_pid=$$
    local max_depth=10
    local depth=0

    _ami_debug "Starting process tree detection from PID $current_pid"

    while [ $depth -lt $max_depth ]; do
        # Get parent PID
        if [[ "$OSTYPE" == "darwin"* ]]; then
            current_pid=$(ps -p "$current_pid" -o ppid= 2>/dev/null | tr -d ' ')
        else
            current_pid=$(ps -p "$current_pid" -o ppid= 2>/dev/null | tr -d ' ')
        fi

        # Check if we've reached the top
        if [ -z "$current_pid" ] || [ "$current_pid" -eq 1 ] || [ "$current_pid" -eq 0 ]; then
            _ami_debug "Reached top of process tree at depth $depth"
            break
        fi

        _ami_debug "Checking PID $current_pid at depth $depth"

        # Check for AI tool patterns
        if ami_process_contains "$current_pid" "claude"; then
            detected="$detected claude"
            _ami_debug "Detected Claude in process tree at depth $depth"
        fi
        if ami_process_contains "$current_pid" "gemini"; then
            detected="$detected gemini"
            _ami_debug "Detected Gemini in process tree at depth $depth"
        fi
        # Detect Codex CLI by process name
        if ami_process_contains "$current_pid" "codex"; then
            detected="$detected codex"
            _ami_debug "Detected Codex in process tree at depth $depth"
        fi
        if ami_process_contains "$current_pid" "aider"; then
            detected="$detected aider"
            _ami_debug "Detected Aider in process tree at depth $depth"
        fi
        if ami_process_contains "$current_pid" "qwen"; then
            detected="$detected qwen"
            _ami_debug "Detected Qwen in process tree at depth $depth"
        fi
        if ami_process_contains "$current_pid" "zed"; then
            # Attribute to Zed's native agent when terminal vars ARE set and SHLVL > 1
            # BUT not if parent is an interactive shell (human typing)
            local tp_lower
            tp_lower=$(echo "$TERM_PROGRAM" | tr '[:upper:]' '[:lower:]')
            if { [ "$tp_lower" = "zed" ] || [ -n "$ZED_TERM" ]; } && [ "${SHLVL:-1}" -gt 1 ]; then
                local parent_comm
                parent_comm=$(ps -p "$PPID" -o comm= 2>/dev/null | tr '[:upper:]' '[:lower:]')
                case "$parent_comm" in
                    bash|elvish|zsh|fish|ksh|tcsh|dash|-bash|-elvish|-zsh|-fish|-ksh|-tcsh|-dash)
                        # Parent is interactive shell - human typing
                        _ami_debug "Zed in tree but parent is interactive shell - human typing"
                        ;;
                    *)
                        detected="$detected zed"
                        _ami_debug "Detected Zed AI in process tree at depth $depth"
                        ;;
                esac
            fi
        fi
        if ami_process_contains "$current_pid" "opencode"; then
            detected="$detected opencode"
            _ami_debug "Detected OpenCode in process tree at depth $depth"
        fi
        # Cursor detection - use cursor-agent to avoid false positives in Cursor IDE terminals
        if ami_process_contains "$current_pid" "cursor-agent"; then
            detected="$detected cursor"
            _ami_debug "Detected Cursor in process tree at depth $depth"
        fi
        # Kimi CLI detection - look for kimi in process command
        if ami_process_contains "$current_pid" "kimi"; then
            detected="$detected kimi"
            _ami_debug "Detected Kimi CLI in process tree at depth $depth"
        fi
        # Crush detection - look for crush in process command
        if ami_process_contains "$current_pid" "crush"; then
            detected="$detected crush"
            _ami_debug "Detected Crush in process tree at depth $depth"
        fi
        # Goose detection - look for goose in process command
        if ami_process_contains "$current_pid" "goose"; then
            detected="$detected goose"
            _ami_debug "Detected Goose in process tree at depth $depth"
        fi
        # Auggie detection - look for auggie in process command
        if ami_process_contains "$current_pid" "auggie"; then
            detected="$detected auggie"
            _ami_debug "Detected Auggie in process tree at depth $depth"
        fi
        # Cline detection
        if ami_process_contains "$current_pid" "cline"; then
            detected="$detected cline"
            _ami_debug "Detected Cline in process tree at depth $depth"
        fi
        # Roo Code detection - use word boundary to avoid matching "kangaroo", etc.
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ps -p "$current_pid" -o comm= 2>/dev/null | grep -qiw "roo" || \
               ps -p "$current_pid" -o command= 2>/dev/null | grep -qiw "roo"; then
                detected="$detected roo"
                _ami_debug "Detected Roo Code in process tree at depth $depth"
            fi
        else
            if ps -p "$current_pid" -o comm= 2>/dev/null | grep -qiw "roo" || \
               ps -p "$current_pid" -o cmd= 2>/dev/null | grep -qiw "roo"; then
                detected="$detected roo"
                _ami_debug "Detected Roo Code in process tree at depth $depth"
            fi
        fi
        # Windsurf detection
        if ami_process_contains "$current_pid" "windsurf"; then
            detected="$detected windsurf"
            _ami_debug "Detected Windsurf in process tree at depth $depth"
        fi
        # Droid detection - use word boundary to avoid matching android-studio, etc.
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ps -p "$current_pid" -o comm= 2>/dev/null | grep -qiw "droid" || \
               ps -p "$current_pid" -o command= 2>/dev/null | grep -qiw "droid"; then
                detected="$detected droid"
                _ami_debug "Detected Droid in process tree at depth $depth"
            fi
        else
            if ps -p "$current_pid" -o comm= 2>/dev/null | grep -qiw "droid" || \
               ps -p "$current_pid" -o cmd= 2>/dev/null | grep -qiw "droid"; then
                detected="$detected droid"
                _ami_debug "Detected Droid in process tree at depth $depth"
            fi
        fi

        depth=$((depth + 1))
    done

    echo "$detected"
}

# Main AI detection function with proper two-phase approach
# Returns the detected AI tool name, or "none" if no AI detected
# Priority order ensures more specific tools take precedence over generic ones
ami_detect() {
    _ami_debug "Starting AI detection"

    # Phase 1: Environment variable detection
    local env_detected
    env_detected=$(ami_check_env)

    # Phase 2: Process tree detection
    local ps_detected
    ps_detected=$(ami_check_ps_tree)

    # Combine results and apply priority order
    local all_detected="$env_detected $ps_detected"

    _ami_debug "Environment detected: '$env_detected'"
    _ami_debug "Process tree detected: '$ps_detected'"
    _ami_debug "Combined detected: '$all_detected'"

    # Priority order: Amp > Codex > Aider > Claude > Gemini > Qwen > Droid > OpenCode > Cursor > Copilot > Kimi > OpenHands > Cline > Roo > Windsurf > Crush > Goose > Auggie > Zed
    # Zed is last because it often hosts other AI tools
    # More specific AI tools take precedence over IDE-level tools
    if [[ "$all_detected" =~ "amp" ]]; then
        _ami_debug "Final result: amp"
        echo "amp"
    elif [[ "$all_detected" =~ "codex" ]]; then
        _ami_debug "Final result: codex"
        echo "codex"
    elif [[ "$all_detected" =~ "aider" ]]; then
        _ami_debug "Final result: aider"
        echo "aider"
    elif [[ "$all_detected" =~ "claude" ]]; then
        _ami_debug "Final result: claude"
        echo "claude"
    elif [[ "$all_detected" =~ "gemini" ]]; then
        _ami_debug "Final result: gemini"
        echo "gemini"
    elif [[ "$all_detected" =~ "qwen" ]]; then
        _ami_debug "Final result: qwen"
        echo "qwen"
    elif [[ "$all_detected" =~ "droid" ]]; then
        _ami_debug "Final result: droid"
        echo "droid"
    elif [[ "$all_detected" =~ "opencode" ]]; then
        _ami_debug "Final result: opencode"
        echo "opencode"
    elif [[ "$all_detected" =~ "cursor" ]]; then
        _ami_debug "Final result: cursor"
        echo "cursor"
    elif [[ "$all_detected" =~ "copilot" ]]; then
        _ami_debug "Final result: copilot"
        echo "copilot"
    elif [[ "$all_detected" =~ "kimi" ]]; then
        _ami_debug "Final result: kimi"
        echo "kimi"
    elif [[ "$all_detected" =~ "openhands" ]]; then
        _ami_debug "Final result: openhands"
        echo "openhands"
    elif [[ "$all_detected" =~ "cline" ]]; then
        _ami_debug "Final result: cline"
        echo "cline"
    elif [[ "$all_detected" =~ "roo" ]]; then
        _ami_debug "Final result: roo"
        echo "roo"
    elif [[ "$all_detected" =~ "windsurf" ]]; then
        _ami_debug "Final result: windsurf"
        echo "windsurf"
    elif [[ "$all_detected" =~ "crush" ]]; then
        _ami_debug "Final result: crush"
        echo "crush"
    elif [[ "$all_detected" =~ "goose" ]]; then
        _ami_debug "Final result: goose"
        echo "goose"
    elif [[ "$all_detected" =~ "auggie" ]]; then
        _ami_debug "Final result: auggie"
        echo "auggie"
    elif [[ "$all_detected" =~ "zed" ]]; then
        _ami_debug "Final result: zed"
        echo "zed"
    else
        _ami_debug "Final result: none"
        echo "none"
    fi
}

# Convenience function: returns 0 (true) if AI is detected, 1 (false) otherwise
ami_is_ai() {
    local result
    result=$(ami_detect)
    [ "$result" != "none" ]
}

# Get all detected AI tools (not just the highest priority one)
# Returns space-separated list or empty string
ami_detect_all() {
    local env_detected
    env_detected=$(ami_check_env)

    local ps_detected
    ps_detected=$(ami_check_ps_tree)

    # Combine and deduplicate
    local all_detected="$env_detected $ps_detected"

    # Remove leading/trailing spaces and deduplicate
    echo "$all_detected" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//'
}

# Get the email address for a detected AI tool
# Arguments: $1 = AI tool name (optional, uses ami_detect if not provided)
ami_get_email() {
    local tool="${1:-$(ami_detect)}"

    case "$tool" in
        "claude")   echo "noreply@anthropic.com" ;;
        "gemini")   echo "noreply@google.com" ;;
        "codex")    echo "noreply@openai.com" ;;
        "aider")    echo "aider@aider.chat" ;;
        "qwen")     echo "noreply@alibaba.com" ;;
        "cursor")   echo "cursoragent@cursor.com" ;;
        "opencode") echo "noreply@opencode.ai" ;;
        "zed")      echo "noreply@zed.dev" ;;
        "copilot")  echo "copilot@github.com" ;;
        "droid")    echo "droid@factory.ai" ;;
        "amp")      echo "noreply@sourcegraph.com" ;;
        "kimi")     echo "noreply@kimi.com" ;;
        "openhands") echo "openhands@all-hands.dev" ;;
        "crush")    echo "crush@charm.land" ;;
        "goose")    echo "goose@opensource.block.xyz" ;;
        "auggie")   echo "noreply@augmentcode.com" ;;
        "cline")    echo "cline@cline.bot" ;;
        "roo")      echo "roo@roocode.dev" ;;
        "windsurf") echo "cascade@codeium.com" ;;
        *)          echo "" ;;
    esac
}

# Get the display name for a detected AI tool
# Arguments: $1 = AI tool name (optional, uses ami_detect if not provided)
ami_get_name() {
    local tool="${1:-$(ami_detect)}"

    case "$tool" in
        "claude")   echo "Claude Code" ;;
        "gemini")   echo "Gemini" ;;
        "codex")    echo "Codex CLI" ;;
        "aider")    echo "Aider" ;;
        "qwen")     echo "Qwen Code" ;;
        "cursor")   echo "Cursor AI" ;;
        "opencode") echo "opencode AI" ;;
        "zed")      echo "Zed AI" ;;
        "copilot")  echo "GitHub Copilot" ;;
        "droid")    echo "Droid" ;;
        "amp")      echo "Amp" ;;
        "kimi")     echo "Kimi CLI" ;;
        "openhands") echo "OpenHands" ;;
        "crush")    echo "Crush" ;;
        "goose")    echo "Goose User" ;;
        "auggie")   echo "Augment Code" ;;
        "cline")    echo "Cline" ;;
        "roo")      echo "Roo Code" ;;
        "windsurf") echo "Windsurf Cascade" ;;
        *)          echo "" ;;
    esac
}

# Print version information
ami_version() {
    echo "am-i-ai version $AMI_VERSION"
    echo "https://github.com/trieloff/am-i-ai"
}

# If this script is run directly (not sourced), run the detection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --version|-v)
            ami_version
            ;;
        --help|-h)
            echo "am-i-ai - AI coding agent detection library"
            echo ""
            echo "Usage as script:"
            echo "  am-i-ai.sh           # Detect AI and print result"
            echo "  am-i-ai.sh --all     # Show all detected AIs"
            echo "  am-i-ai.sh --check   # Exit 0 if AI, 1 if not"
            echo "  am-i-ai.sh --debug   # Run with debug output"
            echo ""
            echo "Usage as library:"
            echo "  source am-i-ai.sh"
            echo "  if ami_is_ai; then"
            echo "    echo \"AI: \$(ami_detect)\""
            echo "  fi"
            echo ""
            echo "Functions:"
            echo "  ami_detect        - Returns detected AI tool or 'none'"
            echo "  ami_is_ai         - Returns 0 if AI detected, 1 otherwise"
            echo "  ami_detect_all    - Returns all detected AI tools"
            echo "  ami_get_name      - Returns display name for AI tool"
            echo "  ami_get_email     - Returns email for AI tool"
            echo "  ami_check_env     - Phase 1: environment variable detection"
            echo "  ami_check_ps_tree - Phase 2: process tree detection"
            ;;
        --all|-a)
            ami_detect_all
            ;;
        --check|-c)
            ami_is_ai
            ;;
        --debug|-d)
            AMI_DEBUG=true ami_detect
            ;;
        *)
            ami_detect
            ;;
    esac
fi
