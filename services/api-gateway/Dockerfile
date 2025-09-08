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
    && adduser -D -u 1000 appuser

WORKDIR /app

COPY --chown=appuser:appuser --from=builder /app/api-gateway .

USER appuser

EXPOSE 8080

CMD ["./api-gateway"]
