ARG THRUK_VERSION="3.18"
ARG UBUNTU_VERSION="noble"

FROM ubuntu:${UBUNTU_VERSION} AS build
ARG APT_PROXY
WORKDIR /build
# Create an apt proxy configuration
RUN if [ -n "$APT_PROXY" ]; then \
        echo "Acquire::http::Proxy \"$APT_PROXY\";" > /etc/apt/apt.conf.d/01proxy; \
    fi
RUN apt update -y && apt install --no-install-recommends -y \
	build-essential \
	ca-certificates \
	curl \
	rsync \
	libgd-dev \
	libmysqlclient-dev \
	chrpath \
	libmodule-install-perl \
	nodejs \
	npm
ARG THRUK_VERSION
RUN cd /build && \
	curl -sSL -o thruk_libs-v${THRUK_VERSION}.tar.gz https://github.com/sni/thruk_libs/archive/refs/tags/v${THRUK_VERSION}.tar.gz && \
	tar -xzf thruk_libs-v${THRUK_VERSION}.tar.gz && \
	cd /build/thruk_libs-${THRUK_VERSION} && \
	make -j"$(nproc)" && \
	DESTDIR=/build/target make installbuilddeps && \
	DESTDIR=/build/target make install
RUN cd /build && \
	curl -sSL -o thruk-v${THRUK_VERSION}.tar.gz https://github.com/sni/thruk/archive/refs/tags/v${THRUK_VERSION}.tar.gz && \
	tar -xzf thruk-v${THRUK_VERSION}.tar.gz && \
	cd /build/Thruk-${THRUK_VERSION} && \
	PERL5LIB="/build/target/usr/lib/thruk/perl5:$PERL5LIB" perl Makefile.PL && \
	PERL5LIB="/build/target/usr/lib/thruk/perl5:$PERL5LIB" ./configure --prefix="" --exec-prefix="" --bindir=/build/target/usr/bin --libdir=/build/target/usr/lib/thruk --sysconfdir=/build/target/etc/thruk --localstatedir=/build/target/var/lib/thruk --datadir=/build/target/usr/share/thruk --mandir=/build/target/usr/share/man --with-initdir=/build/target/etc/init.d --with-logdir=/build/target/var/log/thruk --with-cachedir=/build/target/var/cache/thruk --with-tmpdir=/build/target/var/cache/thruk --with-logrotatedir=/build/target/etc/logrotate.d --with-bashcompletedir=/build/target/etc/bash_completion.d --with-thruk-user=www-data --with-thruk-group=www-data --with-thruk-libs=/build/target/usr/lib/thruk/perl5 --with-httpd-conf=/build/target/etc/apache2/conf-available --with-htmlurl=/thruk --with-checkresultdir=/var/cache/naemon/checkresults --with-unsafeallow3f && \
	make -j"$(nproc)" && \
	make install && \
	for i in $(grep -nrl build\/target /build/target | uniq); do sed -i 's/\/build\/target//g' $i; done && \
	for i in $(grep -nrl usr\/local\/tmp /build/target | uniq); do sed -i 's/\/usr\/local\/tmp/\/var\/cache\/thruk/g' $i; done

FROM ubuntu:${UBUNTU_VERSION} AS final
ARG APT_PROXY
# Create an apt proxy configuration
RUN if [ -n "$APT_PROXY" ]; then \
        echo "Acquire::http::Proxy \"$APT_PROXY\";" > /etc/apt/apt.conf.d/01proxy; \
    fi
RUN apt update -y  && apt install --no-install-recommends -y \
	ca-certificates \
	apache2 \
	libapache2-mod-fcgid \
	liblwp-protocol-https-perl \
	libgd3 \
	libmysqlclient21 && \
	rm -rf /var/lib/apt/lists/*
COPY --from=build /build/target/etc /etc
COPY --from=build /build/target/usr /usr
COPY --from=build /build/target/var /var
RUN sed -i 's/ErrorLog\ \/var\/log\/apache2\/error.log/ErrorLog\ \/dev\/stderr\nCustomLog\ \/dev\/stdout\ combined/g' /etc/apache2/apache2.conf && \
	for i in $(grep -nrl $\{APACHE_RUN_USER /etc/apache2 | uniq ); do sed -i 's/${APACHE_RUN_USER}/www-data/g' $i; done && \
	for i in $(grep -nrl $\{APACHE_RUN_GROUP /etc/apache2 | uniq ); do sed -i 's/${APACHE_RUN_GROUP}/www-data/g' $i; done && \
	for i in $(grep -nrl $\{APACHE_PID_FILE /etc/apache2 | uniq ); do sed -i 's/${APACHE_PID_FILE}/\/var\/run\/apache2\/apache2.pid/g' $i; done && \
	for i in $(grep -nrl $\{APACHE_RUN_DIR /etc/apache2 | uniq ); do sed -i 's/${APACHE_RUN_DIR}/\/var\/run\/apache2/g' $i; done && \
	for i in $(grep -nrl $\{APACHE_LOCK_DIR /etc/apache2 | uniq ); do sed -i 's/${APACHE_LOCK_DIR}/\/var\/lock\/apache2/g' $i; done && \
	for i in $(grep -nrl $\{APACHE_LOG_DIR /etc/apache2 | uniq ); do sed -i 's/${APACHE_LOG_DIR}/\/var\/log\/apache2/g' $i; done && \
	for i in /etc/thruk/plugins/plugins-available/*; do ln -sf /usr/share/thruk/plugins/plugins-available/$(echo $i | cut -d'/' -f6) /etc/thruk/plugins/plugins-available/$(echo $i | cut -d'/' -f6); done && \
	for i in /etc/thruk/themes/themes-available/*; do ln -sf /usr/share/thruk/themes/themes-available/$(echo $i | cut -d'/' -f6) /etc/thruk/themes/themes-available/$(echo $i | cut -d'/' -f6); done && \
	mkdir -p /var/run/apache2/socks \
	/var/lock/apache2 \
	/var/log/apache2 \
	/var/cache/thruk \
	/etc/thruk/bp \
	/etc/thruk/panorama \
	/etc/thruk/thruk_local.d && \
	chown -R www-data:www-data /var/run/apache2 \
	/var/lock/apache2 \
	/var/log/apache2 \
	/var/cache/thruk \
	/var/lib/thruk \
	/var/log/thruk \
	/etc/thruk/bp \
	/etc/thruk/panorama \
	/etc/thruk/thruk_local.conf \
	/etc/thruk/thruk_local.d && \
	a2dissite 000-default.conf && \
	a2enmod remoteip rewrite deflate headers && \
	a2enconf thruk thruk_cookie_auth_vhost
EXPOSE 80
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
