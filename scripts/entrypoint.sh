#!/bin/sh
set -e

mkdir -p "$OFM_HOME"

# Merge (never clobber) distribution=managed into $OFM_HOME/settings.json.
# distribution=managed disables self-updater / announcement feed / hot reload
# inside the container; upgrades happen by rebuilding the image.
# The base image has no jq, so use node itself for the JSON merge.
node <<'EOF'
const fs = require("fs");
const p = process.env.OFM_HOME + "/settings.json";
let s = {};
try {
  s = JSON.parse(fs.readFileSync(p, "utf8"));
} catch (e) {
  s = {};
}
if (typeof s !== "object" || s === null || Array.isArray(s)) {
  s = {};
}
s.distribution = "managed";
fs.writeFileSync(p, JSON.stringify(s, null, 2) + "\n");
EOF

# 18901 is the LAN relay (bound to 0.0.0.0) that Octopus talks to.
# 18900 stays loopback-only by upstream design.
exec node packages/standalone/cli.mjs --lan --lan-port "${OFM_LAN_PORT:-18901}" "$@"
