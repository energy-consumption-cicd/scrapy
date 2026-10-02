# Reference cell: tests-ubuntu.yml, job `tests`, python-version 3.13, TOXENV=py,
# at tag 2.16.0 (same cell as the HEAD campaign; see the fidelity note).
# CPython 3.13.13 is the 3.13 release setup-python resolved on 2026-05-19, the date
# of the tag's reference run; the base is pinned by digest.
FROM python:3.13.13-slim-bookworm@sha256:355bfa66770995d7e9a0da4b3473b44d0cb451f6b56f5615ad9c39e3c4eca03f

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

ENV VENV=/venv
ENV WHEELHOUSE=/wheelhouse

# The tag pins nothing, so every distribution is fixed to the newest release
# available on 2026-05-19 (the tag's reference run); one version per wheel.
RUN printf '%s\n' \
        "anyio==4.13.0" \
        "attrs==26.1.0" \
        "automat==25.4.16" \
        "certifi==2026.4.22" \
        "cffi==2.0.0" \
        "charset-normalizer==3.4.7" \
        "constantly==23.10.4" \
        "coverage==7.14.0" \
        "cryptography==48.0.0" \
        "cssselect==1.4.0" \
        "decorator==5.3.1" \
        "defusedxml==0.7.1" \
        "execnet==2.1.2" \
        "filelock==3.29.0" \
        "greenlet==3.5.0" \
        "h11==0.16.0" \
        "hatchling==1.27.0" \
        "httpcore==1.0.9" \
        "httpx==0.28.1" \
        "hyperlink==21.0.0" \
        "idna==3.15" \
        "incremental==24.11.0" \
        "iniconfig==2.3.0" \
        "itemadapter==0.13.1" \
        "itemloaders==1.4.0" \
        "jmespath==1.1.0" \
        "lxml==6.1.1" \
        "packaging==26.2" \
        "parsel==1.11.0" \
        "pathspec==1.1.1" \
        "pexpect==4.9.0" \
        "pip==26.1.1" \
        "pluggy==1.6.0" \
        "protego==0.6.0" \
        "ptyprocess==0.7.0" \
        "pyasn1-modules==0.4.2" \
        "pyasn1==0.6.3" \
        "pyasynchat==1.0.5" \
        "pyasyncore==1.0.5" \
        "pycparser==3.0" \
        "pydispatcher==2.0.7" \
        "pyftpdlib==2.2.0" \
        "pygments==2.20.0" \
        "pyopenssl==26.2.0" \
        "pytest-cov==7.1.0" \
        "pytest-twisted==1.14.3" \
        "pytest-xdist==3.8.0" \
        "pytest==9.0.3" \
        "queuelib==1.9.0" \
        "requests-file==3.0.1" \
        "requests==2.34.2" \
        "service-identity==24.2.0" \
        "setuptools==82.0.1" \
        "sybil==10.0.1" \
        "testfixtures==11.0.0" \
        "tldextract==5.3.1" \
        "trove-classifiers==2026.5.7.17" \
        "twisted==26.4.0" \
        "typing-extensions==4.15.0" \
        "urllib3==2.7.0" \
        "w3lib==2.4.1" \
        "wheel==0.47.0" \
        "zope-interface==8.4" \
        > /opt/constraints.txt

# Wheels for the whole pinned set (tox.ini [test-requirements] and [testenv] at
# the tag, Scrapy's own requirements, build tools) are built at image build time
# so the measured build stage installs offline (RAPL has no network domain).
RUN python -m venv "$VENV" && \
    "$VENV/bin/pip" install --no-cache-dir -q -c /opt/constraints.txt \
        --upgrade pip setuptools wheel hatchling && \
    mkdir -p "$WHEELHOUSE" && \
    "$VENV/bin/pip" wheel -q -w "$WHEELHOUSE" -c /opt/constraints.txt \
        $(sed -n 's/==.*//p' /opt/constraints.txt) && \
    "$VENV/bin/pip" install -q --no-index --find-links="$WHEELHOUSE" \
        -c /opt/constraints.txt \
        attrs coverage httpx pexpect pyftpdlib pygments \
        pytest pytest-cov pytest-xdist sybil testfixtures pytest-twisted

COPY . /project
WORKDIR /project

# The project wheel is built offline against the wheelhouse, which proves the
# pinned set is complete; a second version of any distribution is refused.
RUN "$VENV/bin/pip" wheel -q -w "$WHEELHOUSE" --no-index --find-links="$WHEELHOUSE" \
        --no-build-isolation . && \
    "$VENV/bin/pip" install -q --no-index --find-links="$WHEELHOUSE" \
        --no-build-isolation . && \
    test -z "$(ls "$WHEELHOUSE" | sed 's/-[0-9].*//' | tr 'A-Z-' 'a-z_' | sort | uniq -d)" && \
    ! "$VENV/bin/python" -c "import h2" 2>/dev/null && \
    ! "$VENV/bin/python" -c "import mitmproxy" 2>/dev/null

# The upstream job runs on GitHub Actions and tests may branch on this.
ENV GITHUB_ACTIONS=true

RUN mkdir -p /work /timing && chown -R runner:runner /work /timing /project

USER runner
