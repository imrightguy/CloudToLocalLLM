FROM ghcr.io/cirruslabs/flutter:3.41.6 AS builder

ENV PATH="/sdks/flutter/bin:/sdks/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --no-analytics && flutter config --enable-web && flutter precache --web

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter create . --platforms web
RUN flutter build web --release --base-href '/'

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY services/flutter-web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
