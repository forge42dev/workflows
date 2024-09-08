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

prepare_deployable_workspaces () {
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

prepare_deployable_workspaces
list_assoc_array WORKSPACES_DEPLOYABLE

# workspace: ["website", "@local/ui"]
# This is the json string we need to construct for all deployable workspaces: { "include": [{"workspace": "website"},{"workspace": "@local/ui"}] }
# Convert the array to the required JSON format
json_array=$(printf '%s\n' "${WORKSPACES_DEPLOYABLE[@]}" | jq -Rsc 'split("\n")[:-1] | map({workspace: .})')

# This is the json string we need to construct for all deployable workspaces: { "include": [{"workspace": "website"},{"workspace": "@local/ui"}] }
echo "deployable_workspaces={\"include\":$json_array}" >> $GITHUB_OUTPUT

