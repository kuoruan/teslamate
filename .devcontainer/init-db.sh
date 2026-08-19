#!/bin/sh
set -e

docker run -d --name teslamate-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=teslamate_dev \
  -p 5432:5432 \
  postgres:18

# 等 Postgres 可连接
until pg_isready -h localhost -U postgres -d teslamate_dev >/dev/null 2>&1; do
  sleep 1
done

mix deps.get
mix setup

MIX_ENV=test mix ecto.setup
