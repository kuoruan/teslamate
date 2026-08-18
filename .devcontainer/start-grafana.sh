#!/bin/sh
set -e

# 可选：启动 Grafana（改 dashboard 时需要）
# 镜像不存在时自动构建（make grafana）
docker image inspect teslamate-grafana:latest >/dev/null 2>&1 || docker build -t teslamate-grafana:latest grafana/

# 把仓库的 dashboard 目录挂载进容器，改仓库文件即生效（需 LOCAL_WORKSPACE_FOLDER 指向宿主仓库路径）
WS="${LOCAL_WORKSPACE_FOLDER:?LOCAL_WORKSPACE_FOLDER not set}"

docker run -d --name teslamate-grafana \
  -e DATABASE_USER=postgres \
  -e DATABASE_PASS=postgres \
  -e DATABASE_NAME=teslamate_dev \
  -e DATABASE_HOST=host.docker.internal \
  -p 3000:3000 \
  -v "$WS/grafana/dashboards:/dashboards" \
  -v "$WS/grafana/dashboards/internal:/dashboards_internal" \
  -v "$WS/grafana/dashboards/reports:/dashboards_reports" \
  teslamate-grafana:latest 2>/dev/null || docker start teslamate-grafana

echo "Grafana: http://localhost:3000 (admin/admin)"
echo "改 dashboard: 直接编辑 grafana/dashboards/*.json，或在 UI 改后保存到挂载文件"
