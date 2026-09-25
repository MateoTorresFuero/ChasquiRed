FROM python:3.12-alpine
WORKDIR /app
COPY server.py ./
EXPOSE 8083
RUN adduser -D appuser
USER appuser
CMD ["python3", "server.py"]
