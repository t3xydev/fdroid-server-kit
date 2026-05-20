FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    PATH="/opt/android-sdk/build-tools/36.0.0:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
      fdroidserver \
      rclone \
      wget \
      unzip \
      openjdk-17-jre-headless \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "$ANDROID_HOME/build-tools" \
    && wget -q -O /tmp/bt.zip \
       "https://dl.google.com/android/repository/build-tools_r36-linux.zip" \
    && unzip -q /tmp/bt.zip -d "$ANDROID_HOME/build-tools" \
    && mv "$ANDROID_HOME/build-tools/android-14" "$ANDROID_HOME/build-tools/36.0.0" 2>/dev/null || true \
    && rm /tmp/bt.zip \
    && chmod +x "$ANDROID_HOME/build-tools/36.0.0/"* 2>/dev/null || true

WORKDIR /srv/fdroid

COPY scripts/ scripts/
RUN chmod +x scripts/*.sh

COPY .env.example .env.example

ENTRYPOINT ["scripts/publish.sh"]
