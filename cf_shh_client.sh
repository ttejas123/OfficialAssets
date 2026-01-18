#!/usr/bin/env bash
set -e

REGISTRY="https://cf-ssh-registry.staticassets.workers.dev/active"

machines=$(curl -s "$REGISTRY")
count=$(echo "$machines" | jq length)

if [[ "$count" -eq 0 ]]; then
  echo "No active machines available"
  exit 0
fi

echo "Available machines:"
echo ""

for i in $(seq 0 $((count - 1))); do
  machine=$(echo "$machines" | jq -r ".[$i].machine")
  user=$(echo "$machines" | jq -r ".[$i].user // \"<unknown>\"")
  echo "$((i + 1))) $machine ($user)"
done

echo ""
read -p "Select a machine [1-$count]: " choice

# enforce numeric input
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
  echo "Please enter a number"
  exit 1
fi

index=$((choice - 1))

if [[ "$index" -lt 0 || "$index" -ge "$count" ]]; then
  echo "Invalid selection"
  exit 1
fi

USER=$(echo "$machines" | jq -r ".[$index].user")
HOST=$(echo "$machines" | jq -r ".[$index].host")

if [[ "$USER" == "null" || -z "$USER" ]]; then
  echo "ERROR: Registry entry missing SSH username"
  echo "Fix server script to send 'user'"
  exit 1
fi

echo ""
echo "Connecting to $USER@$HOST"
echo ""

ssh -o ProxyCommand="cloudflared access ssh --hostname %h" \
"$USER@$HOST"
