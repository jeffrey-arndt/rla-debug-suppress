FROM kong/kong-gateway:3.10.0.10

USER root

COPY log_filter.lua /etc/kong/log_filter.lua
COPY build-template.sh /usr/local/bin/build-template.sh
RUN chmod +x /usr/local/bin/build-template.sh && /usr/local/bin/build-template.sh

USER kong
