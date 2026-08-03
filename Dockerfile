# Pre-built Flutter web served via nginx.
# We ship build/web contents committed under web-dist/ so Coolify skips the heavy
# Flutter compile step (used to OOM on 4GB Linode with cirruslabs/flutter image).
# Rebuild locally: flutter build web --release --base-href / --dart-define=API_BASE_URL=/api
# Then: rm -rf web-dist && cp -r build/web web-dist && git add web-dist && commit.
FROM nginx:alpine
COPY web-dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O- http://127.0.0.1/ || exit 1
