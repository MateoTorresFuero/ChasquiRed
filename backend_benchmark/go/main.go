package main

import (
	"encoding/json"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
)

type Comercio struct {
	ID     int     `json:"id"`
	Nombre string  `json:"nombre"`
	Lat    float64 `json:"lat"`
	Lon    float64 `json:"lon"`
}

var comercios = []Comercio{
	{1, "Bodega Don Julio", -12.0870, -77.0450},
	{2, "Puesto Elsa", -12.0905, -77.0480},
	{3, "Panadería San Ramón", -12.0820, -77.0410},
	{4, "El Sazón Criollo", -12.0950, -77.0500},
	{5, "Bodega La Esquina", -12.0800, -77.0530},
}

func haversineKm(lat1, lon1, lat2, lon2 float64) float64 {
	toRad := func(d float64) float64 { return d * math.Pi / 180 }
	dLat := toRad(lat2 - lat1)
	dLon := toRad(lon2 - lon1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(toRad(lat1))*math.Cos(toRad(lat2))*math.Sin(dLon/2)*math.Sin(dLon/2)
	return 6371.0 * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})
	mux.HandleFunc("/cercanos", func(w http.ResponseWriter, r *http.Request) {
		lat, _ := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
		lon, _ := strconv.ParseFloat(r.URL.Query().Get("lon"), 64)
		type resItem struct {
			Comercio
			DistanciaKm float64 `json:"distancia_km"`
		}
		out := make([]resItem, 0, len(comercios))
		for _, c := range comercios {
			out = append(out, resItem{c, haversineKm(lat, lon, c.Lat, c.Lon)})
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(out)
	})
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}
	log.Println("go server escuchando en :" + port)
	http.ListenAndServe(":"+port, mux)
}
