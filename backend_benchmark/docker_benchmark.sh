#!/usr/bin/env bash
# Ejecutar en una máquina CON Docker y acceso a internet (el sandbox de esta
# conversación no tiene ninguno de los dos). Pensado para correr directamente
# en el VPS del curso.
set -euo pipefail
cd "$(dirname "$0")"

echo "=== 1. Construyendo las 4 imágenes ==="
docker compose build

echo
echo "=== 2. Tamaño final de cada imagen ==="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "bench-(go|node|python|java)|REPOSITORY"

echo
echo "=== 3. Levantando los contenedores (límites: 0.5 vCPU / 512MB cada uno) ==="
docker compose up -d
sleep 3

echo
echo "=== 4. Memoria en reposo por contenedor (docker stats) ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo
echo "=== 5. Prueba de carga (500 peticiones concurrentes) contra cada uno ==="
for puerto_nombre in "8081 go" "8082 node" "8083 python" "8084 java"; do
  set -- $puerto_nombre
  echo "--- $2 ---"
  go run ./loadtest.go "$1" 500 || echo "  (requiere Go instalado en la máquina que corre este script, no en los contenedores)"
done

echo
echo "=== 6. Memoria tras la carga ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo
echo "Para limpiar: docker compose down --rmi local"
