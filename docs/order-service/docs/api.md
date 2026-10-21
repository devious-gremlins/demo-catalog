# API Reference

The Order Service exposes a RESTful HTTP API.

## Endpoints

### `POST /orders`

Create a new order from a shopping cart payload.

**Request:**
```json
{
  "customerId": "cust-8921",
  "items": [
    { "sku": "SKU-1002", "quantity": 2 }
  ],
  "paymentMethodId": "pm-card-4432"
}
```

**Response (`201 Created`):**
```json
{
  "orderId": "ord-98214",
  "status": "confirmed",
  "total": 149.98
}
```

### `GET /orders/:id`

Retrieve the current details and tracking status of an existing order.
