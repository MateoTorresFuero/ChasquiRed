#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No encuentro .env junto a este script. Creá uno con GO_PORT, NODE_PORT, PYTHON_PORT, JAVA_PORT."
  exit 1
fi
set -a
source .env
set +a

GO_PORT="${GO_PORT:-8081}"
NODE_PORT="${NODE_PORT:-8082}"
PYTHON_PORT="${PYTHON_PORT:-8083}"
JAVA_PORT="${JAVA_PORT:-8084}"

N="${LOAD_N:-500}"
WARMUP_N="${WARMUP_N:-3000}"

echo "Puertos leídos de .env: go=$GO_PORT node=$NODE_PORT python=$PYTHON_PORT java=$JAVA_PORT"
echo

medir() {
  local nombre="$1"; local puerto="$2"; shift 2
  local cmd=("$@")

  echo "=== $nombre (puerto $puerto) ==="

  local t0 t1
  t0=$(date +%s.%N)
  PORT="$puerto" "${cmd[@]}" > "/tmp/${nombre}.log" 2>&1 &
  local pid=$!

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

  sleep 0.5

  echo "  calentando ($WARMUP_N peticiones descartadas)..."
  go run loadtest.go "$puerto" "$WARMUP_N" > /dev/null 2>&1

  local resultado
  resultado=$(go run loadtest.go "$puerto" "$N")
  echo "  carga: $resultado"

  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  sleep 0.3
  echo
}

medir go       "$GO_PORT"     ./go/bench-go
medir node     "$NODE_PORT"   node ./node/server.js
medir java     "$JAVA_PORT"   java -Dsun.net.httpserver.nodelay=true -cp ./java Server
medir python   "$PYTHON_PORT" python3 ./python/server.py
