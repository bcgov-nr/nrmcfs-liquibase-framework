#!/usr/bin/env bash
set -e

# Define required environment variables
PODMAN_WORKDIR="${PODMAN_WORKDIR}"
TMP_VOLUME="${TMP_VOLUME}"
AUTHFILE="${AUTHFILE}"
CONTAINER_IMAGE_LIQUBASE="${CONTAINER_IMAGE_LIQUBASE}"

# Validate that all required variables are set
if [[ -z "$TMP_VOLUME" || -z "$AUTHFILE" || -z "$CONTAINER_IMAGE_LIQUBASE" ]]; then
    echo "Error: One or more required environment variables are not set or empty."
    echo "Ensure the following variables are set:"
    echo "  TMP_VOLUME: $TMP_VOLUME"
    echo "  AUTHFILE: $AUTHFILE"
    echo "  CONTAINER_IMAGE_LIQUBASE: $CONTAINER_IMAGE_LIQUBASE"
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

# Set up core migration framework
liquibase --defaultsFile=liquibase.properties \
    status --verbose
