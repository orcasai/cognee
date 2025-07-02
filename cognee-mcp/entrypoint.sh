#!/bin/bash

set -e  # Exit on error
echo "Debug mode: $DEBUG" >&2
echo "Environment: $ENVIRONMENT" >&2

# Run Alembic migrations with proper error handling.
# Note on UserAlreadyExists error handling:
# During database migrations, we attempt to create a default user. If this user
# already exists (e.g., from a previous deployment or migration), it's not a
# critical error and shouldn't prevent the application from starting. This is
# different from other migration errors which could indicate database schema
# inconsistencies and should cause the startup to fail. This check allows for
# smooth redeployments and container restarts while maintaining data integrity.
echo "Running database migrations..." >&2

MIGRATION_OUTPUT=$(alembic upgrade head 2>&1)
MIGRATION_EXIT_CODE=$?

if [[ $MIGRATION_EXIT_CODE -ne 0 ]]; then
    if [[ "$MIGRATION_OUTPUT" == *"UserAlreadyExists"* ]] || [[ "$MIGRATION_OUTPUT" == *"User default_user@example.com already exists"* ]]; then
        echo "Warning: Default user already exists, continuing startup..." >&2
    else
        echo "Migration failed with unexpected error." >&2
        exit 1
    fi
fi

echo "Database migrations done." >&2

echo "Starting Cognee MCP Server..." >&2

# Add startup delay to ensure DB is ready
sleep 2

# Modified Gunicorn startup with error handling
if [ "$ENVIRONMENT" = "dev" ] || [ "$ENVIRONMENT" = "local" ]; then
    if [ "$DEBUG" = "true" ]; then
        echo "Waiting for the debugger to attach..." >&2
        exec python -m debugpy --wait-for-client --listen 0.0.0.0:5678 -m cognee
    else
        exec cognee
    fi
else
    exec cognee
fi
