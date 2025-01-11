# simple-nginx-reverse-proxy
A simple nginx reverse proxy for protecting other Docker containers.

## Background

This project was created to secure traffic between a primary reverse proxy and Docker containers using a self-signed certificate. It is not intended to be a primary reverse proxy but rather to provide encryption for small projects without the need to share or generate multiple self-signed certificates.

## Benefits

- Auto-generates a 20-year self-signed certificate and private key
- Persistent logging for troubleshooting
- Option to redirect nginx logs to Docker logs
  - Note: This logs the entire request string, which may expose sensitive information
  - Set `REDIRECT_PROXY_ACCESS_TO_STDOUT` to `NONE` to suppress all logging within the container
- Configuration via environment variables
  - Certificate fields: `CERT_*`
  - Nginx configuration: `PROXY_DEST_*`
  - Server header: `SERVER_HEADER_NAME`
  - Redirect logs: `REDIRECT_PROXY_ACCESS_TO_STDOUT`
- Easy integration with other Docker Compose projects
- Volumes will be automatically created and required files populated in volumes



https://hub.docker.com/r/etch4sketch/simple-nginx-reverse-proxy

Docker-cli example
```shell
docker run -d \
    -e PROXY_DEST_SCHEME=http \
    -e PROXY_DEST_SERVER_NAME_OR_IP=127.0.0.1 \
    -e PROXY_DEST_SERVER_PORT=80 \
    -e SERVER_HEADER_NAME=MyReverseProxy \
    -e CERT_COUNTRY=US \
    -e CERT_ST=State \
    -e CERT_LOCALITY=MyCity \
    -e CERT_ORGANIZATION=MyOrg \
    -e CERT_CN=myserver.local \
    -e REDIRECT_PROXY_ACCESS_TO_STDOUT=FALSE \
    --volume nginx-certs:/etc/nginx/ssl/ \
    --volume nginx-server-conf:/etc/nginx/nginx-conf/ \
    --volume nginx-logs:/var/log/nginx/ \
    --volume nginx-sites-conf:/etc/nginx/sites-enabled/ \
    -p 7000:443 \
    --name example-simple-nginx-rp \
    etch4sketch/simple-nginx-reverse-proxy:latest
```


Docker-compose example
```shell
# Sample docker-compose to protect a generic webserver running on port 80 with a HTTPS reverse proxy

name: simple-nginx-reverse-proxy-demo

services:
  demo-webserver:
    container_name: demo-webserver
    image: nginx
    networks:
      - nginx-rp-demo
    restart: no

  nginx-rp:
    image: etch4sketch/simple-nginx-reverse-proxy:latest
    container_name: nginx-rp
    restart: no
    volumes:
      - demo-nginx-rp-certs:/etc/nginx/ssl/
      - demo-nginx-rp-server-conf:/etc/nginx/nginx-conf/
      - demo-nginx-rp-logs:/var/log/nginx/
      - demo-nginx-rp-sites-conf:/etc/nginx/sites-enabled/
    environment:
      PROXY_DEST_SCHEME: "http" # http/https
      PROXY_DEST_SERVER_NAME_OR_IP: "demo-webserver"
      PROXY_DEST_SERVER_PORT: "80"
      SERVER_HEADER_NAME: "MyDemoRP"
      REDIRECT_PROXY_ACCESS_TO_STDOUT: "TRUE" # TRUE/FALSE/NONE
      CERT_COUNTRY: CO
      CERT_ST: ST
      CERT_LOCALITY: My City
      CERT_ORGANIZATION: demo
      CERT_CN: demo-webserver.local
    ports:
      - "2222:443"
    networks:
      - nginx-rp-demo

volumes:
  demo-nginx-rp-sites-conf:
  demo-nginx-rp-logs:
  demo-nginx-rp-server-conf:
  demo-nginx-rp-certs:

networks:
  nginx-rp-demo:
    name: nginx-rp-demo
