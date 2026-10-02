# Reference cell: tests-ubuntu.yml, job `tests`, python-version 3.13, TOXENV=py,
# at tag 2.14.0 (same cell as the HEAD campaign; see the fidelity note).
# CPython 3.13.11 is the 3.13 release setup-python resolved on 2026-01-05, the date
# of the tag's reference run; the base is pinned by digest.
FROM python:3.13.11-slim-bookworm@sha256:20080e807bfc404f8450b185cf0fc95d553462673598549613735f70a5b4d5d0

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
# available on 2026-01-05 (the tag's reference run); one version per wheel.
RUN printf '%s\n' \
        "attrs==25.4.0" \
        "automat==25.4.16" \
        "certifi==2026.1.4" \
        "cffi==2.0.0" \
        "charset-normalizer==3.4.4" \
        "constantly==23.10.4" \
        "coverage==7.13.1" \
        "cryptography==46.0.3" \
        "cssselect==1.3.0" \
        "decorator==5.2.1" \
        "defusedxml==0.7.1" \
        "execnet==2.1.2" \
        "filelock==3.20.2" \
        "greenlet==3.3.0" \
        "hatchling==1.27.0" \
        "hyperlink==21.0.0" \
        "idna==3.11" \
        "incremental==24.11.0" \
        "iniconfig==2.3.0" \
        "itemadapter==0.13.0" \
        "itemloaders==1.3.2" \
        "jmespath==1.0.1" \
        "lxml==6.0.2" \
        "packaging==25.0" \
        "parsel==1.10.0" \
        "pathspec==0.12.1" \
        "pexpect==4.9.0" \
        "pip==25.3" \
        "pluggy==1.6.0" \
        "protego==0.5.0" \
        "ptyprocess==0.7.0" \
        "pyasn1-modules==0.4.2" \
        "pyasn1==0.6.1" \
        "pyasynchat==1.0.4" \
        "pyasyncore==1.0.4" \
        "pycparser==2.23" \
        "pydispatcher==2.0.7" \
        "pyftpdlib==2.1.0" \
        "pygments==2.19.2" \
        "pyopenssl==25.3.0" \
        "pytest-cov==7.0.0" \
        "pytest-twisted==1.14.3" \
        "pytest-xdist==3.8.0" \
        "pytest==9.0.2" \
        "queuelib==1.8.0" \
        "requests-file==3.0.1" \
        "requests==2.32.5" \
        "service-identity==24.2.0" \
        "setuptools==80.9.0" \
        "sybil==9.3.0" \
        "testfixtures==10.0.0" \
        "tldextract==5.3.1" \
        "trove-classifiers==2025.12.1.14" \
        "twisted==25.5.0" \
        "typing-extensions==4.15.0" \
        "urllib3==2.6.2" \
        "w3lib==2.3.1" \
        "wheel==0.45.1" \
        "zope-interface==8.1.1" \
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
        attrs coverage pexpect pyftpdlib pygments pytest \
        pytest-cov pytest-xdist sybil testfixtures pytest-twisted

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
