# ==============================================================================
# First stage build (compile the Go server)
# ==============================================================================
FROM alpine:3.7 as builder

RUN apk add --no-cache go musl-dev

WORKDIR /

COPY web/main.go .

RUN GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o server .

# ==============================================================================
# Second stage build
# ==============================================================================
FROM alpine:3.7

RUN apk add --no-cache nginx s6

# Copy s6 configuration
ADD s6 /s6

RUN chmod +x -R /s6 && \
    mkdir -p /run/nginx && \
    mkdir /web && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Copy the internal server from the first stage build
COPY --from=builder /server /web/

# Copy server config
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/

STOPSIGNAL SIGTERM

EXPOSE 443

CMD ["s6-svscan", "/s6"]
