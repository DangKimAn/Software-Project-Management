# ==============================================================================
# Multi-stage Dockerfile for Minh Thanh Villa Backend (Node.js + TypeScript)
# ==============================================================================

# Stage 1: Build stage
FROM node:20-alpine AS builder

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
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5000

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

# Change file ownership to non-root user
USER appuser

EXPOSE 5000

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

CMD ["node", "dist/index.js"]
