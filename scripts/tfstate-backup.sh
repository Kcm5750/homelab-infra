#!/usr/bin/env bash
# Encrypted, off-WSL backup of the Terraform local state (staging).
#
# The state file can contain sensitive values. It is encrypted with `age`
# using a PUBLIC key, so this script needs no secret. Only the matching
# private key (stored offline, NOT in this repo or WSL) can decrypt it.
#
# Required environment:
#   TFSTATE_BACKUP_DEST            Destination directory OUTSIDE this WSL install,
#                                  e.g. /mnt/c/Users/<you>/Backups/homelab-tfstate
#   TFSTATE_AGE_RECIPIENT          age public key (age1...)        } one of
#   TFSTATE_AGE_RECIPIENTS_FILE    file with one public key per line } these
# Optional:
#   TFSTATE_DIR                    State directory (default: terraform/environments/staging)
#   TFSTATE_BACKUP_KEEP            Backups to keep (default: 30)
#   TFSTATE_ALLOW_ANY_DEST=1       Skip the "must be a Windows/network mount" check
#
# Usage: scripts/tfstate-backup.sh
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
state_dir="${TFSTATE_DIR:-$repo_root/terraform/environments/staging}"
keep="${TFSTATE_BACKUP_KEEP:-30}"

command -v age >/dev/null || die "'age' not found. Install it (e.g. 'sudo apt install age')."
[[ "$keep" =~ ^[0-9]+$ && "$keep" -ge 1 ]] || die "TFSTATE_BACKUP_KEEP must be a positive integer."
[[ -n "${TFSTATE_BACKUP_DEST:-}" ]] || die "TFSTATE_BACKUP_DEST is not set."

recipient_args=()
if [[ -n "${TFSTATE_AGE_RECIPIENTS_FILE:-}" ]]; then
  [[ -r "$TFSTATE_AGE_RECIPIENTS_FILE" ]] || die "Cannot read TFSTATE_AGE_RECIPIENTS_FILE."
  recipient_args=(-R "$TFSTATE_AGE_RECIPIENTS_FILE")
elif [[ -n "${TFSTATE_AGE_RECIPIENT:-}" ]]; then
  [[ "$TFSTATE_AGE_RECIPIENT" == age1* ]] || die "TFSTATE_AGE_RECIPIENT must be an age PUBLIC key (age1...)."
  recipient_args=(-r "$TFSTATE_AGE_RECIPIENT")
else
  die "Set TFSTATE_AGE_RECIPIENT or TFSTATE_AGE_RECIPIENTS_FILE."
fi

[[ -f "$state_dir/terraform.tfstate" ]] || die "No state file at $state_dir/terraform.tfstate (nothing to back up yet)."

# --- Destination must be outside the WSL install and the repo ---------------
dest="$(realpath -m -- "$TFSTATE_BACKUP_DEST")"
case "$dest/" in
  "$repo_root"/*) die "Destination is inside the repository." ;;
esac
if [[ "${TFSTATE_ALLOW_ANY_DEST:-0}" != "1" ]]; then
  [[ "$dest" == /mnt/* && "$dest" != /mnt/wsl* ]] || die "Destination must be under a Windows/network mount (/mnt/<drive>/...). Set TFSTATE_ALLOW_ANY_DEST=1 to override."
  probe="$dest"
  while [[ ! -e "$probe" ]]; do probe="$(dirname "$probe")"; done
  fstype="$(findmnt -n -o FSTYPE -T "$probe" 2>/dev/null || true)"
  case "$fstype" in
    9p | drvfs | cifs | smb3 | nfs | nfs4 | fuseblk | fuse.*) ;;
    *) die "Destination is on filesystem '${fstype:-unknown}', which looks local to WSL. Use a Windows drive or network share." ;;
  esac
fi

mkdir -p -- "$dest"
[[ -w "$dest" ]] || die "Destination is not writable."

# --- Build, encrypt, copy, verify ------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

files=(terraform.tfstate)
[[ -f "$state_dir/terraform.tfstate.backup" ]] && files+=(terraform.tfstate.backup)

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
name="tfstate-staging-${stamp}.tar.gz.age"

tar -czf - -C "$state_dir" -- "${files[@]}" | age "${recipient_args[@]}" -o "$work/$name"

head -c 21 "$work/$name" | grep -q '^age-encryption.org/' || die "Encrypted output does not look like an age file."
sum="$(sha256sum "$work/$name" | cut -d' ' -f1)"

cp -- "$work/$name" "$dest/.$name.partial"
copied="$(sha256sum "$dest/.$name.partial" | cut -d' ' -f1)"
[[ "$sum" == "$copied" ]] || { rm -f -- "$dest/.$name.partial"; die "Checksum mismatch after copy; backup discarded."; }
mv -- "$dest/.$name.partial" "$dest/$name"
printf '%s  %s\n' "$sum" "$name" >"$dest/$name.sha256"

# --- Retention ---------------------------------------------------------------
mapfile -t old < <(find "$dest" -maxdepth 1 -name 'tfstate-staging-*.tar.gz.age' -printf '%f\n' | sort -r | tail -n +"$((keep + 1))")
for f in "${old[@]}"; do
  rm -f -- "$dest/$f" "$dest/$f.sha256"
done

echo "OK: wrote $dest/$name (sha256 ${sum:0:12}…); kept newest $keep."
