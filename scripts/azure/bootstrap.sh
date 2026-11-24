#!/bin/bash
# VM boot script (cloud-init custom data). Placeholders __CONFIG__, __SAS_URL__, __BRANCH__
# are filled in at launch by scripts/azure/launch.sh; the SAS URL is never committed.
exec > /var/log/calf-bootstrap.log 2>&1
set -x
export HOME=/root
CONFIG="__CONFIG__"; SAS_URL="__SAS_URL__"; BRANCH="__BRANCH__"; VLLM_SPEC="__VLLM_SPEC__"; PREFIX="__NAME__"
upload() {  # $1 = blob name, $2 = file
  curl -sS -X PUT -H "x-ms-blob-type: BlockBlob" --data-binary @"$2" \
    "${SAS_URL%%\?*}/$PREFIX/$1?${SAS_URL#*\?}"
}
status() { echo "$(date -u +%FT%TZ) $*" > /opt/status.txt; upload status.txt /opt/status.txt; }
status "booted"
nvidia-smi || { status "FAILED: no nvidia driver"; exit 1; }
cd /opt && git clone -b "$BRANCH" https://github.com/shivankur-code/reliable-green-inference.git calf
cd /opt/calf
curl -LsSf https://astral.sh/uv/install.sh | sh && export PATH="$HOME/.local/bin:$PATH"
uv venv -p 3.12 .venv && . .venv/bin/activate
status "installing vllm"
uv pip install "$VLLM_SPEC" nvidia-ml-py aiohttp pyyaml && uv pip install -e . || { status "FAILED: pip"; upload bootstrap.log /var/log/calf-bootstrap.log; exit 1; }
mkdir -p data/measurements && nvidia-smi -q > data/measurements/nvidia-smi-q.txt
( while true; do sleep 600; tar czf /opt/partial.tgz data/measurements --exclude=server.log \
    && upload partial.tgz /opt/partial.tgz; upload bootstrap.log /var/log/calf-bootstrap.log; done ) &
status "running $CONFIG"
python -m gpu_bench.run_sweep "$CONFIG" && RC=ok || RC=failed
tar czf /opt/results.tgz data/measurements --exclude=server.log
upload results.tgz /opt/results.tgz
find data/measurements -name server.log -exec tail -n 200 {} \; > /opt/server_tail.log
upload server_tail.log /opt/server_tail.log
upload bootstrap.log /var/log/calf-bootstrap.log
status "DONE $RC"
