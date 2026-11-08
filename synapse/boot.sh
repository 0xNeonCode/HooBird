#!/bin/bash
set -euo pipefail
if [[ ! -s /data/hoobird.signing.key ]]; then
  python -m synapse.app.homeserver --generate-keys -c /data/homeserver.yaml
fi
exec python -m synapse.app.homeserver --config-path /data/homeserver.yaml
