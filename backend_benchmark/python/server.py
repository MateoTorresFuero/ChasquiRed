import json
import math
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

comercios = [
    {"id": 1, "nombre": "Bodega Don Julio", "lat": -12.0870, "lon": -77.0450},
    {"id": 2, "nombre": "Puesto Elsa", "lat": -12.0905, "lon": -77.0480},
    {"id": 3, "nombre": "Panadería San Ramón", "lat": -12.0820, "lon": -77.0410},
    {"id": 4, "nombre": "El Sazón Criollo", "lat": -12.0950, "lon": -77.0500},
    {"id": 5, "nombre": "Bodega La Esquina", "lat": -12.0800, "lon": -77.0530},
]


def haversine_km(lat1, lon1, lat2, lon2):
    to_rad = math.radians
    d_lat = to_rad(lat2 - lat1)
    d_lon = to_rad(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(to_rad(lat1)) * math.cos(to_rad(lat2)) * math.sin(d_lon / 2) ** 2
    )
    return 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass 

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/healthz":
            self._send_json({"status": "ok"})
            return
        if parsed.path == "/cercanos":
            qs = parse_qs(parsed.query)
            lat = float(qs.get("lat", [0])[0])
            lon = float(qs.get("lon", [0])[0])
            out = [
                {**c, "distancia_km": haversine_km(lat, lon, c["lat"], c["lon"])}
                for c in comercios
            ]
            self._send_json(out)
            return
        self.send_response(404)
        self.end_headers()

    def _send_json(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8083"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"python server escuchando en :{port}")
    server.serve_forever()
