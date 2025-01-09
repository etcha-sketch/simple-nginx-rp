#! /bin/sh

# Determine if container first run or not
CONTAINER_RUN_ONCE="CONTAINER_RUN_ONCE_PLACEHOLDER"
if [ ! -e $CONTAINER_RUN_ONCE ]; then
    touch $CONTAINER_RUN_ONCE
    echo "-- Container first startup --"
else
    echo "-- Not container first startup --"
fi

# Determine if certificate is already defined
if ! test -f /etc/nginx/ssl/cert.pem ; then
    # Certificate and key do not exist, generate 20yr self-signed cert
    echo "/etc/nginx/ssl/cert.pem does not exist, creating 20yr self-signed cert and key"
    openssl req -x509 -nodes -days 7300 -newkey rsa:2048 \
        -subj "/C=$CERT_COUNTRY/ST=$CERT_ST/L=$CERT_LOCALITY/O=$CERT_ORGANIZATION/CN=$CERT_CN" \
        -keyout /etc/nginx/ssl/key.key -out /etc/nginx/ssl/cert.pem
    chmod 600 /etc/nginx/ssl/*
    echo "Self-signed cert and key generated."
else
    # Certificate exists.
    echo "Certificate already exists, skipping creation of self-signed cert and key pair"
fi

# Download nginx.conf if the file has been deleted or using a bind
if ! test -f /etc/nginx/nginx-conf/nginx.conf ; then
    # /etc/nginx/nginx-conf/nginx.conf does not exist
    echo "/etc/nginx/nginx-conf/nginx.conf does not exist, downloading from GitHub"
    curl -O https://raw.githubusercontent.com/etcha-sketch/simple-nginx-rp/refs/heads/main/Config/nginx.conf
    if test -f nginx.conf ; then
        echo "nginx.conf downloaded successfully"
        mv nginx.conf /etc/nginx/nginx-conf/nginx.conf
    else
        echo "ERROR: Failed to download https://raw.githubusercontent.com/etcha-sketch/simple-nginx-rp/refs/heads/main/Config/nginx.conf"
        echo "Aborting. Manual intervention required"
        exit
    fi

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
        sed -i "s/<<Server_Header_Name>>/$SERVER_HEADER_NAME/g" /etc/nginx/nginx-conf/nginx.conf
    else
        # Environment variable defined
        echo "Updating nginx config. Server Header: $SERVER_HEADER_NAME"
        sed -i "s/<<Server_Header_Name>>/$SERVER_HEADER_NAME/g" /etc/nginx/nginx-conf/nginx.conf
    fi
else
    # Nginx.conf already has the server header set.
    echo "Server Header already set: $(cat /etc/nginx/nginx-conf/nginx.conf | grep more_set_headers | awk '{print $3}' | tr -d ';')"
fi

# Always relink the nginx.conf from the nginx-conf folder.
# Allows for the nginx.conf be be located in a persistent volume/bind.
echo "(Re)linking /etc/nginx-conf/nginx.conf -> /etc/nginx/nginx.conf"
ln -sf /etc/nginx/nginx-conf/nginx.conf /etc/nginx/nginx.conf

# Download nginx-rp if the file has been deleted or using a bind
if ! test -f /etc/nginx/sites-enabled/nginx-rp ; then
    # /etc/nginx/sites-enabled/nginx-rp does not exist
    echo "/etc/nginx/sites-enabled/nginx-rp does not exist, downloading from GitHub"
    curl -O https://raw.githubusercontent.com/etcha-sketch/simple-nginx-rp/refs/heads/main/Config/template-No-Restrictions
    if test -f template-No-Restrictions ; then
        echo "nginx-rp-template downloaded successfully"
        mv template-No-Restrictions /etc/nginx/sites-enabled/nginx-rp
    else
        echo "ERROR: Failed to download https://raw.githubusercontent.com/etcha-sketch/simple-nginx-rp/refs/heads/main/Config/template-No-Restrictions"
        echo "Aborting. Manual intervention required"
        exit
    fi
else
    # /etc/nginx/sites-enabled/nginx-rp exists
    echo "/etc/nginx/sites-enabled/nginx-rp already exists"
fi

# Determine if the default reverse proxy configuration update has been completed
if grep -q "<<request_scheme>>" /etc/nginx/sites-enabled/nginx-rp ; then
    # Initial config not completed, replace with user-defined settings
    echo "Updating nginx reverse proxy. Destination: $PROXY_DEST_SCHEME://$PROXY_DEST_SERVER_NAME_OR_IP:$PROXY_DEST_SERVER_PORT"
    sed -i "s/<<request_scheme>>/$PROXY_DEST_SCHEME/g" /etc/nginx/sites-enabled/nginx-rp
    sed -i "s/<<server_name_or_ip>>/$PROXY_DEST_SERVER_NAME_OR_IP/g" /etc/nginx/sites-enabled/nginx-rp
    sed -i "s/<<server_port>>/$PROXY_DEST_SERVER_PORT/g" /etc/nginx/sites-enabled/nginx-rp
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
    ln -sf /dev/stdout /var/log/nginx/simplenginxrp.access.log
  else
    # REDIRECT_PROXY_ACCESS_TO_STDOUT not set to "TRUE"
    echo "REDIRECT_PROXY_ACCESS_TO_STDOUT not set to TRUE, not redirecting output"
  fi
else
    # REDIRECT_PROXY_ACCESS_TO_STDOUT not defined (should never happen)
  echo "REDIRECT_PROXY_ACCESS_TO_STDOUT not set to TRUE, not redirecting output"
fi

# Start nginx
nginx -g "daemon off;"
