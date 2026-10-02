# Energy measurement instrumentation (release 2.16.0)

## Purpose

This directory is not part of the upstream Scrapy repository. It was added to
measure the energy consumption of CI/CD pipeline commands on controlled
hardware, using Intel RAPL counters. The measured construct is the energy of
the CI commands on a controlled bench, not the energy of GitHub-hosted CI in
production.

## Non-invasiveness

No original project file is created or modified. The only additions are this
directory and `.github/workflows/energy-measurement.yml`. This branch is the upstream
tag `2.16.0` plus one instrumentation commit; verify with:

```bash
git diff --stat 2.16.0 release-2.16.0
```

## What is measured

Energy is read from the Intel RAPL counters exposed under
`/sys/class/powercap/intel-rapl`, for four domains: package (`pkg`), cores,
uncore (reported as `gpu`, structurally zero on this bench) and DRAM (`ram`).
Counter deltas are overflow-corrected against `max_energy_range_uj`, which is
read from sysfs at run time rather than hardcoded.

Each run measures a 120 s idle baseline first and derives a per-second rate per
domain. Reported energy per stage is

```
net = max(raw_delta - baseline_rate * wall_time_s, 0)
```

The clamp at zero prevents a negative DRAM figure on light memory workloads.
The unclamped DRAM value is kept as the diagnostic column
`energy_ram_liquid_raw_j`.

`wall_time_s` covers the whole `docker run --rm` lifecycle, including container
setup and teardown, because the RAPL reading window covers the same interval.
`wall_time_container_s` is measured inside the container and is therefore
always smaller; the difference isolates container overhead.

Per-stage CPU time is captured inside the container: file descriptor 3
preserves the workload's stderr while `time` writes to `/timing`, so the CPU
time of child processes is attributed to the stage instead of to the host
`docker` client.

## How to run

Build the image from the root of a clone of branch `release-2.16.0` (the Dockerfile copies
the tree), then run one measurement:

```bash
docker build -t scrapy-measurement-2.16.0 -f energy-measurement/Dockerfile .
bash energy-measurement/run_pipeline.sh 1
```

The workflow `energy-measurement.yml` runs the same script on a self-hosted
runner and is dispatched manually:

```bash
gh workflow run energy-measurement.yml --ref release-2.16.0 -f campaign=validation   # run 0 only
gh workflow run energy-measurement.yml --ref release-2.16.0 -f campaign=full         # warm-up + 10 runs
```

## Stages

Each stage runs in its own container, so build artifacts do not survive into
the test stage.

| stage | corresponds to | command |
|---|---|---|
| `build` | environment provisioning done by `tox`/`uv` in the upstream `Run tests` step | offline install of the `[test-requirements]` and `[testenv]` dependencies plus the project itself, from the image wheelhouse |
| `test` | the `pytest` invocation that `tox` runs for `TOXENV=py` | `pytest --cov-config=pyproject.toml --cov=scrapy --cov-report= --cov-report=term-missing --cov-report=xml --junitxml=testenv.junit.xml -o junit_family=legacy --durations=10 -m "not requires_internet" scrapy tests --doctest-modules` with `PYTEST_ADDOPTS="-n auto"` (coverage on, the value of the cell at this tag) |

Reference cell: `tests-ubuntu.yml`, job `tests`, `python-version: "3.13"`,
`TOXENV: py`, at tag `2.16.0`; the same cell as the HEAD campaign of this fork.

## Deviations from the upstream pipeline

- **Offline dependencies.** Every dependency is pre-built into the image
  wheelhouse and installed with `--no-index`. RAPL has no network domain, so a
  live download would inflate wall time without proportional energy. The tag
  pins nothing, so every distribution is fixed to the newest release available
  on 2026-05-19, the date of the tag's reference run.
- **`--network none`.** The measured containers have no network. The suite's
  own mock servers bind to loopback, which remains available.
- **`requires_internet` tests excluded.** Selected out with
  `-m "not requires_internet"`, the upstream marker: 15 tests in the classes deriving
  from `TestRealWebsiteBase`, which contact live websites.
- **No mitmproxy.** At this tag the `py` cell does not install mitmproxy (a separate
  tox environment runs those tests), so the tests that need it skip, as upstream.
- **`GITHUB_ACTIONS=true`.** Set in the image, as on the upstream runner, so
  tests that branch on it take the same path.
- **uid 1001.** The container runs as a non-root user with the same uid as the
  GitHub runner; running as root would change tests that assert on filesystem
  permissions.

## Output schema

One CSV per run, one row per stage plus a `total` row:

```
run, stage, energy_pkg_j, energy_cores_j, energy_gpu_j, energy_ram_j,
wall_time_s, user_time_s, sys_time_s, energy_ram_liquid_raw_j,
wall_time_container_s, swap_in_pages, swap_out_pages,
baseline_rate_pkg_w, baseline_rate_cores_w, baseline_rate_ram_w
```

The first nine columns are the official schema shared by every project in the
study. The last seven are diagnostic and stay out of the reported analysis:

- `energy_ram_liquid_raw_j` - RAM energy before the `max(.,0)` floor; a negative
  value is the auditable record of baseline over-subtraction.
- `wall_time_container_s` - wall time measured inside the container.
- `swap_in_pages`, `swap_out_pages` - host paging inside the measured window.
- `baseline_rate_pkg_w`, `baseline_rate_cores_w`, `baseline_rate_ram_w` - the
  idle rate subtracted from every stage of the run. One baseline is measured per
  run, so the value repeats on the `build`, `test` and `total` rows. RAPL covers
  the whole host, so a rate above `BASELINE_WARN_W` (default 1.0 W) means the
  host was not idle and the run is suspect for over-subtraction.

Exit codes are written to a sidecar `exit_codes_run_NN.txt`. The package
temperature (hwmon `coretemp`, `Package id 0`) is read immediately before and
after each stage's RAPL window, never inside it, into `temp_run_NN_<stage>.txt`.

## Reproducibility notes

Bench: Intel Core i7-9700 (8 cores, no SMT), 16 GB RAM, Crucial BX500 SATA SSD,
Ubuntu 24.04.4 LTS, kernel 6.8.0-136-generic, Docker 29.7.1.

Container flags: `--privileged --network none --memory=12g --memory-swap=12g`.
Setting swap equal to the memory limit makes `memory.swap.max` zero, so the
container itself cannot page.

Image: Python 3.13.13, pytest 9.0.3, pytest-xdist 3.8.0, pytest-twisted 1.14.3, Twisted 26.4.0, coverage 7.14.0.
`pytest-xdist` runs with `-n auto`, which resolves to 8 workers on this bench
against 4 on a GitHub-hosted runner; the value is the upstream cell's and is not overridden.
