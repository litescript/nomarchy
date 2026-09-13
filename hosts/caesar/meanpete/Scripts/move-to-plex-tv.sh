#!/usr/bin/env bash
#
# Ported from the old box (~meanpete/Scripts/move-to-plex-tv.sh) on 2026-09-13.
# Changed in exactly one way: every `sudo` is gone. See hosts/caesar/meanpete/README.md
# and audit section 11 -- the root path was never needed, and it was a privesc.

# Move TV episodes (from a file OR torrent folder) into Plex TV using rsync.
# - Detects all main video files (ignores *sample*)
# - Parses SxxEyy to derive Show Name and Season
# - Creates: /mnt/nas/PlexMedia/TV/<Show Name>/Season XX/
# - Keeps original episode filenames (which are already Plex-friendly)
# - Finds matching .srt subs per episode and copies them next to the video
# - Cleans junk (.txt, .nfo, *_thumb*, jpg/png, Subs/) after confirmation
# - Runs entirely unprivileged; see the note in move-to-plex.sh. `install -d -m 2775`
#   creates the Show/Season directories on the NAS as a media member, and the setgid
#   bit carries the group down. Verified against the live NAS before this port.
#
# Usage:
#   move-to-plex-tv /path/to/TorrentFolder
#   move-to-plex-tv /path/to/Agatha.All.Along.S01E01....mkv

set -euo pipefail

PLEX_TV_DIR="/mnt/nas/PlexMedia/TV"

if [[ -z "${1:-}" ]]; then
    echo "Usage: move-to-plex-tv <file-or-directory>"
    exit 1
fi

TARGET="$1"

if [[ -d "$TARGET" ]]; then
    BASE_DIR="$TARGET"
elif [[ -f "$TARGET" ]]; then
    BASE_DIR="$(dirname "$TARGET")"
else
    echo "Error: '$TARGET' is not a file or directory"
    exit 1
fi

BASE_DIR="$(cd "$BASE_DIR" && pwd)"

echo "Working in source directory:"
echo "  $BASE_DIR"
echo

# -----------------------------
#   FIND ALL EPISODE FILES
# -----------------------------
mapfile -t VIDEO_FILES < <(
    find "$BASE_DIR" -maxdepth 2 -type f \
        \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.avi' -o -iname '*.mov' \) \
        ! -iname '*sample*' \
        ! -iname '*.part' ! -iname '*.tmp' ! -iname '*.uploading' \
        -printf '%p\n' | sort
)

