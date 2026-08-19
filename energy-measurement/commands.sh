#!/usr/bin/env bash

set -euo pipefail
STAGE="${1:?stage required: build | test}"

# The suite writes into the tree, so it runs from a copy: the image layer stays
# clean and every stage starts from the same state.
WORK=/work/scrapy
BUILD_VENV=/work/venv-build

case "$STAGE" in

  build)
    rm -rf "$WORK" "$BUILD_VENV"
    cp -a /project "$WORK"
    cd "$WORK"
    python -m venv "$BUILD_VENV"
    "$BUILD_VENV/bin/pip" install -q --no-index --find-links=/wheelhouse \
        --upgrade pip setuptools wheel hatchling
    # Dependencies of tox.ini [test-requirements] and [testenv] for TOXENV=py.
    "$BUILD_VENV/bin/pip" install -q --no-index --find-links=/wheelhouse \
        attrs coverage httpx2 pexpect pyftpdlib pygments \
        pytest pytest-cov pytest-rerunfailures pytest-timeout pytest-xdist \
        sybil pytest-twisted
    "$BUILD_VENV/bin/pip" install -q --no-index --find-links=/wheelhouse \
        --no-build-isolation .
    "$BUILD_VENV/bin/pip" list
    ;;

  test)
    cd "$WORK"
    # Value of the reference cell (coverage disabled in that matrix entry).
    export PYTEST_ADDOPTS="-n auto --no-cov"
    # -m: the upstream `requires_internet` marker selects the 15 tests that
    # reach real websites; they cannot run under --network none.
    "$BUILD_VENV/bin/python" -m pytest \
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
