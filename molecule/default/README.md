# Default Molecule scenario

This scenario exercises a successful standalone upgrade entirely on localhost.
`prepare.yml` installs lightweight mocks for the GHES administrative commands
and creates a fake upgrade package. `converge.yml` runs the role, and
`verify.yml` checks:

- the version changed from `3.20.4` to `3.21.1`;
- maintenance mode was enabled and disabled;
- pre-upgrade and post-upgrade evidence files were created.

No real GHES command, reboot, network request, VM, or container is used.
