# Handlers

This role currently defines no handlers. GHES upgrade operations run as an
explicit, ordered task sequence because maintenance mode, reconnect handling,
and post-upgrade validation must happen at specific points.

Add a handler only when deferred execution is safe for the appliance lifecycle.
