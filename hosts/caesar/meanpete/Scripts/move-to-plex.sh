#!/usr/bin/env bash
#
# Ported from the old box (~meanpete/Scripts/move-to-plex.sh) on 2026-09-13.
# Changed in exactly one way: every `sudo` is gone. See hosts/caesar/meanpete/README.md
# and audit section 11 -- the root path was never needed, and it was a privesc.

# Move movie files (file OR folder OR drop directory) into Plex Movies using rsync.
#
# Features:
# - If given a FILE: process that one file.
# - If given a DIRECTORY: batch process all movie files found (maxdepth 2),
#   choosing largest-first each iteration (ignores *sample* and partial/temp files).
# - Renames to "Title (Year).ext" if a year can be parsed from filename.
# - Copies subtitles (.srt) from the movie's folder and Subs/ (maxdepth 2).
# - Detects torrent junk (.txt, .nfo, *_thumb*, images, Subs/) and prompts before deleting.
# - Runs entirely unprivileged. The NAS destinations are drwxrwsr-x group `media`
#   with the setgid bit, so a media member writes, creates dirs and deletes without
#   root. The old root path was working around a problem that did not exist, and the
#   wrapper granting it was an escalation -- see audit section 11.
# - Skips movies whose destination file already exists (idempotent-ish).
#
# Usage:
#   move-to-plex.sh /path/to/MovieFile.mkv
#   move-to-plex.sh /path/to/TorrentFolder
#   move-to-plex.sh /home/meanpete/incoming

set -euo pipefail

PLEX_DIR="/mnt/nas/PlexMedia/Movies"

if [[ -z "${1:-}" ]]; then
  echo "Usage: move-to-plex <file-or-directory>"
  exit 1
fi

TARGET="$1"
IS_FILE_INPUT=false

if [[ -d "$TARGET" ]]; then
  BASE_DIR="$TARGET"
elif [[ -f "$TARGET" ]]; then
  IS_FILE_INPUT=true
  BASE_DIR="$(dirname "$TARGET")"
else
  echo "Error: '$TARGET' is not a file or directory"
  exit 1
fi

# Normalize BASE_DIR (no trailing slash weirdness)
BASE_DIR="$(cd "$BASE_DIR" && pwd)"

echo "Working in source directory:"
echo "  $BASE_DIR"
echo

# Resolve single file to absolute path if needed
SINGLE_FILE=""
if [[ "$IS_FILE_INPUT" == true ]]; then
  SINGLE_FILE="$(cd "$BASE_DIR" && realpath "$(basename "$TARGET")")"
  if [[ ! -f "$SINGLE_FILE" ]]; then
    echo "Error: main video file not found: $SINGLE_FILE"
    exit 1
  fi
fi

is_video_file() {
  local p="$1"
  shopt -s nocasematch
  [[ "$p" =~ \.(mkv|mp4|m4v|avi|mov)$ ]] && \
  [[ ! "$p" =~ sample ]] && \
  [[ ! "$p" =~ \.(part|tmp)$ ]] && \
  [[ ! "$p" =~ uploading$ ]]
}

derive_dest_basename() {
  local main_video="$1"
  local main_basename ext name_no_ext year title_raw title dest_basename

  main_basename="$(basename "$main_video")"
  ext="${main_basename##*.}"
  name_no_ext="${main_basename%.*}"

  # first 4-digit year between 1900-2099
  year="$(echo "$name_no_ext" | grep -oE '(19[0-9]{2}|20[0-9]{2})' | head -n1 || true)"
  dest_basename="$main_basename"

  if [[ -n "$year" ]]; then
    # Title is everything before the year
    title_raw="$(echo "$name_no_ext" | sed -E "s/[[:space:]_]*$year.*$//")"
    # Replace dots/underscores with spaces, trim trailing spaces
    title="$(echo "$title_raw" | sed -E 's/[._]+/ /g' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    if [[ -n "$title" ]]; then
      dest_basename="${title} (${year}).${ext}"
    fi
  fi

  echo "$dest_basename"
}

