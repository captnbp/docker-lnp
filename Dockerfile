FROM alpine:latest
MAINTAINER Benoît Pourre <benoit.pourre@gmail.com>

EXPOSE 80 443

ENV HOME=/root

CMD ["/bin/sh", "/start.sh"]

# install packages
RUN apk --update --no-progress add --no-cache \
	nginx vim curl openssl wget unzip ssmtp \
	php-fpm php-json php-mysql php-curl php-xml php-iconv php-ctype php-dom php-intl php-exif php-cli php-ldap php-xmlrpc php-xsl \
	php-pgsql php-mysqli php-pdo_mysql php-pdo_pgsql php-pdo_sqlite php-sqlite3 \
    php-gd php-ftp php-posix php-zip php-zlib php-bz2 php-openssl php-mcrypt php-phar \
	supervisor python3 \
	&& apk add --no-cache php-geoip --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted \
	&& wget "https://bootstrap.pypa.io/get-pip.py" -O /dev/stdout | python3 \
	&& rm -rf /var/cache/apk/*

RUN pip3 install envtpl

# tweak nginx config
#RUN sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
#sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
#sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/php.ini && \
sed -i -e "s/;sendmail_path = /sendmail_path = sendmail -t -i/g" /etc/php/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/php-fpm.conf && \
sed -i -e "s/listen = 127\.0\.0\.1:9000/listen = \/var\/run\/php-fpm.sock/g" /etc/php/php-fpm.conf && \
sed -i -e "s/;listen.owner = nobody/listen.owner = nobody/g" /etc/php/php-fpm.conf && \
sed -i -e "s/;listen.group = nobody/listen.group = nobody/g" /etc/php/php-fpm.conf && \
sed -i -e "s/;listen.mode = 0660/listen.mode = 0660/g" /etc/php/php-fpm.conf
#sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/pool.d/www.conf && \
#sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/pool.d/www.conf && \
#sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/pool.d/www.conf && \
#sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/pool.d/www.conf && \
#sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/pool.d/www.conf
#sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/pool.d/www.conf

# fix ownership of sock file for php-fpm
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/php-fpm.conf 

RUN echo "date.timezone = Europe/Paris" >>  /etc/php/php.ini && \
    echo "phar.readonly = Off" >> /etc/php/php.ini

# nginx site conf
RUN rm -Rf /etc/nginx/conf.d/* && \
mkdir /etc/nginx/sites-enabled && \
mkdir -p /etc/nginx/ssl/

ADD ./nginx.conf /etc/nginx/nginx.conf
COPY ./conf.d /etc/nginx/
ADD ./nginx-site.conf /etc/nginx/sites-enabled/default.conf

# Supervisor Config
ADD ./supervisord.conf /etc/supervisord.conf

# Start Supervisord
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# Setup Volume
#VOLUME ["/usr/share/nginx/html"]

# add test PHP file
ADD ./index.php /usr/share/nginx/html/index.php
RUN chown -Rf nobody:nobody /usr/share/nginx/html/

RUN cd /tmp && \
    php -r "readfile('https://getcomposer.org/installer');" | php && \
    mv composer.phar /usr/local/bin/composer


