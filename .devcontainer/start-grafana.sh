#!/bin/sh
set -e

# 可选：启动 Grafana（改 dashboard 时需要）
# 镜像不存在时自动构建（make grafana）
docker image inspect teslamate-grafana:latest >/dev/null 2>&1 || docker build -t teslamate-grafana:latest grafana/

# 用 host.docker.internal 连已有的 Postgres（sibling 容器经宿主端口映射）
docker run -d --name teslamate-grafana \
  -e DATABASE_USER=postgres \
  -e DATABASE_PASS=postgres \
  -e DATABASE_NAME=teslamate_dev \
  -e DATABASE_HOST=host.docker.internal \
  -p 3000:3000 \
  teslamate-grafana:latest 2>/dev/null || docker start teslamate-grafana

echo "Grafana: http://localhost:3000 (admin/admin)"
