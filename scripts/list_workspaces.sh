#!/usr/bin/env bash

__dirname="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$__dirname/lib/helper.sh"
source "$__dirname/lib/prepare-vars.sh"
source "$__dirname/lib/retry.sh"
source "$__dirname/lib/fly.sh"

# Enable globstar to allow ** globs which is needed in this function
shopt -s globstar

prepare_workspaces_global () {
  local found_workspace="$(grep -rls "\"name\":.*\".*\"" **/package.json | xargs -I {} dirname {})"
  declare -Ag WORKSPACES
  for workspace in $found_workspace; do
    local workspace_name="$(jq -rS '.name' "$workspace/package.json")"
    local workspace_path_relative="$workspace"
    local workspace_config="$(jq -rS '.config' "$workspace/package.json")"
    WORKSPACES["$workspace_name"]='{"name": "'$workspace_name'", "path": "'$workspace_path_relative'", "config": '$workspace_config'}'
  done
}

list_deployable_workspaces () {
  for workspace in "${!WORKSPACES[@]}"; do
    local workspace_value="${WORKSPACES[$workspace]}"
    declare -ag WORKSPACES_DEPLOYABLE
    # Filter out the workspaces that are deployable (config.deploy == true)
    if [[ "$(echo "$workspace_value" | jq -rS '.config.deploy')" == "true" ]]; then
      WORKSPACES_DEPLOYABLE+=("$workspace")
    fi
  done
}


prepare_workspaces_global
list_assoc_array WORKSPACES

list_deployable_workspaces
list_assoc_array WORKSPACES_DEPLOYABLE

