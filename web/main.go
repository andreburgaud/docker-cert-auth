package main

import (
	"fmt"
	"log"
	"net/http"
)

const (
	client_dn = "X-Ssl-Client-S-Dn"
)

func index(w http.ResponseWriter, r *http.Request) {
	log.Println("Index Handler")
	dn, ok := r.Header[client_dn]
	if ok {
		log.Printf("Client DN: %s", dn)
	} else {
		log.Println("No Client DN in headers")
	}
	fmt.Fprintf(w, "Hello from Go")
}

func headers(w http.ResponseWriter, r *http.Request) {
	h := r.Header
	log.Printf("Headers: %v\n", h)
	fmt.Fprintln(w, "Check headers")
}

func main() {
	mux := http.NewServeMux()

	mux.Handle("/", http.HandlerFunc(index))
	mux.Handle("/headers", http.HandlerFunc(headers))

	http.ListenAndServe(":8080", mux)
}