if ((${#VIDEO_FILES[@]} == 0)); then
    echo "Error: No TV episode video files found in $BASE_DIR"
    exit 1
fi

echo "Detected episode files:"
for v in "${VIDEO_FILES[@]}"; do
    echo "  $v"
done
echo

# -----------------------------
#   DERIVE SHOW TITLE FROM 1ST
# -----------------------------
FIRST_VIDEO="${VIDEO_FILES[0]}"
FIRST_BASENAME="$(basename "$FIRST_VIDEO")"
FIRST_NO_EXT="${FIRST_BASENAME%.*}"
SHOW_TITLE="Unknown Show"

# Extract show name using SxxEyy pattern
if [[ "$FIRST_NO_EXT" =~ ([sS][0-9]{2}[eE][0-9]{2}) ]]; then
    MATCH="${BASH_REMATCH[1]}"
    RAW_TITLE="${FIRST_NO_EXT%$MATCH*}"
    # Replace dots/underscores with spaces, trim spaces
    CLEAN_TITLE="$(echo "$RAW_TITLE" | sed -E 's/[._]+/ /g' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    if [[ -n "$CLEAN_TITLE" ]]; then
        SHOW_TITLE="$CLEAN_TITLE"
    fi
else
    # Fallback: use folder name as show title
    RAW_TITLE="$(basename "$BASE_DIR")"
    CLEAN_TITLE="$(echo "$RAW_TITLE" | sed -E 's/[._]+/ /g' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    SHOW_TITLE="$CLEAN_TITLE"
fi

# Reuse an existing show folder that differs only in capitalisation. Release
# groups are inconsistent ("FROM.S04E01" vs "From.S04E02") and the title is
# derived from the filename, so without this a second folder appears beside the
# first and Plex lists the show twice. Exact match wins; otherwise the
# case-insensitive match holding the most episodes wins, so new files join the
# established folder rather than starting a rival one.
resolve_show_dir() {
    local want="$1" root="$2" d name best="" best_n=-1 n
    [[ -d "$root/$want" ]] && { printf '%s' "$want"; return; }
    shopt -s nullglob
    for d in "$root"/*/; do
        d="${d%/}"; name="${d##*/}"
        [[ "${name,,}" != "${want,,}" ]] && continue
        n=$(find "$d" -type f \( -iname '*.mkv' -o -iname '*.mp4' -o \
                                 -iname '*.avi' -o -iname '*.m4v' \) 2>/dev/null | wc -l)
        (( n > best_n )) && { best_n=$n; best="$name"; }
    done
    shopt -u nullglob
    printf '%s' "${best:-$want}"
}

SHOW_TITLE="$(resolve_show_dir "$SHOW_TITLE" "$PLEX_TV_DIR")"

echo "Derived show title:"
echo "  $SHOW_TITLE"
echo

# For cleanup, track all copied videos and subs
COPIED_VIDEOS=()
COPIED_SUBS=()

# -----------------------------
#   COPY EACH EPISODE
# -----------------------------
for VIDEO in "${VIDEO_FILES[@]}"; do
    BASENAME="$(basename "$VIDEO")"
    NO_EXT="${BASENAME%.*}"

    SEASON_NUM="01"

    if [[ "$NO_EXT" =~ [sS]([0-9]{2})[eE]([0-9]{2}) ]]; then
        SEASON_NUM="${BASH_REMATCH[1]}"
    fi

    SEASON_DIR="Season ${SEASON_NUM}"
    DEST_DIR="${PLEX_TV_DIR}/${SHOW_TITLE}/${SEASON_DIR}"

    echo "Episode:"
    echo "  Source: $VIDEO"
    echo "  Season: $SEASON_NUM"
    echo "  Show:   $SHOW_TITLE"
    echo "  Dest:   $DEST_DIR/$BASENAME"
    echo

    # Ensure destination directory exists
    install -d -m 2775 "$DEST_DIR"

    # Copy video
    rsync -rlptDvh --chmod=D2775,F664 --progress --partial --inplace "$VIDEO" "${DEST_DIR}/${BASENAME}"
    COPIED_VIDEOS+=( "$VIDEO" )

    # -------------------------
    #   FIND MATCHING SUBS
    # -------------------------
    # Look for .srt that start with the same base name (no ext),
    # in BASE_DIR or one level down (e.g., Subs/)
    mapfile -t MATCHING_SUBS < <(
        find "$BASE_DIR" -maxdepth 2 -type f -iname "${NO_EXT}"'*.srt'
    )

    if ((${#MATCHING_SUBS[@]} > 0)); then
        echo "  Found matching subtitles:"
        for s in "${MATCHING_SUBS[@]}"; do
            echo "    $s"
        done

        for s in "${MATCHING_SUBS[@]}"; do
            SUB_BASENAME="$(basename "$s")"
            rsync -rlptDvh --chmod=D2775,F664 --inplace "$s" "${DEST_DIR}/${SUB_BASENAME}"
            COPIED_SUBS+=( "$s" )
        done
    else
        echo "  No matching .srt subtitles found for this episode."
    fi

    echo
done

echo "✔️  All episodes processed and copied into Plex TV structure."
echo

# -----------------------------
#   FIND JUNK / CLEANUP LIST
# -----------------------------
shopt -s nullglob

# Unique lists (avoid duplicates)
declare -A SEEN

# JUNK: txt, nfo, thumb, images, Subs dir
mapfile -t JUNK < <(
    find "$BASE_DIR" -maxdepth 2 \
        \( -type f \( -iname '*.txt' -o -iname '*.nfo' -o -iname '*thumb*' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
           -o -type d -iname 'subs' \)
)

echo "Cleanup candidates from source:"
echo "  Episodes:"
for v in "${COPIED_VIDEOS[@]}"; do
    echo "    $v"
done

if ((${#COPIED_SUBS[@]} > 0)); then
    echo "  Subtitles (copied to Plex TV):"
    for s in "${COPIED_SUBS[@]}"; do
        echo "    $s"
    done
fi

if ((${#JUNK[@]} > 0)); then
    echo "  Junk files & folders:"
    for j in "${JUNK[@]}"; do
        echo "    $j"
    done
else
    echo "  Junk files & folders: (none detected by pattern)"
fi

echo
read -r -p "Delete episodes, listed subs, and junk from source? [y/N] " ANSWER

case "$ANSWER" in
    y|Y|yes|YES)
        # Delete episodes
        for v in "${COPIED_VIDEOS[@]}"; do
            rm -f -- "$v"
        done

        # Delete subs
        if ((${#COPIED_SUBS[@]} > 0)); then
            rm -f -- "${COPIED_SUBS[@]}"
        fi

        # Delete junk
        if ((${#JUNK[@]} > 0)); then
            for j in "${JUNK[@]}"; do
                if [[ -d "$j" ]]; then
                    rm -rf -- "$j"
                else
                    rm -f -- "$j"
                fi
            done
        fi

        echo "🧹 Source episodes, subs, and junk removed."

        # Try to remove torrent folder if TARGET was a directory
        if [[ -d "$BASE_DIR" && -d "$TARGET" && "$BASE_DIR" == "$(cd "$TARGET" && pwd)" ]]; then
            if rmdir "$BASE_DIR" 2>/dev/null; then
                echo "📁 Torrent folder '$BASE_DIR' was empty and has been removed."
            else
                echo "📁 Torrent folder '$BASE_DIR' still has content; leaving it in place."
            fi
        fi
        ;;
    *)
        echo "❗ Leaving source files and folder in place."
        ;;
esac
