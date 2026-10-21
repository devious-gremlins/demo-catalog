# Order Service

The **Order Service** is the central component responsible for handling customer checkout, validating stock with the Inventory Service, and orchestrating billing transactions via the Payment API.

## Overview

- **Owner:** Platform Engineering Team (`group:default/engineering-team`)
- **System:** E-Commerce Platform (`system:default/e-commerce`)
- **Lifecycle:** Production
- **Type:** Backend Service

## Key Responsibilities

1. **Order Lifecycle Management**: Handles draft, pending, confirmed, and cancelled order states.
2. **Inventory Coordination**: Requests reservations from `inventory-service` during checkout.
3. **Payment Execution**: Integrates with `payment-api` to authorize credit card payments.
4. **Persistence**: Stores all order entities and audit events in PostgreSQL (`order-db`).
