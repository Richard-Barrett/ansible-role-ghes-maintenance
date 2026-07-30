# Using the GHES maintenance role

This role performs a guarded GitHub Enterprise Server (GHES) upgrade on either
a standalone appliance or the primary node of a high-availability pair. It does
not determine whether an upgrade path is supported, download packages, upgrade
HA replicas, or orchestrate GHES clusters.

## Prerequisites

Before scheduling an upgrade:

1. Confirm the source-to-target path in the GitHub Enterprise Server Upgrade
   Assistant and read the release-specific upgrade notes.
2. Download the correct `.pkg` or `.hpkg` file to the Ansible controller, or
   stage it on the appliance.
3. Verify that a recent GHES Backup Utilities backup completed successfully.
4. Take a current VM snapshot when that is part of your supported operational
   procedure.
5. Schedule a maintenance window and establish console access and a rollback
   plan.
6. Install Ansible Core 2.15 or newer on the controller.

The controller must reach the appliance's administrative SSH service. GHES
normally exposes that service to the `admin` user on port 122.

## Install the role

Place the repository at a role path named `ghes_upgrade`:

```text
roles/
└── ghes_upgrade/
    ├── defaults/
    ├── meta/
    └── tasks/
```

Alternatively, reference the repository in a role requirements file:

```yaml
---
roles:
  - name: ghes_upgrade
    src: https://github.com/Richard-Barrett/ansible-role-ghes-maintenance.git
    version: main
```

Install it with:

```bash
ansible-galaxy role install -r requirements.yml
```

Pin `version` to a reviewed tag or commit for production automation.

## Create the inventory

```yaml
---
all:
  children:
    ghes_primary:
      hosts:
        github.example.com:
          ansible_user: admin
          ansible_port: 122
```

Use SSH agent forwarding or another secure Ansible authentication mechanism.
Do not store private keys or credentials in the repository.

## Create the upgrade playbook

```yaml
---
- name: Upgrade GitHub Enterprise Server
  hosts: ghes_primary
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
        ghes_upgrade_topology: "standalone"
        ghes_upgrade_backup_confirmed: true
        ghes_upgrade_snapshot_confirmed: true
        ghes_upgrade_external_url: "https://github.example.com"
```

`ghes_upgrade_confirm`, the two operational confirmations, and the exact target
version are deliberate safety gates. Set them only for an approved maintenance
window.

## Validate and run

Check inventory connectivity and playbook syntax first:

```bash
ansible all -i inventory.yml -m ansible.builtin.ping
ansible-playbook -i inventory.yml upgrade.yml --syntax-check
```

Ansible check mode cannot simulate a GHES upgrade or its expected SSH
interruption. Use it to catch basic input and task problems, not as proof that
the upgrade will succeed:

```bash
ansible-playbook -i inventory.yml upgrade.yml --check --diff
```

Run the approved playbook:

```bash
ansible-playbook -i inventory.yml upgrade.yml
```

The role enables maintenance mode immediately before invoking `ghe-upgrade`.
It disables maintenance mode only after the target version, configuration,
background jobs, optional replication, and configured HTTP checks pass. If the
upgrade or reconnect fails, inspect the appliance console and logs before
changing maintenance mode or retrying.

## Package source modes

To copy a package from the controller, set both paths:

```yaml
ghes_upgrade_package_local_path: "/secure/packages/github-enterprise-3.21.1.pkg"
ghes_upgrade_package_remote_path: "/home/admin/github-enterprise-3.21.1.pkg"
```

To use a package already staged on GHES, leave the local path empty:

```yaml
ghes_upgrade_package_local_path: ""
ghes_upgrade_package_remote_path: "/home/admin/github-enterprise-3.21.1.pkg"
```

The remote file must exist, be a regular file, and be non-empty. Set
`ghes_upgrade_remove_package_after: true` to remove it after a successful
upgrade.

## High availability

The role supports an orchestrated HA configuration with one primary and one or
more replicas. This is not GitHub Enterprise Server Clustering.

Create `ghes_primary` and `ghes_replicas` inventory groups, as shown in
`examples/inventory.yml`. Put the shared upgrade inputs in group variables:

```yaml
ghes_upgrade_expected_current_version: "3.20.4"
ghes_upgrade_target_version: "3.21.1"
ghes_upgrade_package_remote_path: "/home/admin/github-enterprise-3.21.1.pkg"
ghes_upgrade_backup_confirmed: true
ghes_upgrade_snapshot_confirmed: true
```

Then review and run `examples/upgrade_ha.yml`. It performs these phases:

1. Validate the package, version, configuration, capacity, and required
   utilities on every appliance without changing HA state.
2. On the primary, require healthy replication, enter maintenance mode, and
   run `ghe-repl-stop-all`.
3. Upgrade the primary and wait for its post-upgrade validation to complete.
4. Upgrade every host in `ghes_replicas` with `serial: 1`.
5. On the primary, run `ghe-repl-start-all`, wait for `ghe-repl-status -vv` to
   return successfully, and only then exit maintenance mode.

```bash
ansible-playbook -i inventory/production.yml examples/upgrade_ha.yml
```

The primary and replica upgrade plays set
`ghes_upgrade_manage_maintenance: false` and
`ghes_upgrade_validate_replication: false` because replication is intentionally
stopped and the outer phases own those states. The role rejects an
`ha_replica` invocation without these guardrails.

If any node upgrade or final replication check fails, the final play does not
run. Maintenance therefore remains enabled and replication remains stopped for
operator investigation. Do not manually continue with a different node until
the failed primary configuration or node upgrade is understood.

The HA sequence applies to feature-release `.pkg` upgrades in the documented
primary-first workflow. Hotpatch `.hpkg` upgrades and actual GHES clusters have
different procedures. Always review the documentation and release notes for
the installed and target GHES versions before execution.

