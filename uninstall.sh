#!/usr/bin/env bash
set -euo pipefail

plugin_id=org.deepin.ds.dock.codexstats
rm -f "$HOME/.local/lib/dde-shell/$plugin_id.so"
rm -rf "$HOME/.local/share/dde-shell/$plugin_id"
rm -f "$HOME/.config/systemd/user/dde-shell@DDE.service.d/codex-dock.conf"
systemctl --user daemon-reload
systemctl --user restart dde-shell@DDE.service
echo '已卸载 Codex Deepin 任务栏插件。旧 Conky 配置仍保留，可按需手动启用。'
