import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.Executors;

public class Server {

    record Comercio(int id, String nombre, double lat, double lon) {}

    static final Comercio[] COMERCIOS = new Comercio[] {
        new Comercio(1, "Bodega Don Julio", -12.0870, -77.0450),
        new Comercio(2, "Puesto Elsa", -12.0905, -77.0480),
        new Comercio(3, "Panadería San Ramón", -12.0820, -77.0410),
        new Comercio(4, "El Sazón Criollo", -12.0950, -77.0500),
        new Comercio(5, "Bodega La Esquina", -12.0800, -77.0530),
    };

    static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return 6371.0 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    static Map<String, String> parseQuery(URI uri) {
        Map<String, String> out = new java.util.HashMap<>();
        String q = uri.getQuery();
        if (q == null) return out;
        for (String pair : q.split("&")) {
            String[] kv = pair.split("=", 2);
            if (kv.length == 2) out.put(kv[0], kv[1]);
        }
        return out;
    }

    static void sendJson(HttpExchange ex, String body) throws java.io.IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json");
        ex.sendResponseHeaders(200, bytes.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(bytes);
        }
    }

    public static void main(String[] args) throws Exception {
        String portEnv = System.getenv("PORT");
        int port = (portEnv != null && !portEnv.isEmpty()) ? Integer.parseInt(portEnv) : 8084;
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 1024);
        System.out.println("java server escuchando en :" + port);

        server.createContext("/healthz", (HttpHandler) ex -> sendJson(ex, "{\"status\":\"ok\"}"));

        server.createContext("/cercanos", (HttpHandler) ex -> {
            Map<String, String> q = parseQuery(ex.getRequestURI());
            double lat = Double.parseDouble(q.getOrDefault("lat", "0"));
            double lon = Double.parseDouble(q.getOrDefault("lon", "0"));
            StringBuilder sb = new StringBuilder("[");
            for (int i = 0; i < COMERCIOS.length; i++) {
                Comercio c = COMERCIOS[i];
                double d = haversineKm(lat, lon, c.lat(), c.lon());
                if (i > 0) sb.append(",");
                sb.append(String.format(
                    "{\"id\":%d,\"nombre\":\"%s\",\"lat\":%f,\"lon\":%f,\"distancia_km\":%f}",
                    c.id(), c.nombre(), c.lat(), c.lon(), d));
            }
            sb.append("]");
            sendJson(ex, sb.toString());
        });

        server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
        server.start();
    }
}
