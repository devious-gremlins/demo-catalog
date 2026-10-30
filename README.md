# RHDHPLAN-552 Demo Catalog & Setup Guide

This directory provides sample Backstage catalog entities and declarative configuration snippets to demonstrate **RHDHPLAN-552**: *Declarative Entity Page & Plugin Customization via the New Frontend System (NFS)*.

---

## Catalog Entities Overview

The entities in `catalog-info.yaml` represent a realistic e-commerce microservices architecture:

| Entity Kind | Name | Purpose in Demo |
| ----------- | ---- | --------------- |
| `Component` | `order-service` | Primary demo service: defines `metadata.links`, TechDocs annotation, provided APIs (`payment-api`), and dependencies (`order-db`, `inventory-service`). Demonstrates both customization models: **Company A (DevOps layout)** vs **Company B (Architecture & Dependencies layout)**. |
| `Component` | `inventory-service` | Supporting microservice consumed by `order-service` with its own TechDocs. |
| `API` | `payment-api` | OpenAPI specification provided by `order-service`. |
| `Resource` | `order-db` | Transactional PostgreSQL database resource consumed by `order-service`. |
| `System` | `e-commerce` | Parent system grouping platform services. |
| `Group` | `engineering-team` | Team ownership entity. |
| `User` | `alex-developer` | User profile entity. |

---

## Dynamic Plugins Rundown

The setup script configures `configs/dynamic-plugins/dynamic-plugins.override.yaml` with the minimal set of dynamic plugins required for this demo:

| Plugin Package | Purpose in Demo |
| -------------- | --------------- |
| `backstage-plugin-app-visualizer` | Mounts the App Visualizer at `/app-visualizer` to inspect the live New Frontend System extension tree, attachment points, inputs, and outputs. |
| `backstage-plugin-auth-backend-module-guest-provider` | Enables guest authentication so local instances can start and authenticate immediately without external OAuth credentials. |
| `backstage-community-plugin-github-actions` | Provides the GitHub Actions tab (`entity-content:github-actions`) and overview card (`entity-card:github-actions/recent-workflow-runs`) used in Company A's DevOps view. |
| `backstage-plugin-org` | Provides the `user-profile`, `group-profile`, and `ownership` cards for User and Group entities. |
| `backstage-plugin-auth-backend-module-github-provider` | GitHub authentication backend module (optional). |
| `backstage-community-plugin-analytics-provider-segment` | Explicitly **disabled** (`enabled: false`) to prevent external telemetry and Content Security Policy (CSP) errors in local demo environments. |

> **Note on Core Plugins:** Standard Backstage plugins (`catalog`, `techdocs`, `api-docs`, `catalog-graph`) are baked into the core RHDH container image as built-in NFS plugins.

---

## Quick Setup with `rhdh-local`

### 1. Set your `rhdh-local` clone path:
Set `RHDH_LOCAL_DIR` to the location of your local `rhdh-local` checkout:
```bash
export RHDH_LOCAL_DIR="${RHDH_LOCAL_DIR:-$HOME/Source/redhat-developer/rhdh-local}"
```

### 2. Deploy configuration & entities:
Run the setup script from this directory:
```bash
./setup-rhdh-local.sh
```
*(This script copies `catalog-info.yaml` and the `docs/` tree it references into `configs/catalog-entities/`, configures `dynamic-plugins.override.yaml`, and prepares `app-config.local.yaml` with the home page enabled and both demo customization blocks commented out)*

### 3. Start your local RHDH instance:
```bash
cd "$RHDH_LOCAL_DIR"
podman compose up -d
```

Verify in your browser:
- **Homepage:** `http://localhost:7007/` (loads cleanly)
- **Catalog:** `http://localhost:7007/catalog` (order-service, inventory-service, payment-api, alex-developer)
- **TechDocs:** `http://localhost:7007/docs` (Order Service, Inventory Service docs)
- **Extension Visualizer:** `http://localhost:7007/app-visualizer`

---

## Demo Customization Walkthrough

Keep `$RHDH_LOCAL_DIR/configs/app-config/app-config.local.yaml` open in your text editor.

### Scene 1: Baseline (Out-of-the-Box Defaults)
- Open `http://localhost:7007/catalog/default/component/order-service`.
- Point out default tab titles (`Overview`, `GitHub Actions`, `TechDocs`, `APIs`).
- Point out that dependencies are not surfaced on the Overview page.

### Scene 2: Company A — "DevOps-Centric Organization"
- In `configs/app-config/app-config.local.yaml`, uncomment the **Scene 2** block:
  - Keeps `Overview` first as the default landing view.
  - Renames `GitHub Actions` to standardized `CI/CD` (`title: CI/CD`) and places it second.
  - Renames `TechDocs` to `Documentation`.
  - Tab order: **Overview | CI/CD | Documentation | APIs**.
- Save file and restart:
  ```bash
  cd "$RHDH_LOCAL_DIR" && podman compose stop rhdh && podman compose start rhdh
  ```
- Refresh `order-service` to show the standardized developer experience.

### Scene 3: Company B — "Architecture & Dependency Governance"
- Comment out Scene 2, and uncomment the **Scene 3** block:
  - Restructures navigation: **Overview | API Specifications | Documentation**.
  - Suppresses CI/CD tab and card (`github-actions` tab and `recent-workflow-runs` card set to `false`).
  - **Re-attaches Dependency Cards to Overview:** In RHDH, `depends-on-resources` and `depends-on-components` are attached to a separate Dependencies tab by default. Using `attachTo: { id: entity-content:catalog/overview, input: cards }`, they are pulled onto the Overview page in ordered sequence (database resources first, microservices second).
  - Turns off bulky relations graph (`entity-card:catalog-graph/relations: false`).
- Save file and restart:
  ```bash
  cd "$RHDH_LOCAL_DIR" && podman compose stop rhdh && podman compose start rhdh
  ```
- Refresh `order-service` to show the single-pane-of-glass architecture overview.
