#!/bin/sh
# fetch-music.sh [assets-dir] [dest]
# Copies the Minecraft soundtrack out of YOUR OWN launcher's asset store into dest
# (default ~/Music/minecraft). The music is Mojang's, so the repo never ships it.
# Nether/End tracks go to dest/spooky/, which the wallpaper ignores (too spooky for a cat).
set -eu
dest="${2:-$HOME/Music/minecraft}"
assets="${1:-}"
if [ -z "$assets" ]; then
    for d in "$HOME/.minecraft/assets" "$HOME/.local/share/PrismLauncher/assets" \
             "$HOME/.local/share/atlauncher/assets" "$HOME/.local/share/multimc/assets"; do
        [ -d "$d/indexes" ] && assets="$d" && break
    done
fi
[ -n "$assets" ] && [ -d "$assets/indexes" ] || { echo "no Minecraft assets found; pass the assets dir (the one with indexes/ and objects/)" >&2; exit 1; }
command -v jq >/dev/null || { echo "needs jq" >&2; exit 1; }

# the index with the most music entries = the newest soundtrack you have
best=""; most=0
for f in "$assets"/indexes/*.json; do
    n=$(jq '[.objects|keys[]|select(startswith("minecraft/sounds/music/"))]|length' "$f")
    [ "$n" -ge "$most" ] && most=$n && best=$f
done
[ "$most" -gt 0 ] || { echo "no music in $assets/indexes" >&2; exit 1; }

mkdir -p "$dest/spooky"
copied=0; missing=0
jq -r '.objects|to_entries[]|select(.key|startswith("minecraft/sounds/music/"))|"\(.key) \(.value.hash)"' "$best" |
while read -r key hash; do
    name=$(echo "${key#minecraft/sounds/music/}" | tr / _)
    case "$name" in game_end_*|game_nether_*) out="$dest/spooky/$name" ;; *) out="$dest/$name" ;; esac
    src="$assets/objects/$(echo "$hash" | cut -c1-2)/$hash"
    if [ -f "$src" ]; then cp -n "$src" "$out"; else echo "missing (launch that MC version once): $key" >&2; fi
done
echo "$(ls "$dest"/*.ogg 2>/dev/null | wc -l) tracks in $dest (+ $(ls "$dest"/spooky/*.ogg 2>/dev/null | wc -l) spooky) from $(basename "$best")"
