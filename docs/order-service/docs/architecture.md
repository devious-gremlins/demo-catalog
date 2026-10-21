# Architecture & Dependencies

## System Context

The Order Service operates as a core transactional service within the `e-commerce` system boundary.

```text
[ Web / Mobile Client ]
         │
         ▼
[ Order Service ] ──(REST)──▶ [ Payment API ]
         │
         ├──(gRPC)──▶ [ Inventory Service ]
         │
         └──(SQL)───▶ [ PostgreSQL Database (order-db) ]
```

## Component Dependencies

- **`payment-api`**: Authorizes payments and processes refunds.
- **`inventory-service`**: Confirms stock availability before finalizing order confirmation.
- **`order-db`**: Relational database storage for order transactional integrity.
