package main

import (
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/textproto"
	"net/url"
	"strings"
	"time"
	// нужны для проброса версии боба! 
	"flag"
	"fmt"
	"os"
)

// не забываем про версию боба! 
var Version = "dev"

func main() {

	versionFlag := flag.Bool("version", false, "print version")
	flag.Parse()

	if *versionFlag {
		fmt.Println(Version)
		os.Exit(0)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	upstreamEnv := os.Getenv("UPSTREAM_BASE_URL")
	if upstreamEnv == "" {
		upstreamEnv = "https://api.telegram.org/"
	}

	upstreamBase, err := url.Parse(upstreamEnv)
	if err != nil {
		log.Fatalf("Invalid UPSTREAM_BASE_URL='%s': %v", upstreamEnv, err)
	}

	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   10 * time.Second,
			KeepAlive: 60 * time.Second,
		}).DialContext,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 60 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		ForceAttemptHTTP2:     true,
	}

	client := &http.Client{Transport: transport, Timeout: 120 * time.Second}

	// ✅ /ping → pong
	http.HandleFunc("/ping", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("pong"))
	})

	// ✅ /proxy/* → upstream/*
	http.HandleFunc("/proxy/", func(w http.ResponseWriter, r *http.Request) {
		maskPath := func(p string) string {
			// замаскировать token вида botXXX...
			i := strings.Index(p, "/proxy/bot")
			if i < 0 {
				return p
			}
			rest := p[i+len("/proxy/bot"):]
			j := strings.Index(rest, "/")
			if j < 0 {
				return p[:i] + "/proxy/bot***"
			}
			return p[:i] + "/proxy/bot***" + rest[j:]
		}

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		targetPath := strings.TrimPrefix(r.URL.Path, "/proxy/")
		u := *upstreamBase
		u.Path = "/" + targetPath
		u.RawQuery = r.URL.RawQuery

		var body io.Reader
		if r.Body != nil {
			defer r.Body.Close()
			_, _ = httputil.DumpRequest(r, false) // just to read headers once
			body = r.Body
		}

		req, err := http.NewRequest(r.Method, u.String(), body)
		if err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		// hop-by-hop headers not forwarded
		hop := map[string]bool{
			"connection":          true,
			"proxy-connection":    true,
			"keep-alive":          true,
			"proxy-authenticate":  true,
			"proxy-authorization": true,
			"te":                  true,
			"trailers":            true,
			"transfer-encoding":   true,
			"upgrade":             true,
		}

		for k, vv := range r.Header {
			kn := textproto.CanonicalMIMEHeaderKey(k)
			if hop[strings.ToLower(kn)] {
				continue
			}
			// no forwarding internal Authorization headers
			if strings.EqualFold(kn, "Authorization") || strings.EqualFold(kn, "Cookie") {
				continue
			}
			for _, v := range vv {
				req.Header.Add(kn, v)
			}
		}

		resp, err := client.Do(req)
		if err != nil {
			http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()

		for k, vv := range resp.Header {
			if hop[strings.ToLower(k)] {
				continue
			}
			for _, v := range vv {
				w.Header().Add(k, v)
			}
		}

		w.WriteHeader(resp.StatusCode)
		_, _ = io.Copy(w, resp.Body)

		log.Printf("%s %s -> %d", r.Method, maskPath(r.URL.Path), resp.StatusCode)
	})

	addr := ":" + port
	log.Printf("proxy listening on %s, upstream %s", addr, upstreamEnv)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal(err)
	}
}
