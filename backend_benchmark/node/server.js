const http = require('http');
const url = require('url');

const comercios = [
  { id: 1, nombre: 'Bodega Don Julio', lat: -12.0870, lon: -77.0450 },
  { id: 2, nombre: 'Puesto Elsa', lat: -12.0905, lon: -77.0480 },
  { id: 3, nombre: 'Panadería San Ramón', lat: -12.0820, lon: -77.0410 },
  { id: 4, nombre: 'El Sazón Criollo', lat: -12.0950, lon: -77.0500 },
  { id: 5, nombre: 'Bodega La Esquina', lat: -12.0800, lon: -77.0530 },
];

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371.0 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const server = http.createServer((req, res) => {
  const parsed = url.parse(req.url, true);
  if (parsed.pathname === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }
  if (parsed.pathname === '/cercanos') {
    const lat = parseFloat(parsed.query.lat);
    const lon = parseFloat(parsed.query.lon);
    const out = comercios.map((c) => ({
      ...c,
      distancia_km: haversineKm(lat, lon, c.lat, c.lon),
    }));
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(out));
    return;
  }
  res.writeHead(404);
  res.end();
});

const PORT = process.env.PORT || 8082;
server.listen(PORT, () => console.log(`node server escuchando en :${PORT}`));
