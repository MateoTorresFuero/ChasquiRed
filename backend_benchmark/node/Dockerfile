FROM node:22-alpine
WORKDIR /app
COPY server.js ./
EXPOSE 8082
# Ejecuta como usuario no-root (buena práctica de seguridad, RNF-002)
USER node
CMD ["node", "server.js"]
