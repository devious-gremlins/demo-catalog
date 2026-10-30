#!/bin/bash
#
# Install the RHDHPLAN-552 demo into the rhdh-local customization workspace.
#
# The fixture is consumed by reference: this checkout is bind-mounted read-only
# into the RHDH container at configs/catalog-entities/demo, so the catalog
# entities and TechDocs sources always reflect this repository. Nothing is
# written into the rhdh-local clone; the files below go into
# rhdh-customizations/, which the rhdh-local skill copies from deliberately:
#
#   compose.override.yaml                                  mount of this checkout
#   configs/catalog-entities/components.override.yaml      entities, techdocs-ref rewritten
#   configs/dynamic-plugins/dynamic-plugins.override.yaml  the plugin set
#   configs/app-config/app-config.local.yaml               guest auth + extension scenes
#
# Usage:
#   ./setup-rhdh-local.sh            install (backs up any file it replaces)
#   ./setup-rhdh-local.sh --remove   delete the four files it manages
#   ./setup-rhdh-local.sh --dry-run  report what would change
#
# Then:
#   ~/bin/rhdh-local apply && ~/bin/rhdh-local up

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="# Managed by demo-catalog/setup-rhdh-local.sh"
MOUNT_TARGET="/opt/app-root/src/configs/catalog-entities/demo"

MODE="install"
for arg in "$@"; do
  case "$arg" in
    --remove) MODE="remove" ;;
    --dry-run) MODE="dry-run" ;;
    -h|--help)
      # Print the header comment block: everything after the shebang up to the
      # first line that is not a comment.
      awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *) echo "Unknown argument: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# --- locate the workspace ----------------------------------------------------

WORKSPACE="${RHDH_LOCAL_SETUP_DIR:-$HOME/Source/redhat-developer/rhdh-local-setup}"
CUSTOM="$WORKSPACE/rhdh-customizations"

if [[ ! -d "$CUSTOM" ]]; then
  cat >&2 <<EOF
Error: customization workspace not found at '$CUSTOM'

Set RHDH_LOCAL_SETUP_DIR to the directory holding rhdh-customizations/ and
rhdh-local/:
  export RHDH_LOCAL_SETUP_DIR=/path/to/rhdh-local-setup
EOF
  exit 1
fi

if [[ ! -e "$WORKSPACE/rhdh-local" ]]; then
  echo "Error: $WORKSPACE/rhdh-local is missing (expected the upstream clone)" >&2
  exit 1
fi

# --- the four managed files --------------------------------------------------

COMPOSE="$CUSTOM/compose.override.yaml"
ENTITIES="$CUSTOM/configs/catalog-entities/components.override.yaml"
PLUGINS="$CUSTOM/configs/dynamic-plugins/dynamic-plugins.override.yaml"
APPCONFIG="$CUSTOM/configs/app-config/app-config.local.yaml"

MANAGED=("$COMPOSE" "$ENTITIES" "$PLUGINS" "$APPCONFIG")

owns_file() {
  [[ -f "$1" ]] && head -1 "$1" | grep -qF "$MARKER"
}

# --- remove ------------------------------------------------------------------

if [[ "$MODE" == "remove" ]]; then
  failures=0
  for f in "${MANAGED[@]}"; do
    if [[ ! -e "$f" ]]; then
      continue
    fi
    if ! owns_file "$f"; then
      echo "skipped (not managed by this script): ${f#"$CUSTOM"/}" >&2
      failures=1
      continue
    fi
    rm -f "$f"
    echo "removed ${f#"$CUSTOM"/}"
  done
  echo ""
  echo "Run '~/bin/rhdh-local apply' to clear the copies from rhdh-local/, then"
  echo "'~/bin/rhdh-local down' to stop the demo stack."
  exit "$failures"
fi

# --- install -----------------------------------------------------------------

if [[ ! -f "$FIXTURE_DIR/catalog-info.yaml" ]]; then
  echo "Error: $FIXTURE_DIR/catalog-info.yaml is missing; is this the fixture checkout?" >&2
  exit 1
fi
if [[ ! -d "$FIXTURE_DIR/docs/order-service" ]]; then
  echo "Error: $FIXTURE_DIR/docs/order-service is missing; TechDocs would not build." >&2
  exit 1
fi

install_file() {
  local target="$1" label="${2:-}"
  local rel="${target#"$CUSTOM"/}"
  local body
  body="$(cat)"   # read the content first so a dry run never breaks the pipe

  if [[ -e "$target" ]] && ! owns_file "$target"; then
    local backup
    backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    if [[ "$MODE" == "dry-run" ]]; then
      echo "would back up $rel -> ${backup#"$CUSTOM"/} and replace it"
    else
      cp -p "$target" "$backup"
      echo "backed up $rel -> ${backup#"$CUSTOM"/}"
    fi
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    echo "would write $rel${label:+ ($label)}"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  printf '%s\n' "$body" > "$target"
  echo "wrote $rel${label:+ ($label)}"
}

# 1. Mount this checkout read-only where the catalog can reach it. The catalog
#    loads configs/catalog-entities/components.override.yaml relative to that
#    directory, and TechDocs resolves dir: refs relative to the same place.
install_file "$COMPOSE" "mounts the fixture" <<EOF
$MARKER
# Read-only mount of the demo-catalog fixture checkout. Entities and TechDocs
# sources are read straight from the repository, so there is nothing to copy.
# Remove this file if you would rather keep your own compose.override.yaml.
services:
  rhdh:
    volumes:
      - ${FIXTURE_DIR}:${MOUNT_TARGET}:ro,z
