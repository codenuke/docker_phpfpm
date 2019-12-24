FROM mcr.microsoft.com/mssql-tools as mssql
FROM php:7.2-fpm-alpine
RUN apk update && apk upgrade

COPY --from=mcr.microsoft.com/mssql-tools /opt/microsoft/ /opt/microsoft/
COPY --from=mcr.microsoft.com/mssql-tools /opt/mssql-tools/ /opt/mssql-tools/
COPY --from=mcr.microsoft.com/mssql-tools /usr/lib/libmsodbcsql-13.so /usr/lib/libmsodbcsql-13.so

RUN set -xe \
    && apk add --no-cache --virtual .persistent-deps \
        freetds \
        unixodbc \
	icu-dev \
	sqlite-dev \
	libmcrypt-dev \
	libxml2-dev \
	zlib-dev \
	autoconf \
	cyrus-sasl-dev \
	libgsasl-dev \
	freetype-dev \
	libjpeg-turbo-dev \
	libzip-dev \
	libpng-dev \
	postgresql-dev \
	supervisor \
	curl-dev \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        unixodbc-dev \
        freetds-dev \
        gcc \
        g++ \
	libmemcached-dev \
    && docker-php-source extract 

### Other ###
RUN docker-php-ext-install -j "$(nproc)" iconv mysqli  bcmath mbstring json xml zip opcache tokenizer exif curl 
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ 
RUN docker-php-ext-install gd

### Xdebug ###
RUN pecl install xdebug \
  && docker-php-ext-enable xdebug

### PDO ###
RUN docker-php-ext-install pdo_dblib pdo_sqlite pdo pdo_mysql 

### MSSQL ###
RUN pecl install  sqlsrv  pdo_sqlsrv \
  && docker-php-ext-enable --ini-name 30-sqlsrv.ini sqlsrv \
  && docker-php-ext-enable --ini-name 35-pdo_sqlsrv.ini pdo_sqlsrv 

### Redis ###
RUN pecl install redis && docker-php-ext-enable redis

### igbinary & memcached ###
RUN apk add --no-cache --update libmemcached-libs zlib
RUN set -xe && \
    cd /tmp/ && \
    apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS && \
    apk add --no-cache --update --virtual .memcached-deps zlib-dev libmemcached-dev cyrus-sasl-dev && \
# Install igbinary (memcached's deps)
    pecl install igbinary && \
# Install memcached
    ( \
        pecl install --nobuild memcached && \
        cd "$(pecl config-get temp_dir)/memcached" && \
        phpize && \
        ./configure --enable-memcached-igbinary && \
        make -j$(nproc) && \
        make install && \
        cd /tmp/ \
    ) && \
# Enable PHP extensions
    docker-php-ext-enable igbinary memcached && \
    rm -rf /tmp/* && \
    apk del .memcached-deps .phpize-deps

### Clear build-deps ###
RUN docker-php-source delete \
    && apk del .build-deps 

### Composer ###
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer 

CMD ["php-fpm"]
