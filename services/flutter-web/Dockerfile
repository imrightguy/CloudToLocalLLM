FROM ubuntu:22.04 AS builder

RUN for attempt in 1 2 3 4 5; do \
      apt-get update && break; \
      echo "apt-get update failed; retrying in $((attempt * 5))s"; \
      sleep $((attempt * 5)); \
    done \
    && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter precache --web
RUN flutter config --no-analytics
RUN flutter config --enable-web

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
