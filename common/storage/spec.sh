# spec.sh -- the ONE parser for hosts/<host>/storage/layout, and the ONE target-identity
# check. Sourced by provision/provision (destructive) and common/scripts/nomarchy
# (read-only); neither encodes the layout itself, so the two cannot drift apart.
#
#   spec_load <file>        fills SPEC[key], SPEC_PARTS[], SPEC_SUBVOLS[], SPEC_NESTED[]
#   spec_identify           resolves disk.by-id; sets DISK_DEV DISK_MODEL DISK_SERIAL DISK_BYTES
#   spec_identity_ok        spec_identify, then all of by-id, model, serial and size must match
#   spec_part <role>        "num role size type partlabel partuuid" for that role
#   spec_part_dev <num>     the partition device of DISK_DEV (nvme0n1 -> nvme0n1p1, sda -> sda1)
#   spec_esp_uuid           esp.volid as blkid shows it (F7EDD893 -> F7ED-D893)

declare -gA SPEC=()
SPEC_PARTS=() SPEC_SUBVOLS=() SPEC_NESTED=()
DISK_DEV='' DISK_MODEL='' DISK_SERIAL='' DISK_BYTES=''

spec_load() {
  local f=$1 line key val
  [[ -f $f ]] || { echo "spec: no such file: $f" >&2; return 1; }
  SPEC=() SPEC_PARTS=() SPEC_SUBVOLS=() SPEC_NESTED=()
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    # A trailing "  # comment" is stripped: a value is never compared with its comment
    # attached. The second release-candidate rehearsal wrote one after rescue.root-uuid, and
    # the never gate's rescue-root check silently matched nothing. No value here contains
    # whitespace followed by '#'.
    line=$(sed 's/[[:space:]]\{1,\}#.*$//' <<<"$line")
    key=${line%%[[:space:]]*}
    val=${line#"$key"}; val=${val#"${val%%[![:space:]]*}"}; val=${val%"${val##*[![:space:]]}"}
    case $key in
      part)   SPEC_PARTS+=("$val") ;;
      subvol) SPEC_SUBVOLS+=("$val") ;;
      nested) SPEC_NESTED+=("$val") ;;
      *)      SPEC[$key]=$val ;;
    esac
  done < "$f"
  # ${key} references, expanded once; the spec has no chains.
  local k v ref pat
  for k in "${!SPEC[@]}"; do
    v=${SPEC[$k]}
    while [[ $v =~ \$\{([A-Za-z0-9._-]+)\} ]]; do
      ref=${BASH_REMATCH[1]}
      [[ -n ${SPEC[$ref]+x} ]] || { echo "spec: $k refers to unknown \${$ref}" >&2; return 1; }
      pat="\${$ref}"; v=${v//"$pat"/${SPEC[$ref]}}
    done
    SPEC[$k]=$v
  done
  local req
  for req in host disk.by-id disk.model disk.serial disk.bytes gpt.uuid luks.uuid luks.mapper \
             btrfs.uuid btrfs.options esp.volid esp.mount boot.cmdline boot.hooks pacstrap; do
    [[ -n ${SPEC[$req]:-} ]] || { echo "spec: $f is missing '$req'" >&2; return 1; }
  done
  ((${#SPEC_PARTS[@]} > 0 && ${#SPEC_SUBVOLS[@]} > 0)) || { echo "spec: $f declares no partitions or no subvolumes" >&2; return 1; }
}

spec_identify() {
  local link=/dev/disk/by-id/${SPEC[disk.by-id]} name
  DISK_DEV='' DISK_MODEL='' DISK_SERIAL='' DISK_BYTES=''
  [[ -e $link ]] || return 1
  DISK_DEV=$(readlink -f "$link"); name=${DISK_DEV##*/}
  # A by-id link to a partition, not a whole disk, is refused outright.
  [[ -d /sys/block/$name ]] || { DISK_DEV=''; return 1; }
  # sysfs pads model and serial with spaces; lsblk reads the same udev data. Trim both ends.
  DISK_MODEL=$(lsblk -dn -o MODEL "$DISK_DEV" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  DISK_SERIAL=$(lsblk -dn -o SERIAL "$DISK_DEV" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # /sys/block/*/size is always in 512-byte units, whatever the logical block size.
  DISK_BYTES=$(( $(cat "/sys/block/$name/size") * 512 ))
}

spec_identity_ok() {
  spec_identify || return 1
  [[ $DISK_MODEL == "${SPEC[disk.model]}" && $DISK_SERIAL == "${SPEC[disk.serial]}" \
     && $DISK_BYTES == "${SPEC[disk.bytes]}" ]]
}

spec_part() {
  local p
  for p in "${SPEC_PARTS[@]}"; do
    read -r _ role _ <<<"$p"
    [[ $role == "$1" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

spec_part_dev() {
  [[ $DISK_DEV =~ [0-9]$ ]] && printf '%sp%s\n' "$DISK_DEV" "$1" || printf '%s%s\n' "$DISK_DEV" "$1"
}

spec_esp_uuid() { local v=${SPEC[esp.volid]}; printf '%s-%s\n' "${v:0:4}" "${v:4:4}"; }
