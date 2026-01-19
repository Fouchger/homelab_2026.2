# Secrets strategy

This project is designed so **no sensitive values are committed to Git**.

## Overview

We use a two-layer approach:

1. **Vaultwarden** stores the source secrets.
2. **SOPS** encrypts any files that must exist on disk, but we decrypt them only at runtime.

Ansible consumes secrets via runtime injection so nothing is written into the repo working tree.

## Recommended toolchain

- **rbw**: lightweight Bitwarden-compatible CLI that works with Vaultwarden
- **age**: secret key format used by SOPS
- **sops**: encrypts YAML/JSON

## Vaultwarden conventions

Create an item named:

- `homelab_2026_2_age_key`

Store your **AGE private key** in the item *password* field.

## Running Ansible with secrets

By default, `scripts/core/ansible.sh` sources `scripts/secrets/runtime.sh`.

Runtime behaviour:

- Tries to fetch `SOPS_AGE_KEY` from Vaultwarden via `rbw`.
- If `ansible/group_vars/all/secrets.sops.yaml` is SOPS encrypted, it decrypts it into a temporary file.
- Adds `-e @/tmp/.../secrets.yaml` to the Ansible run.

## First-time setup

On admin01:

1. Install tools
   - `sudo apt-get update`
   - `sudo apt-get install -y sops age rbw`

2. Configure rbw
   - `rbw config set base_url http://<vaultwarden-hostname-or-ip>`
   - `rbw login`

3. Create an AGE key
   - `age-keygen -o age.key`
   - Store the key contents in Vaultwarden item `homelab_2026_2_age_key`
   - Do not leave the plain key file on shared systems

## secrets.sops.yaml file

Path:

- `ansible/group_vars/all/secrets.sops.yaml`

You can keep this file plain while bootstrapping. When ready, encrypt it:

- `sops --encrypt --age <YOUR_AGE_PUBLIC_KEY> --in-place ansible/group_vars/all/secrets.sops.yaml`

## Guardrails

This repo includes:

- **detect-secrets** + `.secrets.baseline`
- **gitleaks**

Run:

- `pre-commit install`
- `pre-commit run -a`
