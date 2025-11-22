# Fix Terraform Provider Checksum Issues

The `.terraform.lock.hcl` file contains checksums that don't match your platform. To fix this:

## Option 1: Quick Fix (Recommended)
```bash
# Remove the lock file and let Terraform regenerate it
rm .terraform.lock.hcl
rm -rf .terraform
terraform init
```

## Option 2: Use the script
```bash
chmod +x scripts/fix-providers.sh
./scripts/fix-providers.sh
```

## Option 3: Upgrade providers
If you want to use the latest versions of providers, you can run:
```bash
rm .terraform.lock.hcl
terraform init -upgrade
```

## Why this happens
The lock file was created with checksums for a specific platform. When you run Terraform on a different OS or architecture (e.g., Intel Mac vs Apple Silicon Mac, or Mac vs Linux), the checksums don't match.

## Best Practice
After fixing, you can generate a multi-platform lock file:
```bash
terraform providers lock \
  -platform=darwin_amd64 \
  -platform=darwin_arm64 \
  -platform=linux_amd64
```

This ensures the lock file works across different platforms.