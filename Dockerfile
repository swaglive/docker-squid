ARG         base=alpine:3.16

FROM        ${base} as squid

ARG         version=5.6

WORKDIR     /src

RUN         apk add --no-cache --virtual .build-deps \
                gcc \
                g++ \
                libc-dev \
                curl \
                gnupg \
                libressl-dev \
                perl-dev \
                autoconf \
                automake \
                make \
                pkgconfig \
                # heimdal-dev \
                libtool \
                libcap-dev \
                linux-headers && \
            curl -SsL http://www.squid-cache.org/Versions/v${version%%.*}/squid-${version}.tar.gz | tar -xz

WORKDIR     /src/squid-${version}

RUN         ./configure \
                --prefix=/usr \
                --datadir=/usr/share/squid \
                --sysconfdir=/etc/squid \
                --libexecdir=/usr/lib/squid \
                --localstatedir=/var \
                --with-logdir=/var/log/squid \
                # --enable-removal-policies="lru,heap" \
                # --enable-auth-digest \
                # --enable-auth-basic="getpwnam,NCSA,DB" \
                # --enable-basic-auth-helpers="DB" \
                # --enable-epoll \
                # --enable-external-acl-helpers="file_userip,unix_group,wbinfo_group" \
                # --enable-auth-ntlm="fake" \
                # --enable-auth-negotiate="kerberos,wrapper" \
                # --enable-silent-rules \
                # --disable-mit \
                # --enable-heimdal \
                # --enable-delay-pools \
                # --enable-arp-acl \
                --enable-openssl \
                --enable-ssl-crtd \
                # --enable-security-cert-generators="file" \
                # --enable-ident-lookups \
                # --enable-cache-digests \
                # --enable-referer-log \
                # --enable-useragent-log \
                --enable-async-io \
                # --enable-truncate \
                # --enable-arp-acl \
                # --enable-htcp \
                # --enable-carp \
                # --enable-epoll \
                # --enable-follow-x-forwarded-for \
                # --enable-storeio="diskd rock" \
                --enable-ipv6 \
                # --enable-translation \
                # --disable-snmp \
                # --disable-dependency-tracking \
                # --with-large-files \
                --with-default-user=squid \
                --with-openssl \
                # --with-pidfile=/var/run/squid/squid.pid 
                && \
            make -j 32 && \
            make install

###

FROM        ${base} as s6

ARG         s6_version=3.1.0.1

RUN         apk add --no-cache --virtual .build-deps \
                curl && \
            curl -L https://github.com/just-containers/s6-overlay/releases/download/v${s6_version}/s6-overlay-noarch.tar.xz | tar -Jxvp -C /usr/local/bin && \
            curl -L https://github.com/just-containers/s6-overlay/releases/download/v${s6_version}/s6-overlay-x86_64.tar.xz | tar -Jxvp -C /usr/local/bin && \
            apk del .build-deps

### 

FROM        ${base}

ENV         S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV         S6_KEEP_ENV=1
ENV         KUBECONFIG=/.kube/config

EXPOSE      3128/tcp

ENTRYPOINT  ["/init", "squid"]
CMD         ["-NYC"]

RUN         apk add --no-cache --virtual .run-deps \
                libstdc++ \
                libcap \
                libressl3.5-libcrypto \
                libressl3.5-libssl \
                libltdl	\
                ca-certificates

COPY        --from=s6 /usr/local/bin /
COPY        --chown=root:root rootfs/cont-init.d /etc/cont-init.d
COPY        --from=squid /etc/squid/ /etc/squid/
COPY        --from=squid /usr/lib/squid/ /usr/lib/squid/
COPY        --from=squid /usr/share/squid/ /usr/share/squid/
COPY        --from=squid /usr/sbin/squid /usr/sbin/squid

RUN         install -d -o squid -g squid \
                /var/cache/squid \
                /var/log/squid \
                /var/run/squid && \
            chmod +x /usr/lib/squid/* && \
            install -d -m 755 -o squid -g squid \
                /etc/squid/conf.d

USER        squid