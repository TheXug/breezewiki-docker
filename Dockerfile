# BreezeWiki — built from source
# Upstream: https://gitdab.com/cadence/breezewiki  (docs: https://docs.breezewiki.com)
#
# There's no official Docker image, so this builds straight from the source
# tarball using the official Racket image, following the steps from
# docs.breezewiki.com/Running.html ("Running the source code" + the Docker note).

ARG RACKET_VERSION=8.18-full
FROM racket/racket:${RACKET_VERSION}

# Which branch/commit of BreezeWiki to build. Override with --build-arg to pin
# a specific commit hash from https://gitdab.com/cadence/breezewiki/commits/branch/main
ARG BREEZEWIKI_REF=main

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /breezewiki

# Fetch the source tarball straight from the repo (no git needed)
RUN curl -fsSL "https://gitdab.com/cadence/breezewiki/archive/${BREEZEWIKI_REF}.tar.gz" -o /tmp/breezewiki.tar.gz \
    && tar -xzf /tmp/breezewiki.tar.gz -C /breezewiki --strip-components=1 \
    && rm /tmp/breezewiki.tar.gz

# Install the `raco req` tool, then use it to pull in BreezeWiki's package
# dependencies (rackunit, web-server, http-easy, etc. — declared in info.rkt)
RUN raco pkg install --batch --auto --no-docs --skip-installed req-lib \
    && raco req -d

# Byte-compile so the container starts quickly instead of compiling on every boot
RUN raco make dist.rkt

# BreezeWiki config: either a config.ini file in the working directory, or
# environment variables prefixed with bw_ (these override the file).
# See: https://docs.breezewiki.com/Configuration.html
ENV bw_bind_host=0.0.0.0
ENV bw_port=10416

EXPOSE 10416

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${bw_port}/" || exit 1

CMD ["racket", "dist.rkt"]