process_one_movie() {
  local main_video="$1"
  local movie_dir dest_basename dest_path
  movie_dir="$(dirname "$main_video")"

  dest_basename="$(derive_dest_basename "$main_video")"
  dest_path="${PLEX_DIR}/${dest_basename}"

  echo "Detected main video file:"
  echo "  $main_video"
  echo
  echo "Plex destination:"
  echo "  $dest_path"
  echo

  # If destination exists, skip (prevents duplicates on rerun)
  if [[ -e "$dest_path" ]]; then
    echo "⚠️  Destination already exists; skipping:"
    echo "  $dest_path"
    echo
    return 0
  fi

  # -----------------------------
  #   FIND SUBTITLE FILES (.srt)
  # -----------------------------
  # Only within the movie's own folder (and one level down, e.g., Subs/)
  mapfile -t subs < <(
    find "$movie_dir" -maxdepth 2 -type f -iname '*.srt' -printf '%p\n' | sort
  )

  if ((${#subs[@]} > 0)); then
    echo "Found subtitle files to copy:"
    for s in "${subs[@]}"; do
      echo "  $s"
    done
  else
    echo "No .srt subtitles found."
  fi

  echo

  # -----------------------------
  #   RSYNC MAIN VIDEO TO PLEX
  # -----------------------------
  rsync -rlptDvh --chmod=D2775,F664 --progress --partial --inplace "$main_video" "$dest_path"
  local rsync_exit=$?

  if [[ $rsync_exit -ne 0 ]]; then
    echo
    echo "rsync error (code $rsync_exit). Source files NOT removed."
    exit 1
  fi

  echo
  echo "✔️  Main video transferred successfully."

  # Copy subtitles (if any) into the same Plex Movies directory.
  if ((${#subs[@]} > 0)); then
    echo
    echo "Copying subtitles to Plex Movies directory..."
    for s in "${subs[@]}"; do
      rsync -rlptDvh --chmod=D2775,F664 --inplace "$s" "$PLEX_DIR/"
    done
  fi

  # -----------------------------
  #   FIND JUNK / CLEANUP TARGETS
  # -----------------------------
  # Typical torrent artifacts in the movie folder:
  # - *.txt, *.nfo, *thumb*, images
  # - Subs/ directory
  shopt -s nullglob

  mapfile -t junk < <(
    find "$movie_dir" -maxdepth 1 \
      \( -type f \( -iname '*.txt' -o -iname '*.nfo' -o -iname '*thumb*' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
         -o -type d -iname 'subs' \) \
      -printf '%p\n' | sort
  )

  echo
  echo "Cleanup candidates in source directory:"
  echo "  Main video: $main_video"
  if ((${#subs[@]} > 0)); then
    echo "  Subtitles (copied already):"
    for s in "${subs[@]}"; do
      echo "    $s"
    done
  fi
  if ((${#junk[@]} > 0)); then
    echo "  Junk files & folders:"
    for j in "${junk[@]}"; do
      echo "    $j"
    done
  else
    echo "  (No junk files detected by pattern.)"
  fi

  echo
  read -r -p "Delete main video, listed subtitles, and junk from source? [y/N] " answer

  case "$answer" in
    y|Y|yes|YES)
      rm -f -- "$main_video"

      if ((${#subs[@]} > 0)); then
        rm -f -- "${subs[@]}"
      fi

      if ((${#junk[@]} > 0)); then
        for j in "${junk[@]}"; do
          if [[ -d "$j" ]]; then
            rm -rf -- "$j"
          else
            rm -f -- "$j"
          fi
        done
      fi

      echo "🧹 Source movie, subs, and junk removed."

      # If the movie folder is now empty, try removing it (torrent folder hygiene)
      if rmdir "$movie_dir" 2>/dev/null; then
        echo "📁 Folder '$movie_dir' was empty and has been removed."
      fi
      ;;
    *)
      echo "❗ Leaving source directory and files in place."
      ;;
  esac
}

# -----------------------------
#   MAIN DISPATCH
# -----------------------------
if [[ "$IS_FILE_INPUT" == true ]]; then
  process_one_movie "$SINGLE_FILE"
  exit 0
fi

# Directory mode:
# Find all eligible video files up to 2 levels deep, then ingest largest-first in a loop.
while true; do
  mapfile -t size_path < <(
    find "$BASE_DIR" -maxdepth 2 -type f \
      \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.avi' -o -iname '*.mov' \) \
      ! -iname '*sample*' \
      ! -iname '*.part' ! -iname '*.tmp' ! -iname '*.uploading' \
      -printf '%s\t%p\n' | sort -nr
  )

  if ((${#size_path[@]} == 0)); then
    echo "No more movie files found in $BASE_DIR."
    break
  fi

  main_video_line="${size_path[0]}"
  main_video="${main_video_line#*$'\t'}"

  if [[ ! -f "$main_video" ]]; then
    echo "Internal error: detected main video path is not a file: $main_video"
    exit 1
  fi

  process_one_movie "$main_video"

  echo
  echo "----------------------------------------"
  echo
done

# If the user passed a directory that becomes empty, try removing it.
# (Safe: only removes if empty.)
if [[ -d "$TARGET" ]]; then
  if rmdir "$TARGET" 2>/dev/null; then
    echo "📁 Folder '$TARGET' was empty and has been removed."
  fi
fi
