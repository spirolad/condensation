# Stage 1: Build dependencies
FROM php:8.3-cli AS build
WORKDIR /app

# Install zip/unzip required by composer
RUN apt-get update && apt-get install -y git unzip libzip-dev \
    && docker-php-ext-install zip

# Get composer locally
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy ONLY composer files first to leverage Docker layer caching
COPY composer.json composer.lock ./

# Install dependencies before copying the full code
RUN composer install --no-interaction --optimize-autoloader --no-scripts || \
    composer update --no-interaction --optimize-autoloader --no-scripts

# Now copy the rest of the application code
COPY . .

# Run auto-discovery and optimizations
RUN composer dump-autoload --optimize --no-scripts

# Stage 2: Final Runtime image
FROM php:8.3-apache
WORKDIR /var/www/html

# Install ONLY the necessary system extensions
# We keep mysql and postgres clients so docker-entrypoint.sh can ping either DB
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    postgresql-client \
    git \
    unzip \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    && docker-php-ext-install pdo_mysql pdo_pgsql zip mbstring xml \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache mod_rewrite for Laravel routing
RUN a2enmod rewrite

# Configure Apache DocumentRoot to point to Laravel's public directory
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Copy the fully built application from Stage 1
COPY --from=build /app /var/www/html

# Set strict permissions for the webserver user
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Copy the entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Apache runs natively on Port 80
EXPOSE 80

# Start correctly with proper PID 1 inheritance for graceful shutdowns
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
