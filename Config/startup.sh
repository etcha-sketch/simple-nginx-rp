#! /bin/sh

# Determine if container first run or not
CONTAINER_RUN_ONCE="CONTAINER_RUN_ONCE_PLACEHOLDER"
if [ ! -e "$CONTAINER_RUN_ONCE" ]; then
    touch "$CONTAINER_RUN_ONCE"
    echo "-- Container first startup --"
    touch /var/log/nginx/access.log /var/log/nginx/simplenginxrp.access.log
else
    echo "-- Container restarted --"
fi

# Determine if certificate is already defined
CERT_PATH="/etc/nginx/ssl/cert.pem"
if [ ! -f "$CERT_PATH" ]; then
    # Certificate and key do not exist, generate 20yr self-signed cert
    echo "$CERT_PATH does not exist, creating 20yr self-signed cert and key"
    openssl req -x509 -nodes -days 7300 -newkey rsa:2048 \
        -subj "/C=$CERT_COUNTRY/ST=$CERT_ST/L=$CERT_LOCALITY/O=$CERT_ORGANIZATION/CN=$CERT_CN" \
        -keyout /etc/nginx/ssl/key.key -out "$CERT_PATH" >/dev/null 2>&1
    chmod 600 /etc/nginx/ssl/*
    echo "Self-signed cert and key generated with the following settings:"
    echo "  C:   $CERT_COUNTRY"
    echo "  ST:  $CERT_ST"
    echo "  L:   $CERT_LOCALITY"
    echo "  O:   $CERT_ORGANIZATION"
    echo "  CN:  $CERT_CN"
else
    # Certificate exists.
    echo "Certificate already exists, skipping creation of self-signed cert and key pair"
fi

# Copy nginx.conf template if the file has been deleted or using a bind
if ! test -f /etc/nginx/nginx-conf/nginx.conf ; then
    # /etc/nginx/nginx-conf/nginx.conf does not exist
    echo "/etc/nginx/nginx-conf/nginx.conf does not exist, creating new copy"
    cp /template/nginx.conf /etc/nginx/nginx-conf/nginx.conf
else
    # /etc/nginx/nginx-conf/nginx.conf exists
    echo "/etc/nginx/nginx-conf/nginx.conf already exists"
fi

# Determine if server header has been set
if grep -q "<<Server_Header_Name>>" /etc/nginx/nginx-conf/nginx.conf ; then
    # Template still has default value
    if [ "$SERVER_HEADER_NAME" = "DEFAULT" ] ; then
        # Environment variable not defined, generating random 16 char string as server header
        echo "Server header not set as an environment variable, generating random string"
        export SERVER_HEADER_NAME="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16; echo)"
        echo "Updating nginx config. Server Header: $SERVER_HEADER_NAME"
        sed -i "s|<<Server_Header_Name>>|$SERVER_HEADER_NAME|g" /etc/nginx/nginx-conf/nginx.conf
    else
        # Environment variable defined
        echo "Updating nginx config. Server Header: $SERVER_HEADER_NAME"
        sed -i "s|<<Server_Header_Name>>|$SERVER_HEADER_NAME|g" /etc/nginx/nginx-conf/nginx.conf
    fi
else
    # Nginx.conf already has the server header set.
    echo "Server Header already set: $(cat /etc/nginx/nginx-conf/nginx.conf | grep more_set_headers | awk '{print $3}' | tr -d "';")"
fi

# Copy nginx-rp template if the file has been deleted or using a bind
if ! test -f /etc/nginx/sites-enabled/nginx-rp ; then
    # /etc/nginx/sites-enabled/nginx-rp does not exist
    echo "/etc/nginx/sites-enabled/nginx-rp does not exist, creating new copy"
    cp /template/nginx-rp /etc/nginx/sites-enabled/nginx-rp
else
    # /etc/nginx/sites-enabled/nginx-rp exists
    echo "/etc/nginx/sites-enabled/nginx-rp already exists"
fi

# Determine if the default reverse proxy configuration update has been completed
if grep -q "<<request_scheme>>" /etc/nginx/sites-enabled/nginx-rp ; then
    # Initial config not completed, replace with user-defined settings
    echo "Updating nginx reverse proxy. Destination: $PROXY_DEST_SCHEME://$PROXY_DEST_SERVER_NAME_OR_IP:$PROXY_DEST_SERVER_PORT"
    sed -i "s|<<request_scheme>>|$PROXY_DEST_SCHEME|g" /etc/nginx/sites-enabled/nginx-rp
    sed -i "s|<<server_name_or_ip>>|$PROXY_DEST_SERVER_NAME_OR_IP|g" /etc/nginx/sites-enabled/nginx-rp
    sed -i "s|<<server_port>>|$PROXY_DEST_SERVER_PORT|g" /etc/nginx/sites-enabled/nginx-rp
else
    # Initial config already complete
    echo "Proxy destination already set: $(cat /etc/nginx/sites-enabled/nginx-rp | grep proxy_pass | awk '{print $2}' | tr -d ';')"
fi

# Check on every startup if REDIRECT_PROXY_ACCESS_TO_STDOUT is defined.
# If set to true, link the log file to standard out/docker logs.
if [ -n $REDIRECT_PROXY_ACCESS_TO_STDOUT ] ; then
  if [ "$REDIRECT_PROXY_ACCESS_TO_STDOUT" = "TRUE" ] ; then
    # REDIRECT_PROXY_ACCESS_TO_STDOUT set to "TRUE"
    echo "REDIRECT_PROXY_ACCESS_TO_STDOUT set to TRUE, redirecting proxy access log to standard output"
    sed -i "s|access_log            /dev/null|access_log            /var/log/nginx/simplenginxrp.access.log|g" /etc/nginx/sites-enabled/nginx-rp
    sed -i "s|access_log /dev/null|access_log /var/log/nginx/access.log|g" /etc/nginx/nginx-conf/nginx.conf
    ln -sf /dev/stdout /var/log/nginx/access.log
    ln -sf /dev/stdout /var/log/nginx/simplenginxrp.access.log
  elif [ "$REDIRECT_PROXY_ACCESS_TO_STDOUT" = "NONE" ] ; then
  # REDIRECT_PROXY_ACCESS_TO_STDOUT set to "NONE"
    echo "REDIRECT_PROXY_ACCESS_TO_STDOUT set to NONE, supressing all logs"
    sed -i "s|access_log            /var/log/nginx/simplenginxrp.access.log|access_log            /dev/null|g" /etc/nginx/sites-enabled/nginx-rp
    sed -i "s|access_log /var/log/nginx/access.log|access_log /dev/null|g" /etc/nginx/nginx-conf/nginx.conf
    # Need to ensure any previous links are removed
    unlink /var/log/nginx/access.log
    echo 'LOGGING DISABLED!! $REDIRECT_PROXY_ACCESS_TO_STDOUT=NONE' > /var/log/nginx/access.log
    unlink /var/log/nginx/simplenginxrp.access.log
    echo 'LOGGING DISABLED!! $REDIRECT_PROXY_ACCESS_TO_STDOUT=NONE' > /var/log/nginx/simplenginxrp.access.log
  else
    # REDIRECT_PROXY_ACCESS_TO_STDOUT set to anything else
    echo "REDIRECT_PROXY_ACCESS_TO_STDOUT set to $REDIRECT_PROXY_ACCESS_TO_STDOUT, not redirecting output"
    sed -i "s|access_log            /dev/null|access_log            /var/log/nginx/simplenginxrp.access.log|g" /etc/nginx/sites-enabled/nginx-rp
    sed -i "s|access_log /dev/null|access_log /var/log/nginx/access.log|g" /etc/nginx/nginx-conf/nginx.conf
    unlink /var/log/nginx/access.log
    touch /var/log/nginx/access.log
    unlink /var/log/nginx/simplenginxrp.access.log
    touch /var/log/nginx/simplenginxrp.access.log
  fi
else
  # REDIRECT_PROXY_ACCESS_TO_STDOUT not defined (should never happen)
  echo "REDIRECT_PROXY_ACCESS_TO_STDOUT not defined"
fi

# Always relink the nginx.conf from the nginx-conf folder.
# Allows for the nginx.conf be be located in a persistent volume/bind.
echo "(Re)linking /etc/nginx-conf/nginx.conf -> /etc/nginx/nginx.conf"
ln -sf /etc/nginx/nginx-conf/nginx.conf /etc/nginx/nginx.conf

# Always redirect nginx-rp error log to stderr
ln -sf /dev/stderr /var/log/nginx/simplenginxrp.error.log

# Start nginx
nginx -g "daemon off;"
