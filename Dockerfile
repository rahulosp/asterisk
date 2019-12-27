FROM debian:8

ENV DEBIAN_FRONTEND=noninteractive \
    BCG729_VERSION=1.0.4 \
    ASTERISK_VERSION=15.7.3

RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y build-essential openssh-server apache2 mysql-server\
	mysql-client bison flex php5 php5-curl php5-cli php5-mysql php-pear php5-gd curl sox\
	libncurses5-dev libssl-dev libmysqlclient-dev mpg123 libxml2-dev libnewt-dev sqlite3\
	libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev\
	libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev\
	libspandsp-dev sudo libmyodbc subversion libtool-bin python-dev\
	aptitude cron fail2ban net-tools vim wget unzip \
        && curl -sL https://deb.nodesource.com/setup_8.x | bash - \
        && apt-get -y install nodejs \
	&& rm -rf /var/lib/apt/lists/*

RUN cd /usr/src \
	&& wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.7.tar.gz \
	&& tar xfz jansson.tar.gz \
	&& rm -f jansson.tar.gz \
	&& cd jansson-* \
	&& autoreconf -i \
	&& ./configure \
	&& make \
	&& make install \
	&& rm -r /usr/src/jansson*

RUN cd /usr/src \
	&& wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-15.7.3.tar.gz \
	&& tar xfz asterisk-15.7.3.tar.gz \
	&& rm -f asterisk-15.7.3.tar.gz \
	&& cd asterisk-* \
	&& contrib/scripts/install_prereq install \
	&& ./configure --with-pjproject-bundled \
	&& make menuselect.makeopts \
	&& sed -i "s/BUILD_NATIVE //" menuselect.makeopts \
	&& make \
	&& make install \
	&& make config \
	&& ldconfig \
	&& update-rc.d -f asterisk remove \
	&& rm -r /usr/src/asterisk*

RUN useradd -m asterisk \
	&& chown asterisk. /var/run/asterisk \
	&& chown -R asterisk. /etc/asterisk \
	&& chown -R asterisk. /var/lib/asterisk \
	&& chown -R asterisk. /var/log/asterisk \
	&& chown -R asterisk. /var/spool/asterisk \
	&& chown -R asterisk. /usr/lib/asterisk \
	&& rm -rf /var/www/html

RUN sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 120M/' /etc/php5/apache2/php.ini \
	&& sed -i 's/^memory_limit = 128M/memory_limit = 256M/' /etc/php5/apache2/php.ini \
	&& cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig \
	&& sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf \
	&& sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

COPY ./config/odbcinst.ini /etc/odbcinst.ini
COPY ./config/odbc.ini /etc/odbc.ini

RUN cd /usr/src \
	&& wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-14.0-latest.tgz \
	&& tar xfz freepbx-14.0-latest.tgz \
	&& rm -f freepbx-14.0-latest.tgz \
	&& cd freepbx \
	&& chown mysql:mysql -R /var/lib/mysql/* \
	&& /etc/init.d/mysql start \
	&& ./start_asterisk start \
	&& ./install -n --webroot="/var/www/html" \
	&& fwconsole chown \
	&& fwconsole ma upgradeall \
	&& fwconsole ma downloadinstall announcement userman cel calendar backup bulkhandler ringgroups timeconditions ivr restapi configedit asteriskinfo \
	&& /etc/init.d/mysql stop \
#	&& rm -rf /usr/src/freepbx*

RUN a2enmod rewrite && service apache2 restart && mkdir -p /usr/src/asterisk-g72x

COPY ./cfc2eb7bce73.zip /usr/src/asterisk-g72x/cfc2eb7bce73.zip

#### Add G729 Codecs
RUN	git clone https://github.com/BelledonneCommunications/bcg729 /usr/src/bcg729 ; \
	cd /usr/src/bcg729 ; \
	git checkout tags/$BCG729_VERSION ; \
	./autogen.sh ; \
	./configure --libdir=/lib ; \
	make ; \
	make install ; \
	\
        cd /usr/src/asterisk-g72x ; \
        unzip cfc2eb7bce73.zip ; \
        mv arkadi-asterisk-g72x-cfc2eb7bce73/* . ; \
	./autogen.sh ; \
	./configure --with-bcg729 --with-asterisk150 --enable-penryn; \
	make ; \
	make install

RUN sed -i 's/^user		= mysql/user		= root/' /etc/mysql/my.cnf

COPY ./run /run
RUN chmod +x /run/*

RUN chown asterisk:asterisk -R /var/spool/asterisk
#####################Trying to hold data in volumes#######################
RUN cp /etc/odbc.ini . && mv odbc.ini cptstrah.txt \
        && mkdir -p /assets/var/run/asterisk  && mkdir -p /data/var/run/asterisk \
        && cp -ar /var/run/asterisk/* /assets/var/run/asterisk/ \
        #&& rm -rf /var/run/asterisk && ln -s /data/var/run/asterisk /var/run/asterisk \
        && mkdir -p /assets/etc/asterisk \
        #&& mkdir -p /data/etc/asterisk \
        && cp -ar /etc/asterisk/* /assets/etc/asterisk/ \
        #&& rm -rf /etc/asterisk && ln -s /data/etc/asterisk /etc/asterisk \
        && mkdir -p /assets/var/lib/asterisk  \
        #&& mkdir -p /data/var/lib/asterisk \
        && cp -ar /var/lib/asterisk/* /assets/var/lib/asterisk/ \
        #&& rm -rf /var/lib/asterisk && ln -s /data/var/lib/asterisk /var/lib/asterisk \
        && mkdir -p /assets/var/spool/asterisk \
        #&& mkdir -p /data/var/spool/asterisk \
        && cp -ar /var/spool/asterisk/* /assets/var/spool/asterisk/ \
        #&& rm -rf /var/spool/asterisk && ln -s /data/var/spool/asterisk /var/spool/asterisk \
        && mkdir -p /backup && mkdir -p /data/backup \
        && rm -rf /backup && ln -s /data/backup /backup \
        && mkdir -p /assets/var/www/html && mkdir -p /data/var/www/html \
        && cp -ar /var/www/html/* /assets/var/www/html/ 
        #&& rm -rf /var/www/html && ln -s /data/var/www/html /var/www/html
###############Adding Volumes to make docker start using Volume mounts on these directories######
VOLUME /var/run/asterisk
VOLUME /etc/asterisk
VOLUME /var/spool/asterisk
VOLUME /var/www/html
#############Copy of data will be initiated via the script once container starts ###############
#####################Data persistence ends here ##########################
CMD /run/startup.sh
COPY lib_bkp.sh /etc/cron.daily/lib_bkp
RUN chmod +x /etc/cron.daily/lib_bkp

EXPOSE 80 3306 5060 5061 5160 5161 4569 18000-18100/udp
