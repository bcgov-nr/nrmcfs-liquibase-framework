#!/usr/bin/env bash
set -e

# Define required environment variables
PODMAN_WORKDIR="${LIQUIBASE_HOME_DIR}"
TMP_VOLUME="${TMP_VOLUME}"
AUTHFILE="${AUTHFILE}"
CONTAINER_IMAGE_LIQUBASE="${CONTAINER_IMAGE_LIQUBASE}"
GITHUB_TAG="${GITHUB_TAG#v}"
LIQUIBASE_FRAMEWORK_DIR="${LIQUIBASE_FRAMEWORK_DIR}"
DRY_RUN="${DRY_RUN:-false}"

# Validate that all required variables are set
if [[ -z "$TMP_VOLUME" || -z "$AUTHFILE" || -z "$CONTAINER_IMAGE_LIQUBASE" || -z "$GITHUB_TAG" || -z "$LIQUIBASE_FRAMEWORK_DIR" ]]; then
    echo "Error: One or more required environment variables are not set or empty."
    echo "Ensure the following variables are set:"
    echo "  TMP_VOLUME: $TMP_VOLUME"
    echo "  AUTHFILE: $AUTHFILE"
    echo "  CONTAINER_IMAGE_LIQUBASE: $CONTAINER_IMAGE_LIQUBASE"
    echo "  GITHUB_TAG: $GITHUB_TAG"
    echo "  LIQUIBASE_FRAMEWORK_DIR: $LIQUIBASE_FRAMEWORK_DIR"
    echo "  DRY_RUN: $DRY_RUN"
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

# Determine the liquibase command based on DRY_RUN
if [[ "$DRY_RUN" == "true" ]]; then
    LIQUIBASE_CMD="rollback-sql"
else
    LIQUIBASE_CMD="rollback"
fi

# Perform database rollback for version (applies to APP only, not framework)
liquibase --defaultsFile=liquibase.properties \
    ${LIQUIBASE_CMD} --tag=pre${GITHUB_TAG} -Dapp_version=${GITHUB_TAG}
