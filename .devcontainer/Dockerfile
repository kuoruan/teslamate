FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential autoconf m4 \
      libncurses-dev libssl-dev \
      inotify-tools jq \
    && rm -rf /var/lib/apt/lists/*

# treefmt: formatter aggregator (latest)
RUN VERSION=$(curl -fsSL https://api.github.com/repos/numtide/treefmt/releases/latest \
        | jq -r '.tag_name') \
    && curl -fsSL "https://github.com/numtide/treefmt/releases/download/${VERSION}/treefmt_${VERSION#v}_linux_amd64.tar.gz" \
        | tar -xz -C /usr/local/bin treefmt
