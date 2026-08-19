#!/bin/sh
set -e

docker image inspect teslamate-grafana:latest >/dev/null 2>&1 || docker build -t teslamate-grafana:latest grafana/

docker run -d --name teslamate-grafana \
  -e DATABASE_USER=postgres \
  -e DATABASE_PASS=postgres \
  -e DATABASE_NAME=teslamate_dev \
  -e DATABASE_HOST=localhost \
  -p 3000:3000 \
  -v "$WORKSPACE_FOLDER/grafana/dashboards:/dashboards" \
  -v "$WORKSPACE_FOLDER/grafana/dashboards/internal:/dashboards_internal" \
  -v "$WORKSPACE_FOLDER/grafana/dashboards/reports:/dashboards_reports" \
  teslamate-grafana:latest 2>/dev/null || docker start teslamate-grafana
