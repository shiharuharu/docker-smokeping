FROM lscr.io/linuxserver/smokeping:latest

COPY ./mod/Smokeping.pm /usr/share/perl5/vendor_perl/Smokeping.pm
COPY ./mod/Smokeping/* /usr/share/perl5/vendor_perl/Smokeping/
COPY ./mod/Smokeping/probes/* /usr/share/perl5/vendor_perl/Smokeping/probes

COPY ./config/* /defaults/smoke-conf/

RUN apk update && apk add traceroute font-noto font-noto-cjk font-noto-extra font-noto-emoji \
    && chmod a+s /usr/bin/traceroute \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*