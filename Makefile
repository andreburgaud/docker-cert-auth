IMAGE:=nginx-cert-auth
SUBCA:="/C=FR/ST=Paris/L=Paris/O=CA Example/OU=CA/CN=ca.com"
SUBSRV:="/C=FR/ST=Paris/L=Paris/O=ServerExample/OU=SRV/CN=example.com"
SUBCL:="/C=FR/ST=Paris/L=Paris/O=ClientExample/OU=CLIENT/CN=client.example.com"

default: help

help:
	@echo 'Usage:'
	@echo '    make clean           Delete executables and certs'
	@echo '    make certs           Generate certs (using OpenSSL)'
	@echo '    make build           Compile local version of the server (testing outsite container)'
	@echo '    make xbuild          Cross-compile server for Linux (targetging container)'
	@echo '    make image           Build Docker image using the local Dockerfile'
	@echo '    make serve           Start the Docker container'
	@echo

all: certs image

build:
	@echo 'Compile server for local test'
	go build -o server web/main.go

# Not needed: the server is compiled in the first stage build (see Dockerfile)
# xbuild:
# 	@echo 'Cross compile server for Linux'
# 	GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o server web/main.go
# 	upx server

image:
	docker build -t ${IMAGE} .

serve:
	docker run --rm -p 8443:443 -v`pwd`/certs/:/etc/nginx/certs/ ${IMAGE}

certs: clean cakey cacert srvkey srvcsr srvcert clkey clcsr clcert rmsrvkpass rmsclkpass
	@echo Certs generation complete

clean:
	@-rm server 2> /dev/null
	@-rm -rf certs 2> /dev/null
	@-mkdir certs

test:
	curl -v -s -k --key certs/client.key --cert certs/client.crt https://localhost:8443

cakey:
	openssl genrsa -aes256 -passout env:PASSPHRASE -out certs/ca.key 4096

cacert:
	openssl req -new -x509 -days 365 -passin env:PASSPHRASE -passout env:PASSPHRASE -subj ${SUBCA} -key certs/ca.key -out certs/ca.crt

srvkey:
	openssl genrsa -aes256 -passout env:PASSPHRASE -out certs/server.key 2048

srvcsr:
	openssl req -new -passin env:PASSPHRASE -subj ${SUBSRV} -key certs/server.key -out certs/server.csr

srvcert:
	openssl x509 -req -days 365 -in certs/server.csr -CA certs/ca.crt -passin env:PASSPHRASE -CAkey certs/ca.key -set_serial 01 -out certs/server.crt

clkey:
	openssl genrsa -aes256 -passout env:PASSPHRASE -out certs/client.key 2048

clcsr:
	openssl req -new -passin env:PASSPHRASE -subj ${SUBCL} -key certs/client.key -out certs/client.csr

clcert:
	openssl x509 -req -days 365 -in certs/client.csr -CA certs/ca.crt -passin env:PASSPHRASE -CAkey certs/ca.key -set_serial 01 -out certs/client.crt

rmsrvkpass:
	openssl rsa -passin env:PASSPHRASE -in certs/server.key -out certs/server.key

rmsclkpass:
	openssl rsa -passin env:PASSPHRASE -in certs/client.key -out certs/client.key
