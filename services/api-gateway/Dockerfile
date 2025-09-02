# Multi-stage build for Go API Gateway
FROM golang:1.25-alpine3.22 AS builder

RUN apk add --no-cache git

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api-gateway .

FROM alpine:3.22

RUN apk --no-cache add ca-certificates

RUN adduser -D -u 1000 appuser

WORKDIR /app

COPY --from=builder /app/api-gateway .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

CMD ["./api-gateway"]
