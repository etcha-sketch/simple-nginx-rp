# simple-nginx-reverse-proxy
A simple nginx reverse proxy intended for protecting other docker containers.

## Background

Project was started due to having multiple docker and kubernetes hosts with an external HTTPS reverse proxy. There was a need to protect
traffic between the primary reverse proxy and the container. A self-signed reverse proxy will at least encrypt the traffic between
those two nodes. It was also preferable to not share self-signed certs nor have to generate self-signed certs for all small projects.
This project is not intended to be a primary reverse proxy as there are multiple liberties taken to be as compatible with as many other
projects as possible such as allowing files of up to 10GB to be permitted to be uploaded.

## Benefits

- Auto-generation of 20 years self-signed certificate and private key pair
- Verbose and persistent logging for troubleshooting
- Simple ability to redirect nginx verbose custom logging format to docker logs
    - Beware that this logs the entire request string which could expose api keys or secrets to the protected services, which would have otherwise been transmitted over http either way
    - REDIRECT_PROXY_ACCESS_TO_STDOUT can be set to NONE to supress all logging within the container
- Allows for all configuration to be complete via environment variables
    - Cert fields can be specified in CERT_* environment variables
    - Nginx configuration can be specified in PROXY_DEST_* environment variables
    - Server header can be configured with SERVER_HEADER_NAME
    - Redirecting nginx proxy logs to docker logs can be enabled with REDIRECT_PROXY_ACCESS_TO_STDOUT
      - Setting REDIRECT_PROXY_ACCESS_TO_STDOUT to NONE will suppress all reverse proxy access logs in the containers
- Easy integration with other docker-compose projects
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
```
