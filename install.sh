#!/bin/bash
# am-i-ai installation script
# Installs the am-i-ai library to ~/.local/lib/

set -e

INSTALL_DIR="${AM_I_AI_INSTALL_DIR:-$HOME/.local/lib}"
SCRIPT_NAME="am-i-ai.sh"

echo "Installing am-i-ai to $INSTALL_DIR..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download the library
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://raw.githubusercontent.com/trieloff/am-i-ai/main/am-i-ai.sh" \
        -o "$INSTALL_DIR/$SCRIPT_NAME"
elif command -v wget >/dev/null 2>&1; then
    wget -q "https://raw.githubusercontent.com/trieloff/am-i-ai/main/am-i-ai.sh" \
        -O "$INSTALL_DIR/$SCRIPT_NAME"
else
    echo "Error: curl or wget required" >&2
    exit 1
fi

# Make executable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "Installed am-i-ai to $INSTALL_DIR/$SCRIPT_NAME"
echo ""
echo "Usage:"
echo "  # As a script"
echo "  $INSTALL_DIR/$SCRIPT_NAME"
echo ""
echo "  # As a library"
echo "  source $INSTALL_DIR/$SCRIPT_NAME"
echo "  if ami_is_ai; then"
echo "    echo \"AI detected: \$(ami_detect)\""
echo "  fi"
