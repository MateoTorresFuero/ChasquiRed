# --- Etapa de compilación ---
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
# CGO_ENABLED=0: binario estático, sin dependencias de libc -> puede correr en 'scratch'
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app main.go

# --- Etapa final: imagen sin sistema operativo, solo el binario ---
FROM scratch
COPY --from=build /app /app
EXPOSE 8081
ENTRYPOINT ["/app"]
