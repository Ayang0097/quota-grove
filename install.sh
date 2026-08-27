#!/bin/zsh
set -euo pipefail

project_root=${0:A:h}
source_app="$project_root/dist/Quota Grove.app"
install_dir="$HOME/Applications"
destination="$install_dir/Quota Grove.app"

"$project_root/Scripts/build-app.sh"
mkdir -p "$install_dir"

pkill -TERM -x QuotaGrove 2>/dev/null || true
sleep 0.3

if [[ -d "$destination" ]]; then
  timestamp=$(date +%Y%m%d-%H%M%S)
  mv "$destination" "$HOME/.Trash/Quota Grove previous $timestamp.app"
fi

ditto "$source_app" "$destination"
open "$destination"
echo "已安装并启动：$destination"
