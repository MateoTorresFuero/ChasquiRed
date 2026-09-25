//go:build ignore

package main

import (
	"fmt"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

func main() {
	puerto := os.Args[1]
	n, _ := strconv.Atoi(os.Args[2])

	var wg sync.WaitGroup
	latencias := make([]time.Duration, n)
	errores := 0
	var mu sync.Mutex

	inicio := time.Now()
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			t0 := time.Now()
			resp, err := http.Get(fmt.Sprintf("http://localhost:%s/cercanos?lat=-12.09&lon=-77.045", puerto))
			if err != nil {
				mu.Lock()
				errores++
				mu.Unlock()
				return
			}
			resp.Body.Close()
			latencias[i] = time.Since(t0)
		}(i)
	}
	wg.Wait()
	total := time.Since(inicio)

	var suma time.Duration
	max := time.Duration(0)
	for _, l := range latencias {
		suma += l
		if l > max {
			max = l
		}
	}
	fmt.Printf("peticiones=%d errores=%d tiempo_total=%v latencia_prom=%v latencia_max=%v throughput_rps=%.0f\n",
		n, errores, total, suma/time.Duration(n), max, float64(n)/total.Seconds())
}
