FROM nginx:stable

# Must remove the default nginx to install the maintainers version of nginx
# This is used to be able to set the server header option with nginx-extras
# This also allows for roughly ~50MB smaller container size compared to
# installing nginx on top of a generic debian image.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get remove nginx -y && \
    apt-get install -y nginx-extras

# Add the build date to the container image
RUN date -d 'TZ="America/Chicago"' +'%Y%m%d' > /.container_build_date

# Define the four volumes
# /etc/nginx/sites-enabled  - Stores the enabled site configuration files
# /etc/nginx/ssl            - Stores the certificate and key
# /var/log/nginx            - Log persistence in a volume
# /etc/nginx/nginx-conf     - The nginx configuration for the server itself in a volume
#                               Startup creates a symlink from /etc/nginx/nginx-conf/nginx.conf
#                               -> /etc/nginx/nginx.conf
VOLUME [ \
        "/etc/nginx/sites-enabled", \
        "/etc/nginx/ssl", \
        "/var/log/nginx", \
        "/etc/nginx/nginx-conf" \
        ]

# Add the required files
COPY ./Config/nginx.conf /template/nginx.conf
COPY ./Config/template-No-Restrictions /template/nginx-rp
COPY --chmod=755 ./Config/startup.sh /startup.sh

# Define the protected service env variables
ENV PROXY_DEST_SCHEME=http \
    PROXY_DEST_SERVER_NAME_OR_IP=127.0.0.1 \
    PROXY_DEST_SERVER_PORT=80

# Define the nginx.conf file server_header
# if left at "DEFAULT" a random 16 char string is assigned
ENV SERVER_HEADER_NAME=DEFAULT

# Define certificate request details.
ENV CERT_COUNTRY=AA \
    CERT_ST=Testing \
    CERT_LOCALITY=Testing \
    CERT_ORGANIZATION=Testing \
    CERT_CN=testing.local

# DefineREDIRECT_PROXY_ACCESS_TO_STDOUT
# if set to "TRUE" the
ENV REDIRECT_PROXY_ACCESS_TO_STDOUT=FALSE

# Define healthcheck
HEALTHCHECK --interval=1m30s --retries=3 --timeout=3s CMD curl -s https://localhost/.simple_rp_healthcheck -k || exit 1

# Expose the HTTPS port
EXPOSE 443/tcp

# Define startup script
CMD [ "/startup.sh" ]
