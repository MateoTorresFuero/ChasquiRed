#!/usr/bin/env bash
# Compara arranque en frío, memoria RSS en reposo y latencia bajo carga
# para los 4 servidores equivalentes (mismo endpoint /cercanos).
set -uo pipefail
cd "$(dirname "$0")"

N=500  # peticiones concurrentes por ronda

medir() {
  local nombre="$1"; local puerto="$2"; shift 2
  local cmd=("$@")

  echo "=== $nombre (puerto $puerto) ==="

  # --- Arranque en frío ---
  local t0 t1
  t0=$(date +%s.%N)
  "${cmd[@]}" > "/tmp/${nombre}.log" 2>&1 &
  local pid=$!

  # esperar a que /healthz responda (máx 30s)
  local listo=0
  for i in $(seq 1 300); do
    if curl -s -o /dev/null -m 0.2 "http://localhost:${puerto}/healthz"; then
      listo=1
      break
    fi
    sleep 0.1
  done
  t1=$(date +%s.%N)

  if [ "$listo" -eq 0 ]; then
    echo "  NO LEVANTÓ el servidor. Log:"
    cat "/tmp/${nombre}.log"
    kill "$pid" 2>/dev/null
    return
  fi

  local arranque
  arranque=$(echo "$t1 - $t0" | bc)
  printf "  arranque_en_frio: %.3fs\n" "$arranque"

  # dar tiempo a que se estabilice (JIT warmup para Java, etc.)
  sleep 0.5

  # --- Memoria RSS en reposo ---
  local rss_kb
  rss_kb=$(grep VmRSS "/proc/${pid}/status" 2>/dev/null | awk '{print $2}')
  # para node/java puede haber un proceso hijo (p.ej. java lanza el mismo pid, node igual)
  printf "  rss_en_reposo: %s MB\n" "$(echo "scale=1; ${rss_kb:-0}/1024" | bc)"

  # --- Latencia bajo carga (500 peticiones concurrentes) ---
  local resultado
  resultado=$(go run loadtest.go "$puerto" "$N")
  echo "  carga: $resultado"

  # RSS post-carga (tras servir tráfico real)
  local rss_post_kb
  rss_post_kb=$(grep VmRSS "/proc/${pid}/status" 2>/dev/null | awk '{print $2}')
  printf "  rss_post_carga: %s MB\n" "$(echo "scale=1; ${rss_post_kb:-0}/1024" | bc)"

  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  sleep 0.3
  echo
}

medir go       8081 ./go/bench-go
medir node     8082 node ./node/server.js
medir python   8083 python3 ./python/server.py
medir java     8084 java -cp ./java Server
