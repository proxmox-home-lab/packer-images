# packer-images — Proxmox VM Image Templates

## Purpose

Packer templates for building golden VM images on a Proxmox hypervisor. Images are
built once, stored in Proxmox as templates, and cloned when provisioning new VMs.
This eliminates per-VM install time and ensures a consistent, auditable base for
every machine in the home lab.

Initial target: OPNSense firewall image (hub-and-spoke network model).

---

## Architecture

```
packer-images/
│
└── <os>-<version>/         One directory per image
        ├── <image>.pkr.hcl         Build definition (source + build blocks)
        ├── variables.pkr.hcl       Variable declarations
        ├── <image>.auto.pkrvars.hcl  Non-secret variable values (committed)
        └── README.md               What this image is, how to build it
```

**Build flow:**
```
packer build ./<image>/
        │
        ├── ISO download / existing VM clone
        │
        ├── Boot command / HTTP preseed
        │
        ├── Provisioners (shell scripts, Ansible)
        │
        └── Proxmox template snapshot
                │
                └── Used by VM provisioning (future Terraform/Tofu modules)
```

**Secret injection:** Proxmox API credentials and any image passwords come from Vault
via `vault-helper.sh` — they are never stored in committed variable files.

---

## Directory Structure

```
packer-images/
├── .gitignore                  # Excludes .packer_cache/, output-*/, *.secret.pkrvars.hcl
└── (templates — not yet implemented)
```

> **Status:** Early stage. No templates have been implemented yet.
> The structure and conventions below define how new templates should be added.

---

## Adding a New Image

1. Create a directory named `<os>-<version>/` (e.g., `opnsense-25.1/`).

2. Create the build file `<os>.pkr.hcl` using HCL2 format. Minimum structure:
   ```hcl
   packer {
     required_version = ">= 1.10"
     required_plugins {
       proxmox = {
         version = ">= 1.1.0"
         source  = "github.com/hashicorp/proxmox"
       }
     }
   }

   source "proxmox-iso" "<name>" {
     proxmox_url              = var.proxmox_url
     username                 = var.proxmox_username
     token                    = var.proxmox_token
     node                     = var.proxmox_node
     insecure_skip_tls_verify = false
     # ... image-specific settings
   }

   build {
     sources = ["source.proxmox-iso.<name>"]
     # provisioners here
   }
   ```

3. Create `variables.pkr.hcl` with all variable declarations (type + description).

4. Create `<os>.auto.pkrvars.hcl` for non-secret values only (committed to git).

5. Create a `README.md` describing: what the image is, manual build steps, expected output.

---

## Commands Reference

| Command | Context |
|---------|---------|
| `packer init ./<image>/` | Download required Packer plugins |
| `packer validate ./<image>/` | Validate HCL syntax and variable completeness |
| `packer fmt -recursive .` | Format all `.pkr.hcl` files |
| `packer build ./<image>/` | Build the image (requires Vault secrets in env) |
| `packer build -var-file=override.pkrvars.hcl ./<image>/` | Build with additional variable overrides |

**Before building locally:**
```bash
# Load Proxmox + image credentials from Vault
export VAULT_ADDR="https://vault.sergioaten.cloud"
export VAULT_CLIENT_ID="<role-id>"
export VAULT_SECRET_ID="<secret-id>"
source /path/to/vault-helper.sh

packer init ./opnsense-25.1/
packer build ./opnsense-25.1/
```

---

## Conventions

**Format:**
- Use HCL2 (`.pkr.hcl`) exclusively. Do not use JSON-based Packer templates.
- One directory per image. Do not share `.pkr.hcl` files across images.

**Naming:**
- Directory: `<os>-<version>/` — e.g., `opnsense-25.1`, `debian-12`, `ubuntu-24.04`.
- Build file: `<os>.pkr.hcl` — e.g., `opnsense.pkr.hcl`.
- Variables file: `variables.pkr.hcl` (declarations) + `<os>.auto.pkrvars.hcl` (values).

**Secrets:**
- Never commit credentials, tokens, or passwords in any `.pkrvars.hcl` file.
- Use `*.secret.pkrvars.hcl` for local overrides — this pattern is gitignored.
- All sensitive variables come from Vault at build time.

**CI:**
- Image builds are triggered via `tpl-release` workflow from the `github-actions` repo.
- `packer validate` must pass on every PR (to be wired up once first template exists).

---

## Dependencies

**Upstream (what this repo needs):**
- Proxmox hypervisor (local — `https://proxmox.local` or similar)
- HashiCorp Vault — for Proxmox API credentials and image passwords
- `vault-helper.sh` from `proxmox-home-lab/.github` repo

**Downstream (what consumes this repo):**
- Future Terraform/OpenTofu modules that clone Proxmox templates to create VMs.
  The template name/ID output from Packer becomes an input to those modules.

---

## Known Issues / TODOs

- [ ] **No templates implemented** — OPNSense template is the first to build.
- [ ] **No CI validation** — `packer validate` should run on PRs once the first
  template is merged.
- [ ] **Vault path for Proxmox creds** — define and document the Vault KV path
  for Proxmox API token before building the first image.
- [ ] **Proxmox plugin version** — pin `hashicorp/proxmox` Packer plugin to a
  specific version in each template's `packer {}` block.
