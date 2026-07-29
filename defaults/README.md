# Role defaults

`main.yml` defines every supported `ghes_upgrade_*` variable and its
conservative default. The role is intentionally disabled by default:
confirmation, target version, backup confirmation, and snapshot confirmation
must be supplied by the operator.

Override these values in inventory, group variables, host variables, or the
play that invokes the role. Do not place environment-specific addresses,
credentials, or package paths in this directory.

See [`docs/README.md`](../docs/README.md#configuration-reference) for the
configuration reference.
