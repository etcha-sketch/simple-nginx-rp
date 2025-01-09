# simple-nginx-rp
A simple nginx reverse proxy intended for protecting docker containers.

https://hub.docker.com/r/etch4sketch/simple-nginx-reverse-proxy

Docker-cli example
```shell
docker run -d \
    -e PROXY_DEST_SCHEME=http \
    -e SERVER_NAME_OR_IP=127.0.0.1 \
    -e SERVER_PORT=80 \
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
      REQUEST_SCHEME: "http" # http/https
      SERVER_NAME_OR_IP: "demo-webserver"
      SERVER_PORT: "80"
      SERVER_HEADER_NAME: "MyDemoRP"
      REDIRECT_PROXY_ACCESS_TO_STDOUT: "TRUE" # TRUE/FALSE
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
```
