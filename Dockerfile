# Multi-stage build for Shadow platform

# Stage 1: Build Rust backend
FROM rust:1.75-slim as backend-builder

WORKDIR /app/backend

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy backend files
COPY backend/Cargo.toml ./
COPY backend/src ./src

# Build backend
RUN cargo build --release

# Stage 2: Build Next.js frontend
FROM node:20-alpine as frontend-builder

WORKDIR /app/frontend

# Copy frontend files
COPY frontend/package*.json ./
RUN npm ci

COPY frontend ./
RUN npm run build

# Stage 3: Runtime
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy backend binary
COPY --from=backend-builder /app/backend/target/release/shadow-backend /app/backend/shadow-backend

# Copy frontend build
COPY --from=frontend-builder /app/frontend/.next /app/frontend/.next
COPY --from=frontend-builder /app/frontend/public /app/frontend/public
COPY --from=frontend-builder /app/frontend/package*.json /app/frontend/
COPY --from=frontend-builder /app/frontend/node_modules /app/frontend/node_modules

# Copy migration files
COPY migrations ./migrations

EXPOSE 8080 3000

CMD ["sh", "-c", "/app/backend/shadow-backend & cd /app/frontend && npm start"]

