# gpu_bench: measurements that replace model assumptions

## What you need
* A Linux GPU machine with the NVIDIA driver and Python 3.10+. An NVIDIA GPU from the
  Volta generation or later is needed for the hardware energy counter; older GPUs fall
  back to integrating power samples.
* **Root on the GPU** (a VM or bare-metal instance), so power caps can be set. Many shared
  container offerings do not allow `nvidia-smi -pl`; `scripts/setup_gpu_node.sh` checks this.
* Internet access to Hugging Face for the Qwen2.5 models (Apache-2.0, no access request needed).

## Run
```bash
git clone https://github.com/shivankur-code/reliable-green-inference && cd reliable-green-inference
bash scripts/setup_gpu_node.sh && source .venv/bin/activate
python -m gpu_bench.run_sweep configs/gpu/g0_smoke.yaml --quick   # 10 min sanity check
python -m gpu_bench.run_sweep configs/gpu/g3_reliability.yaml     # about 30 min
python -m gpu_bench.run_sweep configs/gpu/g1_powercap.yaml        # about 3 h; use tmux
# 4+ GPUs:
python -m gpu_bench.run_sweep configs/gpu/g2_tp_blast_radius.yaml
```
Then commit `data/measurements/gpu/` (summary CSVs, per-run request and NVML logs, env.json).
Server logs are large; they are git-ignored.

## Notes
* Power caps are fractions of the GPU's *default* limit, clamped to the allowed minimum.
  Caps are restored to 100% when a sweep ends or fails.
* Steady-state temperature depends on cooling and ambient temperature. Record the
  machine type and cloud provider in your commit message.
* Every load run is preceded by a warm-up at the same cap so the temperature settles.
