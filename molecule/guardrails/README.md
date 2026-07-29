# Guardrails Molecule scenario

This localhost-only scenario confirms that validation stops unsafe requests
before the role begins appliance checks. It currently covers:

- an upgrade without `ghes_upgrade_confirm: true`;
- the unsupported `cluster` topology.

The converge play catches each expected Ansible failure, records the result, and
the verify play asserts that both protections fired.
