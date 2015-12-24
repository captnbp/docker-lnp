FROM alpine:latest
MAINTAINER Benoît Pourre <benoit.pourre@gmail.com>

EXPOSE 80 443

ENV HOME=/root

CMD ["/bin/sh", "/start.sh"]

# install packages
RUN apk --update --no-progress add \
	nginx git vim curl openssl wget unzip ssmtp \
	php-fpm php-json php-mysql php-curl php-xml php-iconv php-ctype php-dom php-intl php-exif php-cli php-ldap php-xmlrpc php-xsl \
	php-pgsql php-mysqli php-pdo_mysql php-pdo_pgsql php-pdo_sqlite php-sqlite3 \
	php-gd php-ftp php-posix php-zip php-zlib php-bz2 php-openssl php-mcrypt php-phar \
	supervisor py-pip \
	&& apk add php-geoip --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted \
	&& rm -rf /var/cache/apk/*

RUN pip install --upgrade pip Jinja2 && pip install envtpl

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

# add test PHP file
ADD ./index.php /usr/share/nginx/html/index.php
RUN chown -Rf nobody:nobody /usr/share/nginx/html/

RUN cd /tmp && \
    php -r "readfile('https://getcomposer.org/installer');" | php && \
    mv composer.phar /usr/local/bin/composer
