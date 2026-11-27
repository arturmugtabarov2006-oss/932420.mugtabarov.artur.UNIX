FROM alpine:latest

RUN apk add --no-cache util-linux

COPY script.sh /script.sh
RUN chmod +x /script.sh

ENTRYPOINT ["/script.sh"]