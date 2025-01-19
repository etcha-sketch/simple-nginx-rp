#! /bin/sh

# Migration from v20250116 to v20250119
# Add /.simple_rp_healthcheck mapping to the reverse proxy config for docker healthcheck
    echo "Running migrations for v20250119"
    if [ -f /etc/nginx/sites-enabled/nginx-rp ]; then
        if grep -q "location = /.simple_rp_healthcheck {" /etc/nginx/sites-enabled/nginx-rp ; then
            # Healthcheck location already exists
            echo "  Healthcheck location already exists"
        else
            # Healthcheck location does not exist
            echo "  Adding healthcheck location"
            sed -i 's|        location / {|        location = /.simple_rp_healthcheck {\n                add_header Content-Type text/plain;\n                return 200 \"Running\\n\";\n        }\n\n        location / {|g' /etc/nginx/sites-enabled/nginx-rp
        fi
    else
        echo "  /etc/nginx/sites-enabled/nginx-rp does not exist, no migration is needed"
    fi

echo "Migrations complete"
