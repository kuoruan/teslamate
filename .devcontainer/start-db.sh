#!/bin/sh
# 重启时拉起已存在的 Postgres 容器
docker start teslamate-db 2>/dev/null || true
