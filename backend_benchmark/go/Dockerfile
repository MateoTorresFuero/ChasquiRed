FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app main.go

FROM scratch
COPY --from=build /app /app
EXPOSE 8081
ENTRYPOINT ["/app"]
