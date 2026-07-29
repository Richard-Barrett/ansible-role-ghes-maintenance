# Examples

- `inventory.yml` shows the GHES administrative SSH connection, which normally
  uses the `admin` account on port 122.
- `upgrade.yml` shows a guarded standalone upgrade using a package copied from
  the Ansible controller.
- `services.yml` reports GHES service state and can run an explicitly supplied,
  GitHub Support-approved restart command behind a confirmation guard.

The host names, versions, URLs, and package paths are examples. Copy these files
outside the role, replace all placeholder values, confirm the supported upgrade
path, and test the resulting playbook before using it in production.

See [`docs/README.md`](../docs/README.md) for the complete usage procedure.
