FROM php:8.2-cli-alpine

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    mysql-client \
    curl \
    && docker-php-ext-install pdo pdo_mysql

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . /var/www/html/

# Create non-root user for security
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

# Set proper permissions
RUN chown -R appuser:appgroup /var/www/html
USER appuser

# Health check for ECS
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port 8000
EXPOSE 8000

# Use PHP built-in server on port 8000 (NOT PHP-FPM)
CMD ["php", "-S", "0.0.0.0:8000", "-t", "/var/www/html"]