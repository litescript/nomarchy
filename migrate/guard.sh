# guard.sh -- the migration's path gate (docs/cutover/03 §9, step 2 and §8 H), written and
# rehearsed BEFORE the migration tool itself, so the tool is built on a gate that has
# already refused things. Sourced after common/storage/spec.sh has loaded the host's spec.
#
#   migrate_path_ok source|dest <path>    0 if allowed; otherwise prints why, returns 1
#
# The topology it enforces is §9's, and only that one:
#   source  on the running rescue install's root (rescue.root-uuid) -- SATA, where the old
#           home lives. Never anything else.
#   dest    on the new host's btrfs (btrfs.uuid), opened and mounted on the rescue system.
#   both    never on a keep.untouched filesystem (caesar's sda3), never a device node.
#
# A path is judged by the filesystem that holds it, found from its nearest existing
# ancestor (a destination may not exist yet), with symlinks resolved -- so a link that
# leads onto sda3 is refused as sda3. The copy itself must then run with rsync -x
# (--one-file-system): the gate judges each tree's ROOT, and -x keeps the copy from
# crossing into another filesystem mounted somewhere inside it.
migrate_path_ok() {
  local role=$1 path=$2 p uuid
  case $role in source|dest) ;; *) echo "guard: role must be source or dest, not '$role'"; return 1 ;; esac
  [[ $path == /* ]] || { echo "REFUSED $role $path: not an absolute path"; return 1; }
  [[ $path != /dev/* ]] || { echo "REFUSED $role $path: a device node -- the migration copies files, never devices"; return 1; }
  p=$path
  while [[ ! -e $p ]]; do p=$(dirname "$p"); done
  p=$(readlink -f "$p")
  uuid=$(findmnt -rn -o UUID -T "$p" 2>/dev/null)
  [[ -n $uuid ]] || { echo "REFUSED $role $path: cannot tell which filesystem holds it"; return 1; }
  if [[ " ${SPEC[keep.untouched]:-} " == *" $uuid "* ]]; then
    echo "REFUSED $role $path: on a keep-untouched filesystem ($uuid) -- never read, never written"; return 1
  fi
  if [[ $role == source && $uuid != "${SPEC[rescue.root-uuid]:-}" ]]; then
    echo "REFUSED source $path: not on the rescue install's root (${SPEC[rescue.root-uuid]:-undeclared}), but on $uuid"; return 1
  fi
  if [[ $role == dest && $uuid != "${SPEC[btrfs.uuid]}" ]]; then
    echo "REFUSED dest $path: not on the new system's btrfs (${SPEC[btrfs.uuid]}), but on $uuid"; return 1
  fi
  echo "ok      $role $path  (filesystem $uuid)"
}
