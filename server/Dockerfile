# Сервер онлайн-охоты «Пчёлок уважаешь?».
# Собирать из корня репозитория:  docker build -f server/Dockerfile -t phelki-server .
# Запуск:                         docker run -p 8910:8910 phelki-server
# Готовый образ собирает GitHub Actions: ghcr.io/b0dr0dev/phelki-server:latest
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/godot.zip \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /opt \
 && mv "/opt/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && rm /tmp/godot.zip

WORKDIR /game
COPY . .
RUN godot --headless --path /game --import

ENV PORT=8910
EXPOSE 8910
CMD ["sh", "-c", "godot --headless --path /game -- --server --port=${PORT} --rotate-maps"]
