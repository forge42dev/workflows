#!/usr/bin/env bash

__dirname="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$__dirname/lib/helper.sh"
source "$__dirname/lib/prepare-vars.sh"
source "$__dirname/lib/retry.sh"
source "$__dirname/lib/fly.sh"

# Enable globstar to allow ** globs which is needed in this function
shopt -s globstar

prepare_workspaces_global () {
  local -n workspaces_ref=$1
  local found_workspace="$(grep -rls "\"name\":.*\".*\"" **/package.json | xargs -I {} dirname {})"
  for workspace in $found_workspace; do
    local workspace_name="$(jq -rS '.name' "$workspace/package.json")"
    local workspace_path_relative="$workspace"
    local workspace_config="$(jq -rS '.config' "$workspace/package.json")"
    workspaces_ref["$workspace_name"]='{"name": "'$workspace_name'", "path": "'$workspace_path_relative'", "config": '$workspace_config'}'
  done
}

prepare_filtered_workspaces () {
  local -n workspaces_ref=$1
  local -n workspaces_filtered_ref=$2
  local filter_key="$3"
  for workspace in "${!workspaces_ref[@]}"; do
    local workspace_value="${workspaces_ref[$workspace]}"
    # Filter out the workspaces that are deployable (config["$filter_key"] == true)
    if [[ "$(echo "$workspace_value" | jq -rS '.config["'$filter_key'"]')" == "true" ]]; then
      workspaces_filtered_ref+=("$workspace")
    fi
  done
}

filter_workspaces () {
  local WORKSPACES_FILTERED
  prepare_filtered_workspaces WORKSPACES WORKSPACES_FILTERED $1
  # This is the json string we need to construct for all deployable workspaces: { "include": [{"workspace": "website"},{"workspace": "@local/ui"}] }
  # Convert the array to the required JSON format
  echo "$(printf '%s\n' "${WORKSPACES_FILTERED[@]}" | jq -Rsc 'split("\n")[:-1]')"
}

declare -Ag WORKSPACES
prepare_workspaces_global WORKSPACES
list_assoc_array WORKSPACES

