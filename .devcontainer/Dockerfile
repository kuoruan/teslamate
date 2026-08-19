FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential autoconf m4 \
      libncurses-dev libssl-dev \
      inotify-tools \
    && rm -rf /var/lib/apt/lists/*
