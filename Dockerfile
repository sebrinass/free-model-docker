# free-model-docker — Our Free Model (OFM) standalone service container
#
# Upstream: https://github.com/Ebony-Vinyl/dsh-our-free-model (MIT, zero-dep JS)
# The build context must contain build/src/ — populated by scripts/fetch-source.sh
# (source comes from the upstream git tag tarball, NOT npm / GitHub Release).

FROM node:24-bookworm-slim

LABEL org.opencontainers.image.title="free-model-docker" \
      org.opencontainers.image.description="Our Free Model (OFM) standalone service in a container for Unraid; exposes an OpenAI-compatible LAN relay on 18901 for Octopus" \
      org.opencontainers.image.source="https://github.com/sebrinass/free-model-docker"

# curl: runtime tooling / fetching; ca-certificates: TLS; tini: init + signal handling
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*

# Bun is required by OFM's free-transport layer: OUR_FREE_MODEL_FREE_TRANSPORT
# defaults to auto (prefers bun); the node fallback is not guaranteed upstream.
RUN npm install -g bun \
    && bun --version

ENV OFM_HOME=/data \
    OUR_FREE_MODEL_FREE_TRANSPORT=bun \
    NODE_ENV=production

WORKDIR /app

# Upstream source pre-fetched by scripts/fetch-source.sh into build/src/
COPY build/src/ /app/

# Entrypoint: merges distribution=managed into settings.json, then starts the CLI
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 18901 = LAN relay bound to 0.0.0.0 — the only port Octopus talks to.
# 18900 (local inference + admin UI) is hard-bound to loopback by the project
# (no --host / OFM_ALLOW_NON_LOOPBACK support), so it is intentionally NOT exposed.
EXPOSE 18901

# Probe the in-container loopback health endpoint with node's built-in fetch
# (do not rely on curl in the healthcheck).
HEALTHCHECK --interval=30s --timeout=15s --start-period=90s --retries=10 \
    CMD node -e "fetch('http://127.0.0.1:18900/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
