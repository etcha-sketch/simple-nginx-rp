FROM nginx:stable

# Must remove the default nginx to install the maintainers version of nginx
# this is used to be able to set the server header option with nginx-extras
# this also allows for roughly ~50MB smaller container size compared to
# installing nginx on top of a generic debian image.
RUN apt update && apt upgrade -y &&\
    apt remove nginx -y &&\
    apt install -y nginx nginx-extras

# Define the four volumes
# /etc/nginx/sites-enabled  - Stores the enabled site configuration files
# /etc/nginx/ssl            - Stores the certificate and key
# /var/log/nginx            - Log persistence in a volume
# /etc/nginx/nginx-conf     - The nginx configuration for the server itself in a volume
#                               Startup creates a symlink from /etc/nginx/nginx-conf/nginx.conf
#                               -> /etc/nginx/nginx.conf
VOLUME ["/etc/nginx/sites-enabled", "/etc/nginx/ssl", "/var/log/nginx", "/etc/nginx/nginx-conf"]

# Add the required files
ADD ./Config/nginx.conf /etc/nginx/nginx-conf/nginx.conf
ADD ./Config/template-No-Restrictions /etc/nginx/sites-enabled/nginx-rp
ADD ./Config/startup.sh /startup.sh

# Define the protected service env variables
ENV PROXY_DEST_SCHEME=http \
    SERVER_NAME_OR_IP=127.0.0.1 \
    SERVER_PORT=80

# Define the nginx.conf file server_header
# if left at "DEFAULT" a random 16 char string is assigned
ENV SERVER_HEADER_NAME=DEFAULT

# Define certificate request details.
ENV CERT_COUNTRY=AA
ENV CERT_ST=Testing
ENV CERT_LOCALITY=Testing
ENV CERT_ORGANIZATION=Testing
ENV CERT_CN=testing.local

# DefineREDIRECT_PROXY_ACCESS_TO_STDOUT
# if set to "TRUE" the
ENV REDIRECT_PROXY_ACCESS_TO_STDOUT=FALSE

# Expose the HTTPS port
EXPOSE 443/tcp

# Define startup script
CMD [ "/startup.sh" ]
