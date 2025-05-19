# --------- Build Logseq from Source ---------
FROM ubuntu:22.04 AS builder

# Set environment
ENV DEBIAN_FRONTEND=noninteractive \
    LOGSEQ_BRANCH=test/db \
    TITLE=logseq

LABEL maintainer="linuxserver.io"

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    openjdk-17-jdk \
    curl \
    ca-certificates \
    libfuse2 \
    build-essential \
    libnss3 libxss1 libx11-xcb1 libgtk-3-0 libnotify4 libgconf-2-4 \
    libxcomposite1 libxdamage1 libxrandr2 libxtst6 libxkbfile1 xdg-utils \
    fuse \
    python3 g++ make pkg-config unzip \
    zip \
    default-jre

# Install Node.js 22.x and npm
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

# Install yarn
RUN npm install -g yarn

# Clone and build Logseq
WORKDIR /opt
RUN git clone -b $LOGSEQ_BRANCH --depth=1 https://github.com/logseq/logseq.git

WORKDIR /opt/logseq
RUN curl -O https://download.clojure.org/install/linux-install-1.11.1.1273.sh && \
    chmod +x linux-install-1.11.1.1273.sh && ./linux-install-1.11.1.1273.sh && \
    yarn install && \
    yarn release-electron


# --------- Runtime Layer ---------
FROM ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm

# Install additional runtime packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-l10n \
    git \
    libgtk-3-bin \
    libatk1.0 \
    libatk-bridge2.0 \
    libnss3 \
    python3-xdg && \
    apt-get clean

# Copy built Logseq AppImage
COPY --from=builder /opt/logseq/static/out/make/Logseq-0.11.0.AppImage /tmp/logseq.app

# Install Logseq AppImage
RUN echo "**** add icon ****" && \
    curl -o /kclient/public/icon.png \
      https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/obsidian-logo.png && \
    cd /tmp && \
    chmod +x logseq.app && \
    ./logseq.app --appimage-extract && \
    mv squashfs-root /opt/logseq && \
    cp /opt/logseq/usr/share/icons/hicolor/256x256/apps/Logseq.png /usr/share/icons/hicolor/256x256/apps/Logseq.png && \
    echo "**** cleanup ****" && \
    apt-get autoclean && \
    rm -rf \
      /config/.cache \
      /config/.launchpadlib \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /tmp/*

# Add local files (e.g., optional startup scripts or desktop entries)
COPY /root /



# Stub lsiown to avoid init-adduser failure
#RUN echo -e '#!/bin/bash\nexit 0' > /usr/bin/lsiown && chmod +x /usr/bin/lsiown


# Expose ports and volumes
EXPOSE 3000
VOLUME /config
