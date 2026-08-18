#!/bin/sh
set -e

# 首次创建：起 Postgres + 等就绪 + 装依赖 + 建库
docker run -d --name teslamate-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=teslamate_dev \
  -p 5432:5432 \
  postgres:18

# 等 Postgres 可连接
until pg_isready -h 127.0.0.1 -U postgres -d teslamate_dev >/dev/null 2>&1; do
  sleep 1
done

mix deps.get
mix setup
