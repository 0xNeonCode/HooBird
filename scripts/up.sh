#!/bin/bash
# Start the disposable local stack and wait until the policy API is ready.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/init_local_env.py
if [[ ! -f synapse/homeserver.yaml ]]; then
  python3 scripts/render_local_config.py
fi
if ! sudo docker info >/dev/null 2>&1; then
  sudo dockerd >/tmp/hoobird-dockerd.log 2>&1 &
  for _ in $(seq 1 30); do
    sudo docker info >/dev/null 2>&1 && break
    sleep 1
  done
fi
sudo docker compose up -d --build
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:18018/_hoobird/health" >/dev/null; then
    echo "hoobird stack ready on http://127.0.0.1:18008 (Synapse) and http://127.0.0.1:18018 (policy)"
    exit 0
  fi
  sleep 2
done
echo "stack did not become healthy" >&2
sudo docker compose logs --tail=120
exit 1