The `cluster` topology is rejected because clustered upgrades use a different
procedure.

## Custom checks

Add environment-specific, read-only commands before or after the upgrade:

```yaml
ghes_upgrade_precheck_commands:
  - name: Check local service state
    command: "ghe-service-list"

ghes_upgrade_postcheck_commands:
  - name: Confirm the installed version
    command: "ghe-version"
```

These commands run through Bash on the appliance. Treat their values as trusted
administrative configuration and never include secrets in commands or output.

When `ghes_upgrade_external_url` is set, the role tests the main URL before
leaving maintenance mode and checks each configured API path afterward:

```yaml
ghes_upgrade_external_url: "https://github.example.com"
ghes_upgrade_validate_certs: true
ghes_upgrade_api_checks:
  - path: "/api/v3/meta"
    status_codes: [200, 401, 403]
```

HTTP requests run on the Ansible controller, so its DNS, routing, proxy, and
certificate trust must match the production client path.

## Evidence

Pre-upgrade and post-upgrade evidence is written on the controller under:

```text
{{ playbook_dir }}/artifacts/ghes-upgrade/
```

Override `ghes_upgrade_artifact_dir` to use a protected operational evidence
location. Files contain command output and filesystem data; handle them
according to your organization's retention and access policies.

## Configuration reference

| Variable | Default | Description |
|---|---:|---|
| `ghes_upgrade_package_local_path` | `""` | Optional package path on the controller. |
| `ghes_upgrade_package_remote_path` | `/home/admin/ghes-upgrade.pkg` | Package staging or existing path on GHES. |
| `ghes_upgrade_package_mode` | `"0644"` | Mode applied when copying the package. |
| `ghes_upgrade_remove_package_after` | `false` | Remove the staged package after success. |
| `ghes_upgrade_confirm` | `false` | Required explicit approval gate. |
| `ghes_upgrade_expected_current_version` | `""` | Optional exact current-version guard. |
| `ghes_upgrade_target_version` | `""` | Required exact version expected after upgrade. |
| `ghes_upgrade_topology` | `standalone` | `standalone`, `ha_primary`, or guarded `ha_replica`. |
| `ghes_upgrade_validate_replication` | `true` | Check replication for a non-orchestrated HA primary. |
| `ghes_upgrade_ha_orchestrated` | `false` | Confirm the role is called by the HA multi-play workflow. |
| `ghes_upgrade_replication_retries` | `60` | HA replication health-check attempts. |
| `ghes_upgrade_replication_delay` | `10` | Seconds between HA replication checks. |
| `ghes_upgrade_manage_maintenance` | `true` | Enable and disable maintenance mode. |
| `ghes_upgrade_maintenance_message` | upgrade message | Message shown while maintenance mode is active. |
| `ghes_upgrade_leave_maintenance_on_failure` | `true` | Documents the safe failure policy. |
| `ghes_upgrade_require_backup_confirmation` | `true` | Require explicit backup confirmation. |
| `ghes_upgrade_backup_confirmed` | `false` | Operator assertion that backup succeeded. |
| `ghes_upgrade_require_snapshot_confirmation` | `true` | Require explicit snapshot confirmation. |
| `ghes_upgrade_snapshot_confirmed` | `false` | Operator assertion that snapshot is current. |
| `ghes_upgrade_min_root_free_mb` | `10240` | Minimum free space on `/`, in MiB. |
| `ghes_upgrade_min_data_free_mb` | `20480` | Minimum free space on `/data/user`, in MiB. |
| `ghes_upgrade_max_root_used_percent` | `85` | Maximum allowed utilization on `/`. |
| `ghes_upgrade_max_data_used_percent` | `90` | Maximum allowed utilization on `/data/user`. |
| `ghes_upgrade_command` | `ghe-upgrade` | Upgrade command, configurable for testing/support. |
| `ghes_upgrade_command_extra_args` | `[]` | Additional arguments passed to the upgrade command. |
| `ghes_upgrade_reboot_timeout` | `3600` | Upgrade/reconnect timeout in seconds. |
| `ghes_upgrade_connection_delay` | `30` | Delay before and during reconnect polling. |
| `ghes_upgrade_background_jobs_timeout` | `14400` | Background-job wait timeout in seconds. |
| `ghes_upgrade_background_jobs_poll` | `60` | Background-job polling interval in seconds. |
| `ghes_upgrade_wait_for_background_jobs` | `true` | Wait for post-upgrade jobs to complete. |
| `ghes_upgrade_external_url` | `""` | Optional base URL for controller-side HTTP checks. |
| `ghes_upgrade_validate_certs` | `true` | Validate TLS certificates during HTTP checks. |
| `ghes_upgrade_http_status_codes` | common healthy codes | Accepted main-page response codes. |
| `ghes_upgrade_http_retries` | `60` | HTTP check attempts. |
| `ghes_upgrade_http_delay` | `15` | Delay between HTTP attempts. |
| `ghes_upgrade_precheck_commands` | `[]` | Additional appliance checks before upgrade. |
| `ghes_upgrade_postcheck_commands` | `[]` | Additional appliance checks after upgrade. |
| `ghes_upgrade_api_checks` | `/api/v3/meta` | API paths and accepted status codes. |
| `ghes_upgrade_artifact_dir` | playbook artifacts path | Controller-side evidence directory. |

Defaults remain authoritative in
[`defaults/main.yml`](../defaults/main.yml).

## Development and Molecule

Create the development environment and run all checks:

```bash
make setup
make test
```

Run just the localhost-only Molecule scenarios:

```bash
make molecule
```

See [`molecule/README.md`](../molecule/README.md) for scenario details.
