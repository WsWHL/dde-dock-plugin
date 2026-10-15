#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
plugin_id=org.deepin.ds.dock.codexstats
plugin_dir="$HOME/.local/lib/dde-shell"
package_dir="$HOME/.local/share/dde-shell/$plugin_id"
helper_dir="$HOME/.local/share/codex-dock-plugin"
override_dir="$HOME/.config/systemd/user/dde-shell@DDE.service.d"

installed_version="$(dpkg-query -W -f='${Version}' dde-shell 2>/dev/null || true)"
built_version="$(cat "$project_dir/dist/dde-shell-version" 2>/dev/null || true)"
built_arch="$(cat "$project_dir/dist/architecture" 2>/dev/null || true)"
if [[ "$installed_version" != "$built_version" || "$(uname -m)" != "$built_arch" ]]; then
    echo '预编译模块与当前 dde-shell 版本或系统架构不匹配；请先运行 ./build.sh 重新编译。' >&2
    exit 1
fi

install -d "$plugin_dir" "$package_dir" "$helper_dir" "$override_dir"
install -m 755 "$project_dir/dist/$plugin_id.so" "$plugin_dir/$plugin_id.so"
install -m 644 "$project_dir/package/main.qml" "$project_dir/package/metadata.json" "$package_dir/"
install -m 644 "$project_dir/scripts/codex-rate-status.py" "$project_dir/scripts/codex-activity.py" "$project_dir/src/codexdock.cpp" "$helper_dir/"
printf '[Service]\nEnvironment=DDE_SHELL_PLUGIN_PATH=%%h/.local/lib/dde-shell\n' > "$override_dir/codex-dock.conf"
systemctl --user daemon-reload
systemctl --user restart dde-shell@DDE.service

if systemctl --user list-unit-files conky-panel.service --no-legend 2>/dev/null | grep -q conky-panel.service; then
    systemctl --user disable --now conky-panel.service || true
fi
if [[ -f "$HOME/.config/autostart/conky.desktop" ]]; then
    mv "$HOME/.config/autostart/conky.desktop" "$HOME/.config/autostart/conky.desktop.disabled"
fi

echo '已安装 Codex Deepin 任务栏插件。'
