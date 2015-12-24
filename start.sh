#!/bin/sh

# Tweak nginx to match the workers to cpu's
procs=$(cat /proc/cpuinfo |grep processor | wc -l)
sed -i -e "s/worker_processes 5/worker_processes $procs/" /etc/nginx/nginx.conf

if [ -f /usr/share/nginx/html/render-config-files ]
then
	/usr/share/nginx/html/render-config-files
fi


MAIL_SMTP_HOST=${MAIL_SMTP_HOST:-false}
if [ "$MAIL_SMTP_HOST" != "false" ]; then
    echo -e "mailhub=${MAIL_SMTP_HOST}:${MAIL_SMTP_PORT}\nroot=${MAIL_USER}\nhostname=${MAIL_DOMAIN}\nFromLineOverride=YES\nUseSTARTTLS=Yes\nAuthUser=${MAIL_USER}\nAuthPass=${MAIL_PASS}" > /etc/ssmtp/ssmtp.conf
fi


# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf
