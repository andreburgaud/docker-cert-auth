package main

import (
	"flag"
	"fmt"
	//"html/template"
	"log"
	"net/http"
	"strings"
	"text/template"
)

const htmlTpl = `
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>Headers</title>
	</head>
	<body>
		<ul>
		{{range $key, $value := .Headers}}<li><strong>{{ $key }}</strong>: {{ $value }}</li>{{end}}
		</ul>
	</body>
</html>`

const textTpl = `
Request Headers:
{{range $key, $value := .Headers}}{{ $key }}: {{ $value }}
{{end}}
`

func index(w http.ResponseWriter, r *http.Request) {
	log.Println("Index Handler")
	dn := r.Header.Get("X-SSL-Client-S-DN")
	if dn == "" {
		log.Println("No Client DN in headers")
		fmt.Fprintln(w, "No X-SSL-Client-S-DN header")
		return
	}

	log.Printf("Client DN: %s", dn)
	fmt.Fprintln(w, dn)
}

func headers(w http.ResponseWriter, r *http.Request) {
	h := r.Header
	rawHeaders := fmt.Sprintf("%v\n", h)
	log.Printf(rawHeaders)
	for name, headers := range r.Header {
		name = strings.ToLower(name)
		for _, h := range headers {
			log.Println(fmt.Sprintf("%v: %v", name, h))
		}
	}
	data := struct {
		Title   string
		Headers http.Header
	}{
		Title:   "Headers",
		Headers: h,
	}
	t, _ := template.New("response").Parse(textTpl)
	t.Execute(w, data)
}

func main() {
	portPtr := flag.String("port", "8080", "Port server is listening on.")
	flag.Parse()
	fmt.Printf("Server listening on port %s\n", *portPtr)
	mux := http.NewServeMux()
	mux.Handle("/", http.HandlerFunc(index))
	mux.Handle("/headers", http.HandlerFunc(headers))
	http.ListenAndServe(fmt.Sprintf(":%s", *portPtr), mux)
}
