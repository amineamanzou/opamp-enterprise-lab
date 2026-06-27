package main

import (
	"log"
	"net/http"
	"os"

	"github.com/example/opamp-poc/lab/opamp-server/internal/server"
)

func main() {
	addr := os.Getenv("OPAMP_POC_ADDR")
	if addr == "" {
		addr = ":4320"
	}
	adminAddr := os.Getenv("OPAMP_POC_ADMIN_ADDR")
	if adminAddr == "" {
		adminAddr = os.Getenv("OPAMP_ADMIN_ADDR")
	}

	srv := server.New()
	handler := srv.Router()

	if adminAddr != "" && adminAddr != addr {
		go func() {
			log.Printf("opamp-poc-server admin API listening on %s", adminAddr)
			if err := http.ListenAndServe(adminAddr, handler); err != nil {
				log.Fatalf("admin API listener failed: %v", err)
			}
		}()
	}

	log.Printf("opamp-poc-server OpAMP endpoint listening on %s", addr)
	httpSrv := &http.Server{
		Addr:        addr,
		Handler:     handler,
		ConnContext: srv.ConnContext,
	}
	if err := httpSrv.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
