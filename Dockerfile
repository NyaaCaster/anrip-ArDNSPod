FROM alpine:latest

LABEL maintainer="your-email@example.com"
LABEL description="DNSPod DDNS Client - Lightweight Docker Image"

RUN apk add --no-cache \
    wget \
    iproute2 \
    grep \
    gawk \
    sed \
    bash \
    && rm -rf /var/cache/apk/*

WORKDIR /app

COPY ddnspod.sh /app/ddnspod.sh
COPY dns.conf /app/dns.conf
COPY crontab /etc/crontabs/root
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN sed -i 's/\r$//' /app/ddnspod.sh && \
    sed -i 's/\r$//' /app/dns.conf && \
    sed -i 's/\r$//' /etc/crontabs/root && \
    sed -i 's/\r$//' /docker-entrypoint.sh && \
    chmod +x /app/ddnspod.sh && \
    chmod +x /docker-entrypoint.sh

RUN mkdir -p /var/log && \
    touch /var/log/ddns.log && \
    chmod 666 /var/log/ddns.log

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["crond", "-f", "-l", "2"]
