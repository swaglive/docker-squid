ARG         base=alpine:3.16

###

FROM        ${base} as squid

ARG         version=5.7

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
                --enable-auth-digest \
                # --enable-auth-basic="getpwnam,NCSA,DB" \
                # --enable-basic-auth-helpers="DB" \
                --enable-epoll \
                # --enable-external-acl-helpers="file_userip,unix_group,wbinfo_group" \
                # --enable-auth-ntlm="fake" \
                # --enable-auth-negotiate="kerberos,wrapper" \
                # --enable-silent-rules \
                # --disable-mit \
                # --enable-heimdal \
                --enable-delay-pools \
                # --enable-arp-acl \
                --enable-openssl \
                --enable-ssl-crtd \
                # --enable-security-cert-generators="file" \
                # --enable-ident-lookups \
                --enable-cache-digests \
                --enable-referer-log \
                --enable-useragent-log \
                --enable-async-io \
                # --enable-truncate \
                # --enable-arp-acl \
                # --enable-htcp \
                # --enable-carp \
                # --enable-follow-x-forwarded-for \
                # --enable-storeio="diskd rock" \
                --enable-ipv6 \
                # --enable-translation \
                # --disable-snmp \
                # --disable-dependency-tracking \
                --with-large-files \
                --with-default-user=squid \
                --with-openssl \
                && \
            make -j 32 && \
            make install

### 

FROM        ${base}

EXPOSE      3128/tcp
EXPOSE      3129/tcp

ENTRYPOINT  ["squid"]
CMD         ["-N"]

RUN         apk add --no-cache --virtual .run-deps \
                libstdc++ \
                libcap \
                libltdl	\
                ca-certificates \
                openssl \
                libressl

COPY        --from=squid --chown=squid:squid /etc/squid/ /etc/squid/
COPY        --from=squid --chown=squid:squid /usr/lib/squid/ /usr/lib/squid/
COPY        --from=squid --chown=squid:squid /usr/share/squid/ /usr/share/squid/
COPY        --from=squid --chown=squid:squid /usr/sbin/squid /usr/sbin/squid

COPY        --chown=squid:squid config/pid.conf /etc/squid/conf.d/pid.conf
COPY        --chown=squid:squid config/logs.conf /etc/squid/conf.d/logs.conf
COPY        --chown=squid:squid config/ssl-bump.conf /etc/squid/conf.d/ssl-bump.conf

RUN         install -d -o squid -g squid \
                /var/cache/squid \
                /var/log/squid \
                /var/run/squid \
                /var/lib/squid \
                /etc/squid/certs && \
            install -d -m 755 -o squid -g squid \
                /etc/squid/conf.d && \
            chmod +x /usr/lib/squid/*

USER        squid

RUN         echo 'include /etc/squid/conf.d/*.conf' >> /etc/squid/squid.conf && \

            # Generate SSL db
            /usr/lib/squid/security_file_certgen -c -s /var/cache/squid/ssl_db -M 4MB && \

            # Generate self-signed certificates
            openssl req -newkey rsa:4096 -x509 -nodes -batch \
                -keyout /etc/squid/certs/squid.pem \
                -out /etc/squid/certs/squid.pem && \

            # create missing cache directories and exit
            squid -Nz
