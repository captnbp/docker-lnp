# Docker Alpine Nginx PHP-FPM
This is a Dockerfile to build a container image for nginx and php-fpm. The container can use environment variables to configure your web application using the templating detailed in the special features section.

## Installation
To build the container : 
```
docker build -t ${USER}/lnp https://github.com/captnbp/docker-lnp.git
```

## Running
To simply run the container:

```
sudo docker run --name lnp -p 8080:80 -d ${USER}/lnp
```
You can then browse to http://\<docker_host\>:8080 to view the default install files.

## Special Features

### Mails
You can setup a mail server to use the PHP mail() command by providing these variables when docker run:
```
MAIL_SMTP_HOST
MAIL_SMTP_PORT
MAIL_USER
MAIL_PASS
MAIL_DOMAIN
```
### Templating
This container will automatically configure your web application if you template your code. For example if you are using a MySQL container, and you have a config.php file where you need to set the MySQL details include Jinja2 style template tags.

Example /usr/share/nginx/html/conf/config.php.j2 :

```
<?php
database_name = {{ MYSQL_DATABASE }};
database_host = {{ MYSQL_PORT }};
...
?>
```

To activate the templating process, you have to create and add an executable script named render-config-files in the folder /usr/share/nginx/html/render-config-files :
```
ADD render-config-files /usr/share/nginx/html/render-config-files
```
This render-config-files script will contain one line per file you want to render :
```
#!/bin/sh
envtpl --allow-missing -o /usr/share/nginx/html/user/users.php /usr/share/nginx/html/user/users.php.j2
envtpl --allow-missing -o /usr/share/nginx/html/conf/config.php /usr/share/nginx/html/conf/config.php.j2
chown -R nobody:nobody /usr/share/nginx/html/*
```

### Nginx configuration
You can also add a custom Nginx file for your site. For example nginx-site.conf
```
server {
	listen   80; ## listen for ipv4; this line is default and implied
	listen   [::]:80 default ipv6only=on; ## listen for ipv6

	root /usr/share/nginx/html;
	index index.php index.html index.htm;

	# Disable sendfile as per https://docs.vagrantup.com/v2/synced-folders/virtualbox.html
	sendfile off;

	# Add stdout logging

	error_log /dev/stderr info;
	access_log /dev/stdout;

	#error_page 404 /404.html;

	# redirect server error pages to the static page /50x.html
	#
	error_page 500 502 503 504 /50x.html;
	location = /50x.html {
		root /usr/share/nginx/html;
	}

	# Rewrites
	location / {
		try_files $uri $uri/ /index.php;

		# PHP engine
		location ~ \.php$ {
			try_files      $uri =404;
			fastcgi_pass   unix:/var/run/php-fpm.sock; # Can be different
			fastcgi_index  index.php;
			fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
			include        fastcgi_params;
		}
	}

        location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
                expires           5d;
        }

	# deny access to . files, for security
	#
	location ~ /\. {
    		log_not_found off; 
    		deny all;
	}

}
```

Then add it in your container :
```
ADD nginx-site.conf /etc/nginx/sites-enabled/default.conf
```

## Example for Owncloud
Here is a Dockerfile to create an Owncloud Docker :
```
FROM captnbp/docker-lnp

MAINTAINER Benoît Pourre <benoit.pourre@gmail.com>

# install owncloud
ENV OWNCLOUD_VERSION 8.2.0
ENV OWNCLOUD_PACKAGE owncloud-$OWNCLOUD_VERSION.tar.bz2
ENV OWNCLOUD_URL https://download.owncloud.org/community/$OWNCLOUD_PACKAGE
RUN cd /usr/share/nginx/html \
    && curl -LOs $OWNCLOUD_URL \
    && tar xjf $OWNCLOUD_PACKAGE \
    && rm $OWNCLOUD_PACKAGE \
    && mkdir -p /usr/share/nginx/html/owncloud/config /usr/share/nginx/html/owncloud/data \
    && chmod 0770 /usr/share/nginx/html/owncloud/data \
    && chown -R nobody:nobody /usr/share/nginx/html/owncloud/data /usr/share/nginx/html/owncloud/config

ADD ./render-config-files /usr/share/nginx/html/render-config-files
ADD ./config.inc.php.j2 /usr/share/nginx/html/owncloud/config/config.inc.php.j2
ADD nginx-site.conf /etc/nginx/sites-enabled/default.conf

VOLUME ["/usr/share/nginx/html/owncloud/config", "/usr/share/nginx/html/owncloud/data"]
```

The nginx-site.conf file :
```
server {
	listen   80; ## listen for ipv4; this line is default and implied
	listen   [::]:80 default ipv6only=on; ## listen for ipv6

	root /usr/share/nginx/html/owncloud;
	index index.php;

	# set max upload size
	client_max_body_size 10G;
	fastcgi_buffers 64 4K;

	# Disable gzip to avoid the removal of the ETag header
	gzip off;

	# Disable sendfile as per https://docs.vagrantup.com/v2/synced-folders/virtualbox.html
	sendfile off;

	# Add stdout logging

	error_log /dev/stderr info;
	access_log /dev/stdout;

	rewrite ^/caldav(.*)$ /remote.php/caldav$1 redirect;
	rewrite ^/carddav(.*)$ /remote.php/carddav$1 redirect;
	rewrite ^/webdav(.*)$ /remote.php/webdav$1 redirect;

	index index.php;
	error_page 403 /core/templates/403.php;
	error_page 404 /core/templates/404.php;

	location = /robots.txt {
		allow all;
		log_not_found off;
		access_log off;
	}

	location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README){
		deny all;
	}

	location / {
		# The following 2 rules are only needed with webfinger
		rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
		rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;

		rewrite ^/.well-known/carddav /remote.php/carddav/ redirect;
		rewrite ^/.well-known/caldav /remote.php/caldav/ redirect;

		rewrite ^(/core/doc/[^\/]+/)$ $1/index.html;

		try_files $uri $uri/ /index.php;
	}

	location ~ \.php(?:$|/) {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
		include fastcgi_params;
		fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
		fastcgi_param PATH_INFO $fastcgi_path_info;
		fastcgi_param HTTPS on;
		fastcgi_pass   unix:/var/run/php-fpm.sock; # Can be different
	}

	# Optional: set long EXPIRES header on static assets
	location ~* \.(?:jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {
		expires 30d;
		# Optional: Don't log access to assets
		access_log off;
	}
}
```
The render-config-files :
```
#!/bin/sh
envtpl --allow-missing -o /usr/share/nginx/html/owncloud/config/config.inc.php /usr/share/nginx/html/owncloud/config/config.inc.php.j2
```
