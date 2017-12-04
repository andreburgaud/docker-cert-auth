# Certificate Based Authentication

This project demonstrates the basics of certificate-based authentication. The server (NGINX) validates the certificate presented by the client and reject the request if there is no certificate or the certificate is not valid. If the certificate is valid, NGIX proxy the request to an internal HTTP server (written in Go), and add an entry to the header for the internal server to have access.

[![Docker Pulls](https://img.shields.io/docker/pulls/andreburgaud/nginx-cert-auth.svg)](https://hub.docker.com/r/andreburgaud/nginx-cert-auth/)
[![Docker Automated Build](https://img.shields.io/docker/automated/andreburgaud/nginx-cert-auth.svg)](https://hub.docker.com/r/andreburgaud/nginx-cert-auth/)
[![Docker Build Status](https://img.shields.io/docker/build/andreburgaud/nginx-cert-auth.svg)](https://hub.docker.com/r/andreburgaud/nginx-cert-auth/)

It relies on the following technologies:

* Docker container
* Multi-stage build Docker image
* Usage of a process supervisor to start more than one processes in the container (s6)
* Nginx server handling SSL handshake and validating SSL certificates from the client request
* Internal Go server handling business logic
* Golang cross compilation

# Getting Started

This project was built on Mac OSX, and may require some adjustment if the Makefile is executed on a different system.

## Requirements

The following software need to be installed on the system to build and test the project:

* Docker
* Go (golang)
* OpenSSL
* curl
* make

## Create certs, Go server and Docker image

```
$ make all
```

## Start the Docker container

```
$ make serve
```

## Test

From a terminal, execute:

```
$ curl -v -s -k --key certs/client.key --cert certs/client.crt https://localhost:8443
$ curl -v -s -k --key certs/client.key --cert certs/client.crt https://localhost:8443/headers
```

To test the validation of the server certificate:

* Add example.com to your hosts file
* Then, execute:

```
$ curl -v -s --cacert certs/ca.crt --key certs/client.key --cert certs/client.crt https://localhost:8443
```

# Keys and Certs

The OpenSSL commands are described in the following section. To simplify testing this container, there is a target in the Makefile that will issue all the necessary OpenSSL commands. Prior to execute `make certs`, ensure that you have exported the environment variable you want to use for the passphrase:

```
$ export PASSPHRASE=<some_passphrase>
$ make certs
```

## Create CA Key and Certificate for signing Client Certs

**CA**: Certificate Authority

```
$ openssl genrsa -aes256 -out ca.key 4096                   # CA key
$ openssl req -new -x509 -days 365 -key ca.key -out ca.crt  # CA Certificate
```

## Create the Server Key and CSR

**CSR** : Certificate Signing Request

```
$ openssl genrsa -aes256 -out server.key 2048       # Server key
$ openssl req -new -key server.key -out server.csr  # Server CSR
```

## Create and Sign Server Certificate

* Use a real CA certificate for production

```
$ openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
```

## Create Client Key and CSR

```
$ openssl genrsa -aes256 -out client.key 2048       # Client key
$ openssl req -new -key client.key -out client.csr  # Client CSR
```

## Create and Sign Client Certificate

* Using the same CA cert as for the server, in the context of this setup. In a production environment, the client certificate could be self-signed, but the server certificate would be signed by a trusted CA (e.g. Digicert, GoDaddy, Network Solutions, Let's Encrypt...).

```
$ openssl x509 -req -days 365 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt
```

## Remove passphrases

This is needed so that passphrases are not requested during the start or restart of a service.

```
$ openssl rsa -in server.key -out server.key
$ openssl rsa -in client.key -out client.key
```

# Docker Commands

See Docker commands in the Makefile.

```
$ docker build -t nginx-auth .                                              # Build image
$ docker run --rm -p 8443:443 -v:`pwd`/certs/:/etc/nginx/certs/ nginx-auth  # Start container with certs in a volume
$ docker run --rm -p 8443:443 nginx-auth                                    # Start container with certs in the container
$ docker ps                                                                 # List running active container
$ docker ps -a                                                              # List all active container
$ docker rm $(docker ps -a -f status=exited -f status=created -q)           # Delete all containers
```

To stop the container, you can either press `[CTRL+C]` in the terminal where the container was started (assuming the container was not started with the *daemon* option `-d`), or execute `docker stop <container_name>` after finding the container name via `docker ps`.

## Cross compile the internal web app

```
$ GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o server main.go
$ upx server
$ upx --brute server # For max compression
```

## SSL

### TLS 1.3

Since NGINX 1.13, TLSv1.3 is supported. As of 12/3/2017, the NGINX package in Alpine Linux is version 1.12.2-r3.

Use the following in default.conf, when NGINX 1.13 is available in Alpine:

```
ssl_protocols TLSv1.2 TLSv1.3;
```

### Pass Certificate Info to internal server

The Client DN:

```
proxy_set_header X-SSL-CLIENT-S-DN $ssl_client_s_dn;
```

# Tests

With `-k` proceed even if server connection considered insecure (i.e. even if the server certificate validation fails)

```
$ curl -v -s -k --key certs/client.key --cert certs/client.crt https://localhost:8443
```

or

Replace `-k` with `--cacert certs/ca.crt`. The server certificate was signed with this ca.crt. This requires that the hostname matches the name of the host in the certificate. Adding the host name to the `/etc/hosts` file allows to successfully test this scenario on a development system.

```
$ curl -v -s --cacert certs/ca.crt --key certs/client.key --cert certs/client.crt https://localhost:8443
```

# Multiple Processes in the Container

Container best practices encourage to manage a single process per container. Although it is a goal, it comes with the necessity to orchestrate multiple containers via other services like **Kubernetes**, **Docker Swarm** or others. There are situations where running more than one process removes unnecessary complexity - like this particular project for example - and still allow to prepare the ground for a more elaborated stage that includes orchestration for container.

# Resources

* http://nginx.org/en/docs/http/ngx_http_ssl_module.html#var_ssl_client_cert
* http://nategood.com/client-side-certificate-authentication-in-ngi
* http://www.insivia.com/removing-a-pass-phrase-from-a-ssl-certificate/
* https://serverfault.com/questions/622855/nginx-proxy-to-back-end-with-ssl-client-certificate-authentication
* https://skarnet.org/software/s6/ s6 Process Supervision
* https://upx.github.io/ UPX the Ultimate Packer for eXecutables
