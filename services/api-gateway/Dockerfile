# Multi-stage build for Go API Gateway
FROM golang:1.25-alpine3.22 AS builder

# Pin package versions for reproducibility
RUN apk add --no-cache git=2.49.1-r0

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api-gateway .

FROM alpine:3.22

# Pin ca-certificates version and create non-root user in a single layer
RUN apk --no-cache add ca-certificates=20250619-r0 \
    && addgroup -g 10001 appgroup \
    && adduser -D -u 10001 -G appgroup appuser

WORKDIR /app

COPY --chown=appuser:appgroup --from=builder /app/api-gateway .

USER appuser

EXPOSE 8080 8081

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ready || exit 1

CMD ["./api-gateway"]
