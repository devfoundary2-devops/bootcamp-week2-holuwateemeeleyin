# ---------- Base stage ----------
FROM node:20-alpine3.20 AS base

# Install base tools and security updates
RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache dumb-init && \
    rm -rf /var/cache/apk/*

# Create app directory and non-root user
WORKDIR /usr/src/app
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /usr/src/app


# ---------- Development stage ----------
FROM base AS development
USER nodejs

# Install all dependencies
COPY --chown=nodejs:nodejs package.json package-lock.json ./
RUN npm ci

# Copy source code
COPY --chown=nodejs:nodejs . .

EXPOSE 3000
CMD ["npm", "start"]


# ---------- Builder stage ----------
FROM base AS builder
USER nodejs

COPY --chown=nodejs:nodejs package*.json ./
# Only runtime deps for production
RUN npm ci --omit=dev

COPY --chown=nodejs:nodejs . .
RUN npm run build


# ---------- Production stage ----------
FROM nginx:1.27-alpine AS production

# Install curl for healthcheck
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Copy build output from builder
COPY --from=builder /usr/src/app/build /usr/share/nginx/html

# Copy custom nginx config (make sure this file exists in your project root)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Healthcheck for container
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Add a health endpoint file
RUN echo '{"status":"healthy","service":"frontend"}' > /usr/share/nginx/html/health

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]