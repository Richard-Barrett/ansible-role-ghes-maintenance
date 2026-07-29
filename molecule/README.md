# Molecule tests

The Molecule suite uses Ansible's local connection and does not require Docker,
a licensed GHES image, or access to an appliance.

- `default` runs the complete upgrade workflow against mocked GHES commands and
  verifies the version change, maintenance-mode transitions, and evidence files.
- `guardrails` verifies that missing confirmation and cluster topology are
  rejected before any appliance command runs.

Run both scenarios with:

```bash
make molecule
```

Run a single scenario with:

```bash
make molecule-converge SCENARIO=default
make molecule-verify SCENARIO=default
make molecule-destroy SCENARIO=default
```

The scenarios use dedicated directories below `/tmp` and remove them during
cleanup. Idempotence is omitted intentionally: after a successful upgrade, the
role rejects another run because the current version equals the target version.
