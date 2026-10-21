# Inventory Service

The **Inventory Service** maintains real-time item counts and stock levels across regional fulfillment centers.

## Overview

- **Owner:** Platform Engineering Team (`group:default/engineering-team`)
- **System:** E-Commerce Platform (`system:default/e-commerce`)
- **Lifecycle:** Production
- **Type:** Backend Service

## Features

- Real-time stock reservation during active checkout sessions.
- Multi-warehouse inventory synchronization.
- Low-stock alerting events published to the message broker.
