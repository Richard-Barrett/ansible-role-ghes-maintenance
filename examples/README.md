# Examples

- `inventory.yml` shows the GHES administrative SSH connection, which normally
  uses the `admin` account on port 122.
- `upgrade.yml` shows a guarded standalone upgrade using a package copied from
  the Ansible controller.
- `upgrade_ha.yml` orchestrates an HA primary and replicas using the role's
  preparation and finalization entry points.
- `services.yml` reports GHES service state and can run an explicitly supplied,
  GitHub Support-approved restart command behind a confirmation guard.

The host names, versions, URLs, and package paths are examples. Copy these files
outside the role, replace all placeholder values, confirm the supported upgrade
path, and test the resulting playbook before using it in production. The
examples reference the repository checkout so local syntax checks work; replace
`{{ playbook_dir }}/..` with the installed Galaxy role name in a consuming
repository.

See [`docs/README.md`](../docs/README.md) for the complete usage procedure.
