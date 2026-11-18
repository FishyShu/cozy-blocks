#!/bin/sh
# install.sh: Cozy Blocks wallpaper + Koi Pond lock screen + hotkeys + music, for KDE Plasma 6 (Wayland).
# Re-runnable. Undo steps are in the README.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
wp="$HOME/.local/share/plasma/wallpapers"
apps="$HOME/.local/share/applications"

# 1. plugins: symlink so `git pull` updates them (skipped when the repo already lives in $wp)
mkdir -p "$wp" "$HOME/.local/bin" "$apps" "${XDG_CACHE_HOME:-$HOME/.cache}/cozyblocks"
if [ "$here" != "$wp" ]; then
    for p in com.fishyshu.cozyblocks com.fishyshu.koipond; do
        [ -e "$wp/$p" ] && [ ! -L "$wp/$p" ] && mv "$wp/$p" "$wp/$p.bak-$(date +%s)"
        ln -sfn "$here/$p" "$wp/$p"
    done
fi
ln -sf "$here/tools/cozy" "$HOME/.local/bin/cozy"

# 2. hotkeys Meta+Alt+N / M / C -> cozy next / mute / pet (active after the next login)
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/kglobalshortcutsrc"
[ -f "$cfg" ] && [ ! -f "$cfg.bak-cozy" ] && cp "$cfg" "$cfg.bak-cozy"
for spec in "next N Cozy: next song" "mute M Cozy: mute music" "pet C Cozy: pet the cat"; do
    cmd=${spec%% *}; rest=${spec#* }; key=${rest%% *}; name=${rest#* }
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s %s\nNoDisplay=true\nX-KDE-GlobalAccel-CommandShortcut=true\n' \
        "$name" "$HOME/.local/bin/cozy" "$cmd" > "$apps/cozy-$cmd.desktop"
    kwriteconfig6 --file kglobalshortcutsrc --group services --group "cozy-$cmd.desktop" --key _launch "Meta+Alt+$key"
done

# 3. music from your own Minecraft install (skip with NO_MUSIC=1)
[ "${NO_MUSIC:-0}" = 1 ] || "$here/tools/fetch-music.sh" || echo "music skipped; run tools/fetch-music.sh <assets-dir> later"

# 4. turn it on: wallpaper on every screen (music only on the primary), koi pond on the lock screen
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    'desktops().forEach(d=>{d.wallpaperPlugin="com.fishyshu.cozyblocks"; d.currentConfigGroup=["Wallpaper","com.fishyshu.cozyblocks","General"]; d.writeConfig("Music", d.screen==0); d.reloadConfig()})'
kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin com.fishyshu.koipond
echo "done. log out and back in once for the hotkeys."
