# Role task flow

The task files execute in this order:

1. `validate.yml` checks explicit approval, topology, target version, backup and
   snapshot confirmations, and package input.
2. `prechecks.yml` validates the current appliance state, capacity,
   configuration, background jobs, and optional HA replication.
3. `upgrade.yml` stages the package, enables maintenance mode, starts the
   upgrade, and waits for SSH to return.
4. `postchecks.yml` validates the resulting version and appliance health,
   disables maintenance mode, and saves evidence.

The order is safety-sensitive. New tasks should fail with actionable messages,
avoid logging secrets, and preserve maintenance mode when post-upgrade health
cannot be established.
