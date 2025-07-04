# nginx/Dockerfile
FROM nginx:alpine

# Copy custom nginx configuration
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf

# Copy PHP application files to serve static content
COPY ./app/ /var/www/html/

# Create nginx user and set permissions
RUN addgroup -g 1000 -S nginxgroup && \
    adduser -u 1000 -S nginxuser -G nginxgroup && \
    chown -R nginxuser:nginxgroup /var/www/html && \
    chown -R nginxuser:nginxgroup /var/cache/nginx && \
    chown -R nginxuser:nginxgroup /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Install curl for health checks
RUN apk add --no-cache curl

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]