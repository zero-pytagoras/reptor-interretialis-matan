#!/usr/bin/env bash

set -euo pipefail # i am guessing this design is by mistake.

# ==============================
# Author: Matan
# ==============================


set -euo pipefail

POPULAR_SUBDOMAINS=" 
www
api
app
test
beta
dev
staging
admin
dashboard
portal
shop
blog
docs
cdn
static
" # why ?

main() {
    local main_domain="${1:-}"
    local output_file="nginx.conf"
    local base_port=8081
    local current_port

    if [[ -z "$main_domain" ]]; then
        echo "Usage: $0 <main-domain>"
        echo "Example: $0 mydomain.com"
        exit 1
    fi

    current_port="$base_port"

    cat > "$output_file" <<EOF
events {}

http {
    server {
        listen 80;
        server_name ${main_domain};

        location / {
            return 200 "Main domain: ${main_domain}\n";
        }
    }

EOF

    for subdomain in $POPULAR_SUBDOMAINS; do  # looping through this  block will add the whole block which is not what upstream does. you are creating new virtualhosts on web server
                                            # you are suppose to tak domain -> apped to it all the sub-domain, and make the original one push redirect traffic.
        cat >> "$output_file" <<EOF
    server {
        listen 80;
        server_name ${subdomain}.${main_domain}; 

        location / {
            proxy_pass http://host.docker.internal:${current_port};

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }

EOF

        current_port=$((current_port + 1))
    done

    cat >> "$output_file" <<EOF
}
EOF

    echo "Created ${output_file}"
    echo
    echo "Domain mappings:"
    echo "${main_domain} -> main nginx response"

    current_port="$base_port"

    for subdomain in $POPULAR_SUBDOMAINS; do
        echo "${subdomain}.${main_domain} -> host.docker.internal:${current_port}"
        current_port=$((current_port + 1))
    done
}

main "$@" # good work on taking all variables
