#!/bin/sh
set -e

# 首次创建：起 Postgres + 等就绪 + 装依赖 + 建库
docker run -d --name teslamate-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=teslamate_dev \
  -p 5432:5432 \
  postgres:18

# 等 Postgres 可连接（经宿主端口映射访问 sibling 容器）
until pg_isready -h host.docker.internal -U postgres -d teslamate_dev >/dev/null 2>&1; do
  sleep 1
done

mix deps.get
mix setup

# 创建测试数据库
MIX_ENV=test mix ecto.setup
