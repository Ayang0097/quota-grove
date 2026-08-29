#!/bin/zsh
set -euo pipefail

label="com.ayang.quotagrove"
installed_app="$HOME/Applications/Quota Grove.app"
launch_agent="$HOME/Library/LaunchAgents/$label.plist"
application_data="$HOME/Library/Application Support/Quota Grove"
timestamp=$(date +%Y%m%d-%H%M%S)

pkill -x QuotaGrove 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true

if [[ -f "$launch_agent" ]]; then
  rm "$launch_agent"
fi

if [[ -d "$installed_app" ]]; then
  mv "$installed_app" "$HOME/.Trash/Quota Grove $timestamp.app"
  echo "应用已移到废纸篓。"
fi

if [[ -d "$application_data" ]]; then
  mv "$application_data" "$HOME/.Trash/Quota Grove data $timestamp"
  echo "自定义背景等本地应用数据已移到废纸篓。"
fi

defaults delete "$label" 2>/dev/null || true
echo "Quota Grove 已卸载，登录启动和本地偏好已删除。"
