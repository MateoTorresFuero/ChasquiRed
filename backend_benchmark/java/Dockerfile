# --- Etapa de compilación + runtime mínimo con jlink ---
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /src
COPY Server.java ./
RUN javac Server.java
# jlink genera un runtime Java a medida, incluyendo SOLO los módulos que
# este programa usa (java.base + jdk.httpserver), en vez de cargar el JDK
# completo (~300MB+). Esto es lo más parecido que tiene Java al binario
# estático de Go: sigue siendo mucho más pesado, pero reduce bastante
# el tamaño frente a copiar el JDK completo a producción.
RUN jlink \
    --add-modules java.base,jdk.httpserver \
    --strip-debug \
    --no-header-files \
    --no-man-pages \
    --compress=2 \
    --output /javaruntime

# --- Etapa final: alpine + runtime a medida, sin el JDK de compilación ---
FROM alpine:3.20
RUN apk add --no-cache libc6-compat
COPY --from=build /javaruntime /opt/java
COPY --from=build /src/*.class /app/
ENV PATH="/opt/java/bin:${PATH}"
WORKDIR /app
EXPOSE 8084
RUN adduser -D appuser
USER appuser
CMD ["java", "Server"]
