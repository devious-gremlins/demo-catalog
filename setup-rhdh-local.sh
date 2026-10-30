#!/bin/bash
# Helper script to set up rhdh-local for RHDHPLAN-552 demo

set -euo pipefail

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${RHDH_LOCAL_DIR:-}" ]]; then
  if [[ -d "$DEMO_DIR/../rhdh-local" ]]; then
    RHDH_LOCAL_DIR="$(cd "$DEMO_DIR/../rhdh-local" && pwd)"
  elif [[ -d "$HOME/Source/redhat-developer/rhdh-local" ]]; then
    RHDH_LOCAL_DIR="$HOME/Source/redhat-developer/rhdh-local"
  else
    echo "Error: RHDH_LOCAL_DIR is not set and rhdh-local could not be located." >&2
    echo "Please specify your rhdh-local directory:" >&2
    echo "  export RHDH_LOCAL_DIR=/path/to/your/rhdh-local" >&2
    echo "  $0" >&2
    exit 1
  fi
fi

if [[ ! -d "$RHDH_LOCAL_DIR" ]]; then
  echo "Error: rhdh-local directory not found at '$RHDH_LOCAL_DIR'" >&2
  echo "Please set RHDH_LOCAL_DIR to your rhdh-local clone:" >&2
  echo "  export RHDH_LOCAL_DIR=/path/to/your/rhdh-local" >&2
  exit 1
fi

CATALOG_DEST="$RHDH_LOCAL_DIR/configs/catalog-entities"
APP_CONFIG_LOCAL="$RHDH_LOCAL_DIR/configs/app-config/app-config.local.yaml"
DYNAMIC_PLUGINS_OVERRIDE="$RHDH_LOCAL_DIR/configs/dynamic-plugins/dynamic-plugins.override.yaml"

echo "=== Setting up rhdh-local for RHDHPLAN-552 Demo ==="
echo "Target rhdh-local directory: $RHDH_LOCAL_DIR"

# 1. Copy the published fixture verbatim: entities plus the TechDocs sources
# they reference. `catalog-info.yaml` records `techdocs-ref: dir:./docs/<service>`,
# so the docs/ tree has to land beside it with the same relative layout.
echo "1. Deploying demo catalog entities and TechDocs documentation..."
mkdir -p "$CATALOG_DEST"
cp -f "$DEMO_DIR/catalog-info.yaml" "$CATALOG_DEST/components.override.yaml"
rm -rf "$CATALOG_DEST/docs"
cp -rf "$DEMO_DIR/docs" "$CATALOG_DEST/docs"

# Ensure container user (uid 1001) can read/write catalog and techdocs files
chmod -R a+rwX "$CATALOG_DEST"

# 2. Configure dynamic-plugins.override.yaml
echo "2. Configuring dynamic-plugins.override.yaml (enabling required demo plugins)..."
cat <<'EOF' > "$DYNAMIC_PLUGINS_OVERRIDE"
# Dynamic plugin override config for rhdh-local

includes:
  - dynamic-plugins.default.yaml

plugins:
  # App Visualizer — inspect the NFS extension tree at /app-visualizer
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-plugin-app-visualizer:bs_1.54.6__0.2.7'
    enabled: true

  # Guest auth backend module for local development / cluster-free testing
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-plugin-auth-backend-module-guest-provider:bs_1.54.6__0.2.22'
    enabled: true

  # GitHub auth backend module (optional)
  - package: 'oci://quay.io/rhdh/backstage-plugin-auth-backend-module-github-provider:{{inherit}}'
    enabled: true

  # GitHub Actions frontend plugin (NFS) — provides CI/CD tab & overview card
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-github-actions:bs_1.54.6__1.4.0'
    enabled: true

  # Org plugin — provides User and Group profile cards
  - package: 'oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-plugin-org:bs_1.54.6__0.7.8'
    enabled: true

  # Disable Segment analytics plugin to avoid CSP violations and external telemetry in local demo
  - package: 'oci://quay.io/rhdh/backstage-community-plugin-analytics-provider-segment:{{inherit}}'
    enabled: false
EOF

# 3. Configure baseline app-config.local.yaml with home page, github, and demo snippets
echo "3. Initializing app-config.local.yaml with base home page and demo snippets..."
cat <<'EOF' > "$APP_CONFIG_LOCAL"
auth:
  environment: development
  providers:
    guest:
      dangerouslyAllowOutsideDevelopment: true
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
              dangerouslyAllowSignInWithoutUserInCatalog: true

integrations:
  github:
    - host: github.com
      apps:
        - $include: ../extra-files/github-app-credentials.yaml

app:
  title: Red Hat Developer Hub
  baseUrl: ${BASE_URL}
  branding:
    fullLogoWidth: ${FULL_LOGO_WIDTH}
    theme:
      light:
        palette:
          primary:
            main: ${PRIMARY_LIGHT_COLOR}
          navigation:
            indicator: ${NAV_INDICATOR_LIGHT_COLOR}
        pageTheme:
          default:
            backgroundColor:
              - ${HEADER_LIGHT_COLOR_1}
              - ${HEADER_LIGHT_COLOR_2}
      dark:
        palette:
          primary:
            main: ${PRIMARY_DARK_COLOR}
          navigation:
            indicator: ${NAV_INDICATOR_DARK_COLOR}
        pageTheme:
          default:
            backgroundColor:
              - ${HEADER_DARK_COLOR_1}
              - ${HEADER_DARK_COLOR_2}

  extensions:
    # --------------------------------------------------------------------------
    # Base NFS Configuration (Home Page & RHDH Sidebar)
    # --------------------------------------------------------------------------
    - nav-content:app: false
    - page:home:
        config:
          path: /
    - api:home/visits: true
    - app-root-element:home/visit-listener: true
    - home-page-widget:search/search-bar: false

    # --------------------------------------------------------------------------
    # DEMO SCENE 2: Company A — "DevOps-Centric Organization"
    # Focus: Developer velocity, standardized CI/CD pipelines, documentation
    # To enable: uncomment this block (and keep Scene 3 commented out)
    # --------------------------------------------------------------------------
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

    # --------------------------------------------------------------------------
    # DEMO SCENE 3: Company B — "Architecture & Dependency Governance Organization"
    # Focus: Single-pane-of-glass overview with ordered dependencies, API contracts
    # To enable: comment out Scene 2 above and uncomment this block below
    # --------------------------------------------------------------------------
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
    # # Re-attach Dependency Cards from the Dependencies tab onto Overview & order them:
    # # 1. Database & resource dependencies table first
    # - entity-card:catalog/depends-on-resources:
    #     attachTo:
    #       id: entity-content:catalog/overview
    #       input: cards
    # # 2. Downstream microservice dependencies table second
    # - entity-card:catalog/depends-on-components:
    #     attachTo:
    #       id: entity-content:catalog/overview
    #       input: cards
    # # 3. Suppress bulky relations graph
    # - entity-card:catalog-graph/relations: false
EOF

echo ""
echo "Setup complete!"
echo ""
echo "To restart RHDH with the new setup:"
echo "  cd \"$RHDH_LOCAL_DIR\" && podman compose stop rhdh && podman compose start rhdh"
echo "  (or: cd \"$RHDH_LOCAL_DIR\" && podman compose down && podman compose up -d)"
echo ""
echo "Verify:"
echo "  1. Homepage: http://localhost:7007/ (loads cleanly, no 404)"
echo "  2. Catalog:  http://localhost:7007/catalog"
echo "  3. Order Service: http://localhost:7007/catalog/default/component/order-service"
echo "  4. TechDocs: http://localhost:7007/docs"
