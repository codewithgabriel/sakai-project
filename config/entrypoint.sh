#!/bin/bash
set -e

# --- Configuration Defaults ---
export SAKAI_DB_HOST=${SAKAI_DB_HOST:-db}
export SAKAI_DB_PORT=${SAKAI_DB_PORT:-3306}
export SAKAI_DB_NAME=${SAKAI_DB_NAME:-sakaidatabase}
export SAKAI_DB_USER=${SAKAI_DB_USER:-sakaiuser}
export SAKAI_DB_PASS=${SAKAI_DB_PASS:-sakaipassword}

# Generate sakai.properties from template ONLY if:
#   - No sakai.properties is already bind-mounted, AND
#   - The template file actually exists
if [ -f "${SAKAI_HOME}/sakai.properties" ]; then
    echo "sakai.properties already present (bind-mounted). Skipping template generation."
elif [ -f "${SAKAI_HOME}/sakai.properties.template" ]; then
    echo "Generating sakai.properties from template..."
    envsubst < "${SAKAI_HOME}/sakai.properties.template" > "${SAKAI_HOME}/sakai.properties"
else
    echo "WARNING: No sakai.properties or template found. Sakai may not start correctly."
fi

echo "Starting Sakai on Tomcat..."
exec catalina.sh run
