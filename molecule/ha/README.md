# HA scenario

This scenario models one GHES primary and two replicas using local mocked
administrative commands. It verifies the required order: maintenance mode,
replication stop, primary upgrade, serial replica upgrades, replication start,
health validation, and maintenance-mode exit.
