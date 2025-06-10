# HashiCorp Vault

## Purpose
Provides a secrets management tool. Vault is used to securely store, manage, and control access to tokens, passwords, certificates, API keys, and other sensitive data.

## Configuration
- **Helm Chart:** Configuration is primarily managed via the `values.yaml` file, which customizes the official HashiCorp Vault Helm chart.
- **Storage Backend:** The `values.yaml` file will define the storage backend for Vault (e.g., Consul, S3, an integrated Raft storage). This is a critical configuration piece.
- **Listeners & UI:** Configuration for network listeners, UI access, and other Vault operational parameters are set in `values.yaml`.
- **Secrets:** Initial root keys or unseal keys might be handled during the initial setup process. Ongoing, secrets *within* Vault are managed by Vault itself. Secrets *for* Vault (like cloud credentials for storage backend) are managed in Rancher and injected. Refer to the main project `README.md`.

## Deployment and Management
- **Fleet:** Vault is deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet uses the Helm chart (likely the official HashiCorp Vault chart) and the `values.yaml` file to deploy and manage the Vault cluster.
- **Initialization & Unsealing:** After deployment, Vault typically requires initialization (to generate master keys and root tokens) and unsealing (providing a quorum of unseal keys to make Vault operational). These are manual operational steps unless automated.

## Backup and Restore
[Details on backup and restore procedures for Vault need to be added. This is highly dependent on the configured storage backend:
- **Raft integrated storage:** Requires taking snapshots of the Raft backend.
- **Consul backend:** Requires backing up Consul's data.
- **Filesystem/S3 backend:** Requires backing up the respective filesystem path or S3 bucket.
It's crucial to also securely back up unseal keys and any recovery keys.]

## Key Files
- `fleet.yaml`: Fleet configuration for Vault deployment.
- `values.yaml`: Helm values file for customizing the HashiCorp Vault Helm chart.
- `README.md`: This file.

## Further Reading
- [HashiCorp Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
