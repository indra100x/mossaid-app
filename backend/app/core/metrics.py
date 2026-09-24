from prometheus_client import Counter, Histogram

http_requests_total = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
http_request_duration_seconds = Histogram("http_request_duration_seconds", "HTTP request duration", ["endpoint"])
booking_status_changes = Counter("booking_status_changes_total", "Booking status transitions", ["from_status", "to_status"])
payment_held_total = Counter("payment_held_total", "Payments held via Chargily")
payment_released_total = Counter("payment_released_total", "Payments released to craftsman")
payment_disputed_total = Counter("payment_disputed_total", "Payments disputed")
