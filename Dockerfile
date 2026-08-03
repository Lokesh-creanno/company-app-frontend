# Build stage — Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
# Build with relative /api so Coolify reverse-proxy on same host can route to backend.
# Change --dart-define if backend lives on a different origin (e.g. https://api.example.com/api).
RUN flutter build web --release --base-href / --no-tree-shake-icons \
    --dart-define=API_BASE_URL=/api

# Serve stage — tiny nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O- http://127.0.0.1/ || exit 1
