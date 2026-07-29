# Contributing to ansible-role-ghes-maintenance

Thank you for contributing to `ansible-role-ghes-maintenance`.

This project automates operationally sensitive GitHub Enterprise Server tasks, including upgrades, maintenance-mode changes, health checks, service reloads, and replication validation. Contributions should prioritize safety, predictability, and clear operator feedback.

## Code of Conduct

Be respectful, constructive, and professional in all project discussions, issues, reviews, and pull requests.

## Before You Start

For substantial changes, open an issue before writing code. This is especially important for changes that affect:

- GHES upgrade sequencing
- High-availability or replication behavior
- Maintenance-mode handling
- Reboots or service restarts
- Backup or snapshot validation
- Version detection
- Commands executed with elevated privileges
- Support for new GHES releases

Small documentation updates, typo corrections, and straightforward test improvements can be submitted directly as pull requests.

## Development Requirements

Recommended local tooling:

- Python 3.10 or newer
- Ansible Core
- Molecule
- ansible-lint
- yamllint
- pre-commit
- GNU Make

Create a virtual environment and install the development dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
```

Install the Git hooks:

```bash
make hooks
```

View all available development targets:

```bash
make help
```

## Repository Workflow

1. Fork the repository.
2. Create a branch from the default branch.
3. Make focused changes.
4. Add or update tests.
5. Update documentation when behavior changes.
6. Run the full validation suite.
7. Submit a pull request.

Use descriptive branch names, for example:

```text
feature/ha-replica-prechecks
fix/maintenance-mode-cleanup
docs/upgrade-package-guidance
test/service-restart-guardrails
```

## Coding Standards

### Ansible

- Use fully qualified collection names where practical.
- Give every task a descriptive name.
- Prefer modules over `command` or `shell`.
- When a GHES command-line utility must be used, make the command explicit and testable.
- Set `changed_when` and `failed_when` deliberately.
- Avoid hiding failures with `ignore_errors`.
- Use `block`, `rescue`, and `always` where cleanup or maintenance-mode handling is required.
- Keep defaults conservative and non-destructive.
- Require explicit confirmation variables for disruptive actions.
- Do not log secrets, tokens, credentials, or sensitive command output.
- Preserve maintenance mode after a failed disruptive operation unless cleanup is clearly safe.

### YAML

- Use two-space indentation.
- Start YAML documents with `---`.
- Keep lines readable and compatible with the repository's lint configuration.
- Quote values when YAML coercion could change their meaning.

### Shell Commands

- Prefer one command per task.
- Avoid complex pipelines when Ansible modules can express the same behavior.
- Quote variables carefully.
- Do not use undocumented GHES commands without explaining why they are necessary.
- Commands supplied by GitHub Support should remain configurable rather than hard-coded.

## Safety Requirements

Changes that perform upgrades, restarts, reboots, failovers, replication operations, or maintenance-mode transitions must include safeguards.

At minimum, disruptive workflows should consider:

- Explicit operator confirmation
- Supported topology validation
- Current and target version validation
- Backup confirmation
- Snapshot confirmation
- Disk-capacity checks
- Configuration validation
- Background migration status
- Replication health for HA deployments
- Maintenance-mode handling
- Reconnect behavior after restart
- Post-operation service validation
- HTTP or API sanity tests
- Actionable failure messages

Do not assume that standalone, high-availability, and clustered GHES deployments use the same operational sequence.

## Testing

Run the complete local validation suite before submitting a pull request:

```bash
make lint
make syntax
make test
make pre-commit
```

To run all Molecule scenarios:

```bash
make molecule
```

To work with one scenario:

```bash
make molecule-create SCENARIO=default
make molecule-converge SCENARIO=default
make molecule-verify SCENARIO=default
make molecule-destroy SCENARIO=default
```

### Molecule Expectations

Molecule scenarios should not require a licensed GHES appliance image.

Mock GHES command-line utilities where appropriate, including commands such as:

```text
ghe-version
ghe-upgrade
ghe-config-check
ghe-config-apply
ghe-maintenance
ghe-repl-status
ghe-service-list
```

Tests should verify both successful workflows and guardrails. Relevant failure cases include:

- Missing operator confirmation
- Unsupported topology
- Unexpected current version
- Insufficient disk space
- Failed configuration checks
- Incomplete background migrations
- Unhealthy replication
- Failed service validation
- Failed post-upgrade sanity checks

Changes to behavior should include corresponding assertions in Molecule's verification tasks.

## Documentation

Update `README.md` when you add or change:

- Role variables
- Supported topologies
- Playbook usage
- Make targets
- Required confirmations
- Operational assumptions
- Upgrade sequencing
- Service-management behavior
- Molecule scenarios

Document defaults, examples, safety implications, and expected failure behavior.

## Commit Messages

Use clear, imperative commit messages.

Examples:

```text
Add HA replication pre-checks
Fix maintenance mode cleanup on validation failure
Document upgrade package staging
Test core service restart guardrails
```

Keep commits focused. Avoid combining unrelated refactoring, documentation, and behavior changes in a single commit when they can be reviewed independently.

## Pull Request Requirements

A pull request should include:

- A clear summary of the change
- The operational reason for the change
- Testing performed
- Any new or changed variables
- Safety and rollback considerations
- Documentation updates
- Relevant issue references

A useful pull request description includes:

```markdown
## Summary

Describe the change.

## Why

Explain the operational problem being solved.

## Testing

List the commands and Molecule scenarios executed.

## Safety considerations

Describe failure behavior, maintenance-mode behavior, and rollback impact.

## Checklist

- [ ] Linting passes
- [ ] Syntax checks pass
- [ ] Molecule tests pass
- [ ] Pre-commit checks pass
- [ ] Documentation is updated
- [ ] No secrets or environment-specific data are included
```

## Testing Against a Real GHES Instance

Do not test disruptive changes against a production GHES instance first.

When real-appliance validation is necessary:

1. Use a staging instance that mirrors production as closely as practical.
2. Confirm a recent backup exists.
3. Confirm a recoverable VM snapshot exists.
4. Schedule a maintenance window.
5. Record the current GHES version and topology.
6. Validate rollback procedures before execution.
7. Capture pre- and post-operation evidence.
8. Remove credentials and environment-specific data before sharing logs.

Never commit:

- GHES licenses
- Upgrade packages
- Authentication tokens
- SSH private keys
- Vault passwords
- Production inventory files
- Internal hostnames or IP addresses
- Backups or support bundles

## Reporting Security Issues

Do not disclose suspected security vulnerabilities in a public issue.

Report them privately to the repository maintainers with:

- A description of the issue
- Affected files or workflows
- Reproduction steps
- Potential impact
- Suggested remediation, when available

Do not include live credentials, production data, or sensitive support bundles.

## License

By contributing to this repository, you agree that your contributions will be licensed under the MIT License.
