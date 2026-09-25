FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /src
COPY Server.java ./
RUN javac Server.java

RUN jlink \
    --add-modules java.base,jdk.httpserver \
    --strip-debug \
    --no-header-files \
    --no-man-pages \
    --compress=2 \
    --output /javaruntime

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
