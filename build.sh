#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$project_dir/build" "$project_dir/dist"

if [[ -n "${CODEX_DOCK_SYSROOT:-}" ]]; then
    root="$CODEX_DOCK_SYSROOT/usr"
    moc="$root/lib/qt6/libexec/moc"
    include_flags=(
        "-I$root/include/dde-shell"
        "-I$root/include/dtk6/DCore"
        "-I$root/include/x86_64-linux-gnu/qt6"
        "-I$root/include/x86_64-linux-gnu/qt6/QtCore"
    )
    link_flags=(
        /usr/lib/x86_64-linux-gnu/libdde-shell.so.1
        /usr/lib/x86_64-linux-gnu/libdtk6core.so.6
        /usr/lib/x86_64-linux-gnu/libQt6Core.so.6
    )
else
    moc="$(command -v moc6 || true)"
    [[ -n "$moc" ]] || moc=/usr/lib/qt6/libexec/moc
    command -v pkg-config >/dev/null
    pkg-config --exists Qt6Core dtk6core
    [[ -f /usr/include/dde-shell/applet.h ]] || { echo '缺少 libdde-shell-dev' >&2; exit 1; }
    read -r -a qt_cflags <<< "$(pkg-config --cflags Qt6Core dtk6core)"
    read -r -a qt_libs <<< "$(pkg-config --libs Qt6Core dtk6core)"
    include_flags=(-I/usr/include/dde-shell "${qt_cflags[@]}")
    link_flags=(-ldde-shell "${qt_libs[@]}")
fi

"$moc" -I"${CODEX_DOCK_SYSROOT:-}/usr/include/dde-shell" -I/usr/include/dde-shell \
    "$project_dir/src/codexdock.cpp" -o "$project_dir/build/codexdock.moc"

g++ -std=c++17 -fPIC -shared -O2 \
    -I"$project_dir/build" "${include_flags[@]}" \
    "$project_dir/src/codexdock.cpp" \
    -o "$project_dir/dist/org.deepin.ds.dock.codexstats.so" \
    "${link_flags[@]}"

dpkg-query -W -f='${Version}' dde-shell > "$project_dir/dist/dde-shell-version"
uname -m > "$project_dir/dist/architecture"
echo "构建完成: $project_dir/dist/org.deepin.ds.dock.codexstats.so"
