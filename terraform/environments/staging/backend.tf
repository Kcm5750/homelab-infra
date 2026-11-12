# State backend: local file, deliberately.
#
# The state file (terraform.tfstate) is git-ignored and can contain sensitive
# values, so it is NEVER committed. Protection is an encrypted off-WSL backup:
#   scripts/tfstate-backup.sh   (age-encrypted copy to a Windows/NAS path)
#   scripts/tfstate-restore.sh  (restore + procedure in terraform/README.md)
#
# Alternatives (S3-compatible/MinIO with locking, HCP Terraform) are discussed
# in terraform/README.md. Switching later is: edit this block, then
# `terraform init -migrate-state`.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
