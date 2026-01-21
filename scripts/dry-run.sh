#!/usr/bin/env bash
set -e

# Define required environment variables
PODMAN_WORKDIR="${LIQUIBASE_HOME_DIR}"
TMP_VOLUME="${TMP_VOLUME}"
AUTHFILE="${AUTHFILE}"
CONTAINER_IMAGE_LIQUBASE="${CONTAINER_IMAGE_LIQUBASE}"
GITHUB_TAG="${GITHUB_TAG#v}"
LIQUIBASE_FRAMEWORK_DIR="${LIQUIBASE_FRAMEWORK_DIR}"

# Validate that all required variables are set
if [[ -z "$TMP_VOLUME" || -z "$AUTHFILE" || -z "$CONTAINER_IMAGE_LIQUBASE" || -z "$GITHUB_TAG" || -z "$LIQUIBASE_FRAMEWORK_DIR" ]]; then
    echo "Error: One or more required environment variables are not set or empty."
    echo "Ensure the following variables are set:"
    echo "  TMP_VOLUME: $TMP_VOLUME"
    echo "  AUTHFILE: $AUTHFILE"
    echo "  CONTAINER_IMAGE_LIQUBASE: $CONTAINER_IMAGE_LIQUBASE"
    echo "  GITHUB_TAG: $GITHUB_TAG"
    echo "  LIQUIBASE_FRAMEWORK_DIR: $LIQUIBASE_FRAMEWORK_DIR"
    exit 1
fi

# Define an alias for the liquibase command using podman
alias liquibase="podman run --rm \
    --security-opt label=disable \
    --userns keep-id \
    -v \"$(pwd)/${TMP_VOLUME}:${PODMAN_WORKDIR}\" \
    --workdir \"${PODMAN_WORKDIR}\" \
    --authfile \"${TMP_VOLUME}/${AUTHFILE}\" \
    \"${CONTAINER_IMAGE_LIQUBASE}\""

# Ensure the alias is available in the current shell
shopt -s expand_aliases

# Start pre-migration
# Set up core migration framework
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=changelog.xml \
    --contexts=setup,compile_schema update-sql -Dstage=pre${GITHUB_TAG}

# Clear schema state for pre-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=changelog.xml \
    --contexts=clear_schema_state update-sql -Dstage=pre${GITHUB_TAG}

# Log schema state for pre-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=changelog.xml \
    --contexts=log_schema_state update-sql -Dstage=pre${GITHUB_TAG}

# Tag database before running migration
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=changelog.xml \
    --contexts=pre_tag update-sql -Dmigration_tag=${GITHUB_TAG}
# End pre-migration

# Start migration
# Perform database migration for version
liquibase --defaultsFile=liquibase.properties \
    --contexts=pre_tag update-sql -Dapp_version=${GITHUB_TAG}

# Tag database for version
echo "Skipping tag database for version"

# Recompile schema
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=changelog.xml \
    --contexts=compile_schema update-sql

# Clear schema state for post-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=changelog.xml \
    --contexts=clear_schema_state update-sql -Dstage=post${GITHUB_TAG}

# Log schema state for post-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=changelog.xml \
    --contexts=log_schema_state update-sql -Dstage=post${GITHUB_TAG}
# End migration
