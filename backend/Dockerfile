# ==============================================================================
# Multi-stage Dockerfile for Minh Thanh Villa Backend (Node.js + TypeScript)
# ==============================================================================

# Stage 1: Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Install build dependencies
COPY package*.json tsconfig*.json ./

RUN npm ci

# Copy source code and database migrations
COPY src ./src
COPY database ./database

# Compile TypeScript to JavaScript in /app/dist
RUN npm run build

# Stage 2: Production runtime stage
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
# CONFLICT-RESOLVED: Đồng bộ cổng mặc định từ 5000 sang 7000 để khớp với env.ts, docker-compose.yml và Flutter config/dev.json
ENV PORT=7000

# Install curl for Docker health checks
RUN apk add --no-cache curl

# Create non-root system user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Install only production dependencies
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy compiled files and migrations from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/database ./database

# Create writable runtime cache/upload/backup directories and change file ownership to non-root user
RUN mkdir -p /app/data/cache /app/uploads /app/backups && chown -R appuser:appgroup /app
USER appuser

# CONFLICT-RESOLVED: Mở cổng 7000 và kiểm tra sức khỏe theo biến PORT (mặc định 7000) thay vì cổng 5000 cũ
EXPOSE 7000

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-7000}/api/health || exit 1

CMD ["node", "dist/index.js"]
