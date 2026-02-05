#!/usr/bin/env bash
set -e
param=$1

case "$param" in
  "--run-update")
    DRY_LB_CMD=update-sql;
    LIQUIBASE_CMD=update;
    ;;
  "--run-rollback")
    DRY_LB_CMD=rollback-sql;
    LIQUIBASE_CMD=rollback;
    ;;
  *)
    echo "Invalid parameter: $param"
    echo "$0 [--run-update|--run-rollback]"
    exit 1
esac

# Define required environment variables
PODMAN_WORKDIR="${LIQUIBASE_HOME_DIR}"
TMP_VOLUME="${TMP_VOLUME}"
AUTHFILE="${AUTHFILE}"
CONTAINER_IMAGE_LIQUBASE="${CONTAINER_IMAGE_LIQUBASE}"
GITHUB_TAG="${GITHUB_TAG#v}"
LIQUIBASE_FRAMEWORK_DIR="${LIQUIBASE_FRAMEWORK_DIR}"
DRY_RUN="${DRY_RUN:-false}"
LB_LOG_LEVEL="${LIQUIBASEFRAMEWORKLOGLEVEL:-WARNING}"

# Validate that all required variables are set
if [[ -z "$TMP_VOLUME" || -z "$AUTHFILE" || -z "$CONTAINER_IMAGE_LIQUBASE" || -z "$GITHUB_TAG" || -z "$LIQUIBASE_FRAMEWORK_DIR" ]]; then
    echo "Error: One or more required environment variables are not set or empty."
    echo "Ensure the following variables are set:"
    echo "  TMP_VOLUME: $TMP_VOLUME"
    echo "  AUTHFILE: $AUTHFILE"
    echo "  CONTAINER_IMAGE_LIQUBASE: $CONTAINER_IMAGE_LIQUBASE"
    echo "  GITHUB_RELEASE_TAG: $GITHUB_RELEASE_TAG"
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
    LIQUIBASE_CMD=$DRY_LB_CMD
fi

# Get status
liquibase --defaultsFile=liquibase.properties \
    status --verbose -Dapp_version=${GITHUB_TAG}

##### pre-migration ####################################################################################################

# Set up core migration framework
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=nrdk.xml \
    --log-level=${LB_LOG_LEVEL} \
    --contexts=setup,compile_schema ${LIQUIBASE_CMD} -Dstage=pre${GITHUB_TAG}
echo Exit: $?

# Clear schema state for pre-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=nrdk.xml \
    --log-level=${LB_LOG_LEVEL} \
    --show-banner false \
    --contexts=clear_schema_state ${LIQUIBASE_CMD} -Dstage=pre${GITHUB_TAG}
echo Exit: $?

# Log schema state for pre-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=nrdk.xml \
    --log-level=${LB_LOG_LEVEL} \
    --show-banner false \
    --contexts=log_schema_state ${LIQUIBASE_CMD} -Dstage=pre${GITHUB_TAG}
echo Exit: $?

# Tag database before running migration
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=nrdk.xml \
    --log-level=${LB_LOG_LEVEL} \
    --show-banner false \
    --contexts=pre_tag ${LIQUIBASE_CMD} -Dmigration_tag=${GITHUB_TAG}
echo Exit: $?

##### update or rollback ###############################################################################################

# Perform database migration for version
liquibase --defaultsFile=liquibase.properties \
    ${LIQUIBASE_CMD} -Dapp_version=${GITHUB_TAG}
echo Exit: $?

##### post-migration ###################################################################################################


# Tag database for version
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Skipping tag database for version (DRY_RUN=true)"
else
    liquibase --defaultsFile=liquibase.properties \
        --log-level=${LB_LOG_LEVEL} \
        tag ${GITHUB_TAG}
fi

# Recompile schema
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=nrdk.xml \
    --log-level=${LB_LOG_LEVEL} \
    --show-banner false \
    --contexts=compile_schema ${LIQUIBASE_CMD}
echo Exit: $?

# Clear schema state for post-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=nrdk.xml \
    --log-level=${LB_LOG_LEVEL} \
    --show-banner false \
    --contexts=clear_schema_state ${LIQUIBASE_CMD} -Dstage=post${GITHUB_TAG}
echo Exit: $?

# Log schema state for post-version stage
liquibase --defaultsFile=liquibase.properties \
    --search-path=${PODMAN_WORKDIR}/${LIQUIBASE_FRAMEWORK_DIR} \
    --changelog-file=nrdk.xml \
    --log-level=${LB_LOG_LEVEL} \
    --show-banner false \
    --contexts=log_schema_state ${LIQUIBASE_CMD} -Dstage=post${GITHUB_TAG}
echo Exit: $?
