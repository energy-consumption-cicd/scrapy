# Reference cell: tests-ubuntu.yml, job `tests`, python-version 3.13, TOXENV=py
# (cell 1 of 16; see the fidelity note for the selection criteria).
FROM python:3.13.15-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# libxml2/libxslt headers are what the upstream job installs before building
# lxml; the compiler toolchain is needed to build sdists offline later.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libssl-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# The GitHub runner executes as uid 1001; running as root would change the
# outcome of tests that assert on filesystem permissions.
RUN groupadd -g 1001 runner && \
    useradd -u 1001 -g 1001 -m -d /home/runner -s /bin/bash runner

COPY . /project
WORKDIR /project

ENV VENV=/venv
ENV WHEELHOUSE=/wheelhouse

# Dependencies of tox.ini [test-requirements] and [testenv], pinned to the
# versions resolved on 2026-08-19. Wheels are built at image build time so the
# measured build stage installs offline (RAPL has no network domain).
ENV DEP_ATTRS=attrs==25.4.0 \
    DEP_COVERAGE=coverage==7.15.4 \
    DEP_HTTPX2=httpx2==2.12.0 \
    DEP_PEXPECT=pexpect==4.9.0 \
    DEP_PYFTPDLIB=pyftpdlib==2.2.0 \
    DEP_PYGMENTS=pygments==2.19.2 \
    DEP_PYTEST=pytest==9.1.1 \
    DEP_PYTEST_COV=pytest-cov==7.0.0 \
    DEP_PYTEST_RERUN=pytest-rerunfailures==16.1 \
    DEP_PYTEST_TIMEOUT=pytest-timeout==2.4.0 \
    DEP_PYTEST_XDIST=pytest-xdist==3.8.0 \
    DEP_SYBIL=sybil==10.1.0 \
    DEP_PYTEST_TWISTED=pytest-twisted==1.14.3 \
    DEP_HATCHLING=hatchling==1.27.0

RUN python -m venv "$VENV" && \
    "$VENV/bin/pip" install --no-cache-dir -q --upgrade pip setuptools wheel "$DEP_HATCHLING" && \
    mkdir -p "$WHEELHOUSE" && \
    "$VENV/bin/pip" wheel -q -w "$WHEELHOUSE" pip setuptools wheel "$DEP_HATCHLING" && \
    "$VENV/bin/pip" wheel -q -w "$WHEELHOUSE" \
        "$DEP_ATTRS" "$DEP_COVERAGE" "$DEP_HTTPX2" "$DEP_PEXPECT" "$DEP_PYFTPDLIB" \
        "$DEP_PYGMENTS" "$DEP_PYTEST" "$DEP_PYTEST_COV" "$DEP_PYTEST_RERUN" \
        "$DEP_PYTEST_TIMEOUT" "$DEP_PYTEST_XDIST" "$DEP_SYBIL" "$DEP_PYTEST_TWISTED" && \
    "$VENV/bin/pip" wheel -q -w "$WHEELHOUSE" --no-build-isolation . && \
    "$VENV/bin/pip" install -q --no-index --find-links="$WHEELHOUSE" \
        "$DEP_ATTRS" "$DEP_COVERAGE" "$DEP_HTTPX2" "$DEP_PEXPECT" "$DEP_PYFTPDLIB" \
        "$DEP_PYGMENTS" "$DEP_PYTEST" "$DEP_PYTEST_COV" "$DEP_PYTEST_RERUN" \
        "$DEP_PYTEST_TIMEOUT" "$DEP_PYTEST_XDIST" "$DEP_SYBIL" "$DEP_PYTEST_TWISTED" && \
    "$VENV/bin/pip" install -q --no-index --find-links="$WHEELHOUSE" --no-build-isolation .

# mitmproxy in its own environment, exposing only the executable. The upstream
# job installs it with `uv tool install`, which keeps h2 out of the test
# environment; installing it into the test venv would un-skip six HTTP/2 tests
# that the reference cell skips.
ENV MITMPROXY_VERSION=12.2.3
RUN python -m venv /opt/mitm && \
    /opt/mitm/bin/pip install --no-cache-dir -q "mitmproxy==${MITMPROXY_VERSION}" && \
    ln -s /opt/mitm/bin/mitmdump /usr/local/bin/mitmdump && \
    mitmdump --version | head -1 && \
    ! "$VENV/bin/python" -c "import h2" 2>/dev/null

# The upstream job runs on GitHub Actions and tests may branch on this.
ENV GITHUB_ACTIONS=true

RUN mkdir -p /work /timing && chown -R runner:runner /work /timing /project

USER runner
