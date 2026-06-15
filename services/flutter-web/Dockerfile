FROM ghcr.io/cirruslabs/flutter:3.41.6 AS builder

ENV PATH="/sdks/flutter/bin:/sdks/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --no-analytics && flutter config --enable-web && flutter precache --web

WORKDIR /app
ARG WEB_CACHE_BUST=latest
ARG API_BASE_URL=/api
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter create . --platforms web
RUN flutter build web --release --base-href '/' --dart-define=API_BASE_URL=${API_BASE_URL}
RUN set -eux; \
    mv build/web/main.dart.js "build/web/main.${WEB_CACHE_BUST}.dart.js"; \
    python3 -c "from pathlib import Path; root = Path('build/web'); p = root / 'flutter_bootstrap.js'; p.write_text(p.read_text().replace('main.dart.js', 'main.${WEB_CACHE_BUST}.dart.js')); p = root / 'index.html'; p.write_text(p.read_text().replace('flutter_bootstrap.js', 'flutter_bootstrap.js?v=${WEB_CACHE_BUST}'))"

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY services/flutter-web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
