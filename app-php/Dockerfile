FROM php:8.4-fpm-alpine

COPY index.php /var/www/html/index.php
# Replace the default pool; drop zz-docker.conf (it would override listen = 9000).
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
RUN rm -f /usr/local/etc/php-fpm.d/zz-docker.conf

ENV FPM_WORKERS=5
EXPOSE 9000

# zz-docker.conf used to set daemonize=no; do it on the command line instead.
CMD ["php-fpm", "--nodaemonize"]
