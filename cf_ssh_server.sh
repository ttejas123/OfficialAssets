#!/usr/bin/env bash
set -e

REGISTRY="https://cf-ssh-registry.staticassets.workers.dev"
OS="$(uname -s)"
USER_NAME="$(whoami)"
MACHINE="$(hostname)"

LOG_FILE="$HOME/.cloudflared-ssh.log"
PID_FILE="$HOME/.cloudflared-ssh.pid"

echo "▶ Starting remote support for $MACHINE"

# ---- install cloudflared ----
install_linux() {
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /tmp/cloudflared
  chmod +x /tmp/cloudflared
  sudo mv /tmp/cloudflared /usr/local/bin/cloudflared
}

# install_mac_v1() {
#   if ! command -v brew >/dev/null; then
#     echo "✖ Homebrew not found. Install Homebrew first."
#     exit 1
#   fi
#   brew install cloudflare/cloudflare/cloudflared
# }

install_mac() {
  # Install Homebrew if not installed
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Ensure brew is available in the current shell
    if [[ -d "/opt/homebrew/bin" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -d "/usr/local/bin" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  echo "Installing cloudflared..."
  brew install cloudflare/cloudflare/cloudflared
}


if ! command -v cloudflared >/dev/null; then
  [[ "$OS" == "Linux" ]] && install_linux
  [[ "$OS" == "Darwin" ]] && install_mac
fi

# ---- ensure SSH server ----
if [[ "$OS" == "Darwin" ]]; then
  sudo systemsetup -setremotelogin on >/dev/null
else
  sudo systemctl start ssh || sudo systemctl start sshd
fi

# ---- start tunnel quietly in background ----
echo "▶ Launching tunnel in background…"

nohup cloudflared tunnel --url ssh://localhost:22 \
  > "$LOG_FILE" 2>&1 &

PID=$!
echo "$PID" > "$PID_FILE"

# ---- extract hostname from log ----
for i in {1..30}; do
  HOST=$(grep -oE 'https://[a-z0-9.-]+\.trycloudflare\.com' "$LOG_FILE" \
    | tail -n1 | sed 's|https://||')
  [[ -n "$HOST" ]] && break
  sleep 0.5
done

if [[ -z "$HOST" ]]; then
  echo "✖ Failed to start tunnel"
  kill "$PID" 2>/dev/null || true
  rm -f "$PID_FILE"
  exit 1
fi

# ---- register ----
curl -s -X POST "$REGISTRY/register" \
  -H "Content-Type: application/json" \
  -d "{\"host\":\"$HOST\",\"machine\":\"$MACHINE\",\"user\":\"$USER_NAME\"}" \
  >/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "REMOTE ACCESS READY"
echo ""
echo "Host: $HOST"
echo ""
echo "STOP access:"
echo "  pkill cloudflared"
echo ""
echo "Check status:"
echo "  ps -p $(cat "$PID_FILE")"
echo ""
echo "Log file:"
echo "  $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
