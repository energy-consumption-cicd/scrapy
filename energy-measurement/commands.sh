#!/usr/bin/env bash

set -euo pipefail
STAGE="${1:?stage required: build | test}"

# Each stage runs in its own container, so nothing the build stage writes
# survives into the test stage: the build measures the provisioning work and
# its output is discarded, while the test stage uses the environment already
# installed in the image.
WORK=/work/scrapy
BUILD_VENV=/work/venv-build

case "$STAGE" in

  build)
    rm -rf "$BUILD_VENV"
    python -m venv "$BUILD_VENV"
    "$BUILD_VENV/bin/pip" install -q --no-index --find-links=/wheelhouse \
        --upgrade pip setuptools wheel hatchling
    # Dependencies of tox.ini [test-requirements] and [testenv] for TOXENV=py.
    "$BUILD_VENV/bin/pip" install -q --no-index --find-links=/wheelhouse \
        attrs coverage httpx2 pexpect pyftpdlib pygments \
        pytest pytest-cov pytest-rerunfailures pytest-timeout pytest-xdist \
        sybil pytest-twisted
    cd /project
    "$BUILD_VENV/bin/pip" install -q --no-index --find-links=/wheelhouse \
        --no-build-isolation .
    "$BUILD_VENV/bin/pip" list
    ;;

  test)
    # The suite writes into the tree, so it runs from a copy and the image
    # layer stays identical across runs.
    rm -rf "$WORK"
    cp -a /project "$WORK"
    cd "$WORK"
    # Value of the reference cell (coverage disabled in that matrix entry).
    export PYTEST_ADDOPTS="-n auto --no-cov"
    # -m: the upstream `requires_internet` marker selects the 15 tests that
    # reach real websites; they cannot run under --network none.
    /venv/bin/python -m pytest \
        --cov-config=pyproject.toml --cov=scrapy --cov-report= \
        --cov-report=term-missing --cov-report=xml \
        --junitxml=testenv.junit.xml -o junit_family=legacy --durations=10 \
        -m "not requires_internet" \
        scrapy tests --doctest-modules
    ;;

  *)
    echo "Unknown stage: $STAGE" >&2
    exit 1
    ;;
esac
