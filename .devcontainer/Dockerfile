FROM elixir:1.20.2-otp-29

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential inotify-tools postgresql-client \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force
