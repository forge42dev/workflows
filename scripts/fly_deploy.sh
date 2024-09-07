#!/usr/bin/env bash
# Exit on any failure
set -eo pipefail

DEBUG=${DEBUG:-}

# Debug mode
if [ -n "$DEBUG" ]; then
  set -xu
fi

# Handle errors
trap 'echo "Error: $? at line $LINENO" >&2' ERR
# Cleanup before exit
trap 'cleanup' EXIT

__dirname="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$__dirname/lib/helper.sh"
source "$__dirname/lib/prepare-vars.sh"
source "$__dirname/lib/retry.sh"
source "$__dirname/lib/fly.sh"

if [[ -z "$workflow_inputs" || -z "$workflow_secrets" || -z "$workflow_event" ]]; then
  error "Missing workflow inputs, secrets or event."
  exit 1
fi

prepare_globals "$workflow_inputs" "$workflow_secrets" "$workflow_event"
if [[ $? -ne 0 ]]; then
  error "prepare_globals failed"
  exit 1
fi

list_assoc_array WORKFLOW_INPUTS
list_assoc_array WORKFLOW_SECRETS
list_assoc_array WORKFLOW_EVENT

prepare_deploy_vars
if [[ $? -ne 0 ]]; then
  error "prepare_deploy_vars failed"
  exit 1
fi

echo "WORKSPACE_NAME=$WORKSPACE_NAME"
echo "WORKSPACE_PATH=$WORKSPACE_PATH"
echo "WORKSPACE_PATH_RELATIVE=$WORKSPACE_PATH_RELATIVE"
echo "FLY_ORG=$FLY_ORG"
echo "FLY_APP_NAME=$FLY_APP_NAME"
echo "FLY_CONSUL_ATTACH=$FLY_CONSUL_ATTACH"
echo "FLY_CONFIG_FILE_PATH=$FLY_CONFIG_FILE_PATH"
echo "GIT_COMMIT_SHA=$GIT_COMMIT_SHA"
echo "GIT_COMMIT_SHA_SHORT=$GIT_COMMIT_SHA_SHORT"

fly_app_create
if [[ $? -ne 0 ]]; then
  error "fly_app_create failed."
  exit 1
else
  notice "App $FLY_APP_NAME created."
fi

fly_secrets_import
if [[ $? -ne 0 ]]; then
  error "fly_secrets_import failed"
  exit 1
else
  notice "Secrets imported on $FLY_APP_NAME."
fi

fly_consul_attach
if [[ $? -ne 0 ]]; then
  error "fly_consul_attach failed"
  exit 1
else
  notice "Consul cluster attached to $FLY_APP_NAME."
fi

fly_deploy
if [[ $? -ne 0 ]]; then
  error "fly_deploy failed"
  exit 1
else
  notice "$FLY_APP_NAME deployed successfully."
fi

group "Get the app url"
app_url=$(fly_app_url)
if [[ $? -ne 0 ]]; then
  group_end
  error "fly_app_url failed"
  exit 1
fi

# Set the app url as an github output
notice "app_url=$app_url"
echo "app_url=$app_url" >> $GITHUB_OUTPUT
group_end

echo "### Deployed ${FLY_APP_NAME} :rocket:" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "App URL: $app_url" >> $GITHUB_STEP_SUMMARY