EOF

# 2. Entities. Generated from the repository's catalog-info.yaml on every run so
#    the demo cannot drift from the fixture. techdocs-ref is repointed from
#    dir:./docs/<service> to dir:./demo/docs/<service> because the checkout is
#    mounted under configs/catalog-entities/demo.
{
  echo "$MARKER"
  echo "# Generated from catalog-info.yaml in the demo-catalog repository."
  echo "# Do not edit: change the fixture and re-run the script."
  echo ""
  sed "s|dir:\./docs/|dir:./demo/docs/|g" "$FIXTURE_DIR/catalog-info.yaml"
} | install_file "$ENTITIES" "generated from catalog-info.yaml"

# 3. Dynamic plugins the demo needs.
install_file "$PLUGINS" "demo plugin set" <<'EOF'
# Managed by demo-catalog/setup-rhdh-local.sh
# Dynamic plugin override config for the RHDHPLAN-552 demo.

includes:
  - dynamic-plugins.default.yaml

plugins:
  # App Visualizer — inspect the NFS extension tree at /app-visualizer
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-plugin-app-visualizer:bs_1.54.6__0.2.7'
    enabled: true

  # Guest auth backend module for local development / cluster-free testing
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-plugin-auth-backend-module-guest-provider:bs_1.54.6__0.2.22'
    enabled: true

  # GitHub Actions frontend plugin (NFS) — provides the CI/CD tab and overview card
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-github-actions:bs_1.54.6__1.4.0'
    enabled: true

  # Org plugin — provides User and Group profile cards
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-plugin-org:bs_1.54.6__0.7.8'
    enabled: true

  # Disable Segment analytics to avoid CSP violations and external telemetry
  - package: 'oci://quay.io/rhdh/backstage-community-plugin-analytics-provider-segment:{{inherit}}'
    enabled: false
EOF

# 4. Local app-config: guest auth and the extension scenes. catalog.locations is
#    deliberately absent — the entities ride in through components.override.yaml,
#    so overriding that array (which would drop the default locations) is not
#    needed.
install_file "$APPCONFIG" "guest auth + extension scenes" <<'EOF'
# Managed by demo-catalog/setup-rhdh-local.sh
auth:
  environment: development
  providers:
    guest:
      dangerouslyAllowOutsideDevelopment: true

app:
  extensions:
    # Base NFS configuration (home page and RHDH sidebar)
    - nav-content:app: false
    - page:home:
        config:
          path: /
    - api:home/visits: true
    - app-root-element:home/visit-listener: true
    - home-page-widget:search/search-bar: false

    # -------------------------------------------------------------------------
    # Scene 2: Company A — "DevOps-centric organization"
    # Uncomment this block and keep Scene 3 commented out.
    # -------------------------------------------------------------------------
    # - entity-content:catalog/overview:
    #     config:
    #       group: overview
    # - entity-content:github-actions:
    #     config:
    #       title: CI/CD
    #       group: ci-cd
    # - entity-content:techdocs:
    #     config:
    #       title: Documentation
    #       group: documentation
    #       filter:
    #         $not:
    #           kind:
    #             $in: [user, group]
    # - page:catalog/entity:
    #     config:
    #       groups:
    #         - overview:
    #             title: Overview
    #         - ci-cd:
    #             title: CI/CD
    #         - documentation:
    #             title: Documentation

    # -------------------------------------------------------------------------
    # Scene 3: Company B — "Architecture and dependency governance"
    # Uncomment this block and keep Scene 2 commented out.
    # -------------------------------------------------------------------------
    # - entity-content:catalog/overview:
    #     config:
    #       group: overview
    # - entity-content:api-docs/apis:
    #     config:
    #       title: API Specifications
    #       group: apis
    # - entity-content:techdocs:
    #     config:
    #       title: Documentation
    #       group: documentation
    #       filter:
    #         $not:
    #           kind:
    #             $in: [user, group]
    # - entity-content:github-actions: false
    # - entity-card:github-actions/recent-workflow-runs: false
    # - page:catalog/entity:
    #     config:
    #       groups:
    #         - overview:
    #             title: Overview
    #         - apis:
    #             title: API Specifications
    #         - documentation:
    #             title: Documentation
    # # Re-attach the dependency cards from the Dependencies tab onto Overview:
    # - entity-card:catalog/depends-on-resources:
    #     attachTo:
    #       id: entity-content:catalog/overview
    #       input: cards
    # - entity-card:catalog/depends-on-components:
    #     attachTo:
    #       id: entity-content:catalog/overview
    #       input: cards
    # # Suppress the bulky relations graph
    # - entity-card:catalog-graph/relations: false
EOF

echo ""
if [[ "$MODE" == "dry-run" ]]; then
  echo "Dry run: nothing written."
  exit 0
fi

cat <<EOF
Next:
  ~/bin/rhdh-local apply   # copy the customizations into rhdh-local/
  ~/bin/rhdh-local up      # apply + podman compose up -d

Verify:
  1. Homepage:     http://localhost:7007/
  2. Catalog:      http://localhost:7007/catalog
  3. Order Service http://localhost:7007/catalog/default/component/order-service
  4. TechDocs:     http://localhost:7007/docs
  5. Visualizer:   http://localhost:7007/app-visualizer

The fixture itself is mounted read-only from:
  $FIXTURE_DIR
EOF
