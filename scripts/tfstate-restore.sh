#!/usr/bin/env bash
# Restore the Terraform local state (staging) from an age-encrypted backup.
#
# Required environment:
#   AGE_IDENTITY_FILE   Path to your age PRIVATE key (kept offline; copy it
#                       temporarily to a safe path, delete it afterwards).
# Optional:
#   TFSTATE_DIR         State directory (default: terraform/environments/staging)
#
# Usage: scripts/tfstate-restore.sh [--force] /path/to/tfstate-staging-<ts>.tar.gz.age
#   Without --force the script refuses to touch an existing terraform.tfstate.
#   With --force the existing state is first moved to terraform.tfstate.pre-restore-<ts>.
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

force=0
if [[ "${1:-}" == "--force" ]]; then force=1; shift; fi
backup="${1:-}"
[[ -n "$backup" && -f "$backup" ]] || die "Usage: $0 [--force] <backup.tar.gz.age>"
[[ -n "${AGE_IDENTITY_FILE:-}" && -r "$AGE_IDENTITY_FILE" ]] || die "Set AGE_IDENTITY_FILE to your age private key file."
command -v age >/dev/null || die "'age' not found."

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
state_dir="${TFSTATE_DIR:-$repo_root/terraform/environments/staging}"
[[ -d "$state_dir" ]] || die "State directory $state_dir does not exist."

if [[ -f "$backup.sha256" ]]; then
  (cd "$(dirname "$backup")" && sha256sum --status -c "$(basename "$backup").sha256") || die "Checksum mismatch: backup is corrupt or modified."
  echo "Checksum OK."
fi

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

age -d -i "$AGE_IDENTITY_FILE" -o "$work/state.tar.gz" "$backup" || die "Decryption failed (wrong key?)."

# Only the two expected plain file names are allowed in the archive.
while IFS= read -r member; do
  case "$member" in
    terraform.tfstate | terraform.tfstate.backup) ;;
    *) die "Unexpected archive member '$member'; refusing to extract." ;;
  esac
done < <(tar -tzf "$work/state.tar.gz")

mkdir "$work/x"
tar -xzf "$work/state.tar.gz" -C "$work/x" --no-same-owner
[[ -f "$work/x/terraform.tfstate" ]] || die "Archive has no terraform.tfstate."
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "version" in d and "serial" in d' "$work/x/terraform.tfstate" \
  || die "Restored file is not a valid Terraform state."

if [[ -f "$state_dir/terraform.tfstate" ]]; then
  [[ "$force" == 1 ]] || die "$state_dir/terraform.tfstate exists. Re-run with --force to replace it (the old file is kept)."
  mv -- "$state_dir/terraform.tfstate" "$state_dir/terraform.tfstate.pre-restore-$(date -u +%Y%m%dT%H%M%SZ)"
fi

install -m 600 "$work/x/terraform.tfstate" "$state_dir/terraform.tfstate"
[[ -f "$work/x/terraform.tfstate.backup" ]] && install -m 600 "$work/x/terraform.tfstate.backup" "$state_dir/terraform.tfstate.backup"

echo "Restored state into $state_dir."
echo "Next: cd $state_dir && terraform init && terraform plan   (review: it should show no unexpected changes)"
