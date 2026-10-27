# Stage 1: Build Flutter app for web
# Use Node.js base + Flutter SDK to avoid slow builds; this requires pre-built artifacts
# For production, run: flutter build web --release locally, then use stage 2 only
FROM node:20-alpine AS builder

WORKDIR /app

# Install Flutter dependencies
RUN apk add --no-cache git curl unzip xz bash

# Clone Flutter SDK with retry logic and shallow clone (faster, smaller)
RUN for i in 1 2 3; do \
  git clone --branch stable --depth 1 https://github.com/flutter/flutter.git /flutter && break; \
  if [ $i -lt 3 ]; then echo "Retry $i failed, trying again..."; sleep 5; fi; \
done

RUN /flutter/bin/flutter config --enable-web && \
    /flutter/bin/flutter precache

ENV PATH="/flutter/bin:${PATH}"

# Copy project
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .

# Build web release (cache-friendly: dependencies already fetched)
RUN flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
