#!/bin/bash
# bundle.sh - Bundle am-i-ai library into dependent scripts
#
# This script takes a target script and embeds the am-i-ai detection
# functions directly into it, creating a single self-contained file.
#
# Usage:
#   ./bundle.sh <input-script> <output-script>
#   ./bundle.sh --inline <input-script>  # Modify in place
#
# The input script should contain the marker:
#   # @bundle:am-i-ai
# This marker will be replaced with the embedded library functions.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_FILE="$SCRIPT_DIR/am-i-ai.sh"

# Extract just the function definitions from am-i-ai.sh
# Skips the shebang, version info, CLI handling, and if-main block
extract_functions() {
    local in_function=false
    local brace_count=0
    local skip_next=false

    # Use awk to extract function definitions
    awk '
    BEGIN {
        in_function = 0
        brace_count = 0
        skip_section = 0
    }

    # Skip shebang and initial comments
    /^#!/ { next }
    /^# am-i-ai\.sh/ { next }
    /^# Part of the AI Ecoverse/ { next }
    /^# https:\/\/github\.com/ { next }
    /^#$/ && NR < 20 { next }

    # Skip the if-main block at the end
    /^if \[\[ "\$\{BASH_SOURCE\[0\]\}"/ { skip_section = 1 }
    skip_section { next }

    # Skip version and debug config (they get redefined)
    /^AMI_VERSION=/ { next }
    /^AMI_DEBUG=/ { next }

    # Skip _ami_debug function (we use debug_log instead)
    /^_ami_debug\(\)/ { skip_func = 1; next }
    skip_func && /^\}$/ { skip_func = 0; next }
    skip_func { next }

    # Skip ami_version function
    /^ami_version\(\)/ { skip_func = 1; next }

    # Print everything else
    { print }
    ' "$LIB_FILE"
}

# Generate the bundled library code
generate_bundle() {
    cat << 'BUNDLE_HEADER'
# ===========================================================================
# Bundled from am-i-ai v1.0.0
# https://github.com/trieloff/am-i-ai
#
# AI coding agent detection library - provides functions to detect whether
# code is running under AI control (Claude, Gemini, Cursor, etc.)
# ===========================================================================

BUNDLE_HEADER

    extract_functions

    cat << 'BUNDLE_FOOTER'

# Map am-i-ai function names to local conventions
process_contains() { ami_process_contains "$@"; }
check_env_vars() { ami_check_env; }
check_ps_tree() { ami_check_ps_tree; }
detect_ai_tool() { ami_detect; }

# ===========================================================================
# End of bundled am-i-ai library
# ===========================================================================
BUNDLE_FOOTER
}

usage() {
    echo "Usage: $0 <input-script> <output-script>"
    echo "       $0 --inline <input-script>"
    echo ""
    echo "Bundles the am-i-ai library into a shell script."
    echo ""
    echo "The input script should contain the marker:"
    echo "  # @bundle:am-i-ai"
    echo ""
    echo "Options:"
    echo "  --inline    Modify the input script in place"
    echo "  --help      Show this help message"
}

# Main
case "${1:-}" in
    --help|-h)
        usage
        exit 0
        ;;
    --inline)
        if [ -z "${2:-}" ]; then
            echo "Error: --inline requires an input file" >&2
            exit 1
        fi
        INPUT="$2"
        OUTPUT="$2"
        ;;
    *)
        if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
            usage
            exit 1
        fi
        INPUT="$1"
        OUTPUT="$2"
        ;;
esac

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT" >&2
    exit 1
fi

if [ ! -f "$LIB_FILE" ]; then
    echo "Error: am-i-ai.sh not found: $LIB_FILE" >&2
    exit 1
fi

# Check for marker
if ! grep -q '# @bundle:am-i-ai' "$INPUT"; then
    echo "Error: Input file does not contain '# @bundle:am-i-ai' marker" >&2
    exit 1
fi

# Create temp file for output
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Process the input file
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == *"# @bundle:am-i-ai"* ]]; then
        # Replace marker with bundled library
        generate_bundle
    else
        echo "$line"
    fi
done < "$INPUT" > "$TEMP_FILE"

# Copy to output
cp "$TEMP_FILE" "$OUTPUT"
chmod +x "$OUTPUT"

echo "Bundled am-i-ai into: $OUTPUT"
