#!/bin/bash
set -euo pipefail

# Supported _FILE variables for Docker Secrets.
# For each entry, if FOO_FILE is set, reads the file and exports FOO=<content>.
# If both FOO and FOO_FILE are set, FOO takes precedence.
#
# GARMIN_EMAIL_FILE / GARMIN_PASSWORD_FILE are handled natively by upstream,
# so they are deliberately not listed here.
FILE_VARS=(
    GARMIN_MCP_HTTP_TOKEN_FILE:GARMIN_MCP_HTTP_TOKEN
)

for entry in "${FILE_VARS[@]}"; do
    file_var="${entry%%:*}"
    target="${entry##*:}"
    file_path="${!file_var:-}"

    [[ -z "$file_path" ]] && continue

    if [[ -n "${!target:-}" ]]; then
        echo >&2 "[entrypoint] ${target} already set; ignoring ${file_var}"
        continue
    fi

    if [[ -f "$file_path" ]]; then
        export "${target}=$(< "$file_path")"
        unset "$file_var"
        echo >&2 "[entrypoint] Loaded Docker Secret: ${target}"
    else
        echo >&2 "[entrypoint] Error: Secret file not found: ${file_path} (for ${file_var})"
        exit 1
    fi
done

# Default CMD is `garmin-mcp`; pass another command (e.g. `garmin-mcp-auth`)
# to run it instead.
exec "$@"
