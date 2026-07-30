<img align="right" width="60" height="60" src="https://github.com/devicons/devicon/blob/master/icons/ansible/ansible-plain-wordmark.svg">

# Ansible Role: `ansible-role-ghes-maintenance`
Ansible Role for GHES Maintenance

A guarded Ansible role for upgrading a standalone GitHub Enterprise Server
appliance or orchestrating an HA primary and its replicas with `ghe-upgrade`.

For installation, preflight planning, a complete variable reference, HA
guidance, and operational examples, see the
[usage guide](https://github.com/Richard-Barrett/ansible-role-ghes-maintenance/wiki).

## Safety model

The role will not run unless all of these are explicitly provided:

- `ghes_upgrade_confirm: true`
- `ghes_upgrade_target_version`
- backup confirmation
- VM snapshot confirmation
- an upgrade package

The role intentionally rejects GHES cluster topology. Cluster upgrades have a different node ordering and procedure.

## Workflow

1. Verify GHES administrative utilities.
2. Read and validate the current version.
3. Run `ghe-config-check --error-checks-only`.
4. Verify no earlier background upgrade jobs remain.
5. Enforce root and `/data/user` capacity thresholds.
6. Run `ghe-check-disk-usage` and optional custom checks.
7. For a non-orchestrated HA primary, validate `ghe-repl-status -vv`.
8. Stage and checksum the upgrade package.
9. Enable maintenance mode.
10. Execute `ghe-upgrade`, tolerate the expected SSH interruption, and reconnect.
11. Wait for background upgrade jobs, verify the exact target version, check configuration and replication, and run HTTP/API sanity tests.
12. Disable maintenance mode only after validation succeeds.
13. Save pre- and post-upgrade evidence on the controller.

## Inventory

GHES administrative SSH normally uses the `admin` account on port `122`:

```yaml
all:
  hosts:
    ghes-primary:
      ansible_host: github.example.com
      ansible_user: admin
      ansible_port: 122
```

## Example

```yaml
- name: Upgrade GHES
  hosts: ghes-primary
  gather_facts: false
  serial: 1
  any_errors_fatal: true

  roles:
    - role: ghes_upgrade
      vars:
        ghes_upgrade_confirm: true
        ghes_upgrade_expected_current_version: "3.20.4"
        ghes_upgrade_target_version: "3.21.1"
        ghes_upgrade_package_local_path: "/secure/packages/github-enterprise-3.21.1.pkg"
        ghes_upgrade_package_remote_path: "/home/admin/github-enterprise-3.21.1.pkg"
        ghes_upgrade_backup_confirmed: true
        ghes_upgrade_snapshot_confirmed: true
        ghes_upgrade_external_url: "https://github.example.com"
```

Run it with:

```bash
ansible-playbook -i examples/inventory.yml examples/upgrade.yml
```

## Important variables

| Variable | Purpose |
|---|---|
| `ghes_upgrade_topology` | `standalone`, `ha_primary`, or `ha_replica` |
| `ghes_upgrade_ha_orchestrated` | Require the guarded multi-play HA workflow |
| `ghes_upgrade_expected_current_version` | Prevents upgrading an unexpected appliance version |
| `ghes_upgrade_target_version` | Exact version expected after reboot |
| `ghes_upgrade_package_local_path` | Package on the Ansible controller |
| `ghes_upgrade_package_remote_path` | Staging path or pre-existing package on GHES |
| `ghes_upgrade_external_url` | URL used for post-upgrade web and API tests |
| `ghes_upgrade_precheck_commands` | Environment-specific read-only checks |
| `ghes_upgrade_postcheck_commands` | Environment-specific sanity checks |

## HA note

The included `examples/upgrade_ha.yml` playbook uses the role's `ha_preflight`,
`ha_prepare`, and `ha_finalize` task entry points to:

1. Preflight every appliance before disruption.
2. Verify replication, enable maintenance mode, and stop all replication.
3. Upgrade the primary.
4. Upgrade replicas serially.
5. Restart and validate replication before disabling maintenance mode.

This workflow is for GHES HA or geo-replication appliances. GitHub Enterprise
Server Clustering uses different commands and node ordering and remains
unsupported by this role.

## Package and upgrade-path validation

The role validates the local state but does not infer a supported upgrade path. Before execution, use GitHub's Upgrade Assistant and obtain the correct platform-specific `.pkg` or universal `.hpkg` package. A hotpatch is only suitable for patch releases in the same feature series; a feature release requires an upgrade package.

## Testing

The Molecule suite runs against local mocked GHES commands, so it does not need
a licensed appliance, VM, or container:

```bash
make setup
make molecule
make test
```

The `default` scenario exercises a complete successful upgrade. The
`guardrails` scenario checks that missing operator confirmation and unsupported
cluster topology are rejected. See
[`molecule/README.md`](molecule/README.md) for individual scenario commands.
