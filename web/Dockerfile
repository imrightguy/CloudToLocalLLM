FROM nginx:1.27-alpine

USER root

COPY build/web /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx

USER nginx

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
