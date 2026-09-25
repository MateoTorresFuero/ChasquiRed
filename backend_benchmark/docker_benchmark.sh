#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No encuentro .env junto a este script. Copiá el .env de ejemplo o creá uno con GO_PORT, NODE_PORT, PYTHON_PORT, JAVA_PORT."
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

echo "Puertos leídos de .env: go=$GO_PORT node=$NODE_PORT python=$PYTHON_PORT java=$JAVA_PORT"
echo

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
docker compose ps

echo
echo "=== 4. Memoria en reposo por contenedor (docker stats) ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "bench-(go|node|python|java)|NAME"

load_test() {
  local url="$1"
  local n="$2"
  local tmpdir
  tmpdir=$(mktemp -d)

  local t_inicio t_fin
  t_inicio=$(date +%s.%N)
  for i in $(seq 1 "$n"); do
    ( curl -s -o /dev/null -w "%{time_total}\n" -m 10 "$url" > "$tmpdir/$i" 2>/dev/null || echo "ERROR" > "$tmpdir/$i" ) &
  done
  wait
  t_fin=$(date +%s.%N)

  local total_wall
  total_wall=$(awk -v a="$t_inicio" -v b="$t_fin" 'BEGIN{printf "%.3f", b-a}')

  cat "$tmpdir"/* | awk -v n="$n" -v wall="$total_wall" '
    /ERROR/ { errores++; next }
    { suma+=$1; count++; if ($1>max) max=$1 }
    END {
      if (count==0) { printf "peticiones=%d errores=%d (todas fallaron)\n", n, errores; exit }
      printf "peticiones=%d errores=%d tiempo_total=%.3fs latencia_prom=%.1fms latencia_max=%.1fms throughput_rps=%.0f\n", \
        n, errores+0, wall, (suma/count)*1000, max*1000, n/wall
    }'
  rm -rf "$tmpdir"
}

# --- Sondeo de recursos en segundo plano (para medir CPU/memoria DURANTE la carga) ---
sample_stats() {
  local outfile="$1"
  while true; do
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null \
      | grep -E "^bench-(go|node|python|java)," >> "$outfile"
    sleep 0.3
  done
}

echo
echo "=== 5. Verificando que cada servidor responde antes de la carga ==="
declare -A PUERTOS=( [bench-go]="$GO_PORT" [bench-node]="$NODE_PORT" [bench-python]="$PYTHON_PORT" [bench-java]="$JAVA_PORT" )
for servicio in bench-go bench-node bench-python bench-java; do
  p="${PUERTOS[$servicio]}"
  code=$(curl -s -o /dev/null -m 3 -w "%{http_code}" "http://localhost:${p}/healthz")
  if [ "$code" = "200" ]; then
    echo "  $servicio (puerto $p): OK"
  else
    echo "  $servicio (puerto $p): NO RESPONDE (http_code=$code). Revisá: docker compose logs $servicio"
  fi
done

echo "=== 6. Prueba de carga ($N peticiones concurrentes) contra cada uno ==="

declare -A SUM_ERRORES SUM_TIEMPO SUM_LATPROM SUM_LATMAX SUM_RPS CONTADOR

for servicio in bench-go bench-node bench-python bench-java; do
  SUM_ERRORES[$servicio]=0
  SUM_TIEMPO[$servicio]=0
  SUM_LATPROM[$servicio]=0
  SUM_LATMAX[$servicio]=0
  SUM_RPS[$servicio]=0
  CONTADOR[$servicio]=0
done

# Arrancar el sondeo de recursos justo antes de empezar las rondas de carga
STATS_FILE=$(mktemp)
sample_stats "$STATS_FILE" &
SAMPLER_PID=$!

for i in 1 2 3 4 5; do
  echo "=== Ronda de prueba $i/5 ==="
  servicios_random=($(printf "%s\n" bench-go bench-node bench-python bench-java | shuf))
  for servicio in "${servicios_random[@]}"; do
    p="${PUERTOS[$servicio]}"
    echo "--- $servicio (puerto $p) ---"

    resultado=$(load_test "http://localhost:${p}/cercanos?lat=-12.09&lon=-77.045" "$N")
    echo "$resultado"

    errores=$(echo "$resultado"      | grep -oE 'errores=[0-9]+'            | cut -d= -f2)
    tiempo=$(echo "$resultado"       | grep -oE 'tiempo_total=[0-9.]+'      | cut -d= -f2)
    lat_prom=$(echo "$resultado"     | grep -oE 'latencia_prom=[0-9.]+'     | cut -d= -f2)
    lat_max=$(echo "$resultado"      | grep -oE 'latencia_max=[0-9.]+'      | cut -d= -f2)
    rps=$(echo "$resultado"          | grep -oE 'throughput_rps=[0-9.]+'    | cut -d= -f2)

    SUM_ERRORES[$servicio]=$(echo "${SUM_ERRORES[$servicio]} + $errores"   | bc)
    SUM_TIEMPO[$servicio]=$(echo "${SUM_TIEMPO[$servicio]} + $tiempo"      | bc)
    SUM_LATPROM[$servicio]=$(echo "${SUM_LATPROM[$servicio]} + $lat_prom"  | bc)
    SUM_LATMAX[$servicio]=$(echo "${SUM_LATMAX[$servicio]} + $lat_max"     | bc)
    SUM_RPS[$servicio]=$(echo "${SUM_RPS[$servicio]} + $rps"               | bc)
    CONTADOR[$servicio]=$((CONTADOR[$servicio] + 1))
  done
done

# Detener el sondeo de recursos apenas terminan las 5 rondas
kill "$SAMPLER_PID" 2>/dev/null
wait "$SAMPLER_PID" 2>/dev/null

echo ""
echo "=== Promedios tras 5 rondas ==="
printf "%-14s %-12s %-16s %-16s %-16s %-16s\n" "Servicio" "Errores" "Tiempo(s)" "Lat.Prom(ms)" "Lat.Max(ms)" "Throughput(rps)"

for servicio in bench-go bench-node bench-python bench-java; do
  n="${CONTADOR[$servicio]}"
  prom_err=$(echo "scale=2; ${SUM_ERRORES[$servicio]} / $n"  | bc)
  prom_tiempo=$(echo "scale=4; ${SUM_TIEMPO[$servicio]} / $n" | bc)
  prom_latprom=$(echo "scale=2; ${SUM_LATPROM[$servicio]} / $n" | bc)
  prom_latmax=$(echo "scale=2; ${SUM_LATMAX[$servicio]} / $n" | bc)
  prom_rps=$(echo "scale=2; ${SUM_RPS[$servicio]} / $n" | bc)

  printf "%-14s %-12s %-16s %-16s %-16s %-16s\n" "$servicio" "$prom_err" "$prom_tiempo" "$prom_latprom" "$prom_latmax" "$prom_rps"
done

echo
echo "=== 6b. CPU / Memoria muestreada DURANTE la carga (5 rondas) ==="
if [ -s "$STATS_FILE" ]; then
  printf "%-14s %-14s %-14s %-14s %-10s\n" "Servicio" "CPU_prom(%)" "Mem_prom(MiB)" "Mem_max(MiB)" "Muestras"
  awk -F',' '
    {
      name=$1
      cpu=$2; gsub("%","",cpu); cpu=cpu+0
      mem=$3
      split(mem, parts, " / ")
      used=parts[1]
      match(used, /^[0-9.]+/)
      num=substr(used, RSTART, RLENGTH)+0
      unit=substr(used, RSTART+RLENGTH)
      if (unit=="GiB") num=num*1024
      else if (unit=="KiB") num=num/1024
      sum_cpu[name]+=cpu
      sum_mem[name]+=num
      cnt[name]++
      if (num > max_mem[name]) max_mem[name]=num
    }
    END {
      for (n in cnt) {
        printf "%-14s %-14.2f %-14.2f %-14.2f %-10d\n", n, sum_cpu[n]/cnt[n], sum_mem[n]/cnt[n], max_mem[n], cnt[n]
      }
    }
  ' "$STATS_FILE" | sort
else
  echo "  (no se capturaron muestras; revisá si docker stats está disponible)"
fi
rm -f "$STATS_FILE"

echo
echo "=== 7. Memoria tras la carga (reposo, para comparar contra el punto 4) ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "bench-(go|node|python|java)|NAME"

echo
echo "Para limpiar: docker compose down --rmi local"
