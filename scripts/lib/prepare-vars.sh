# This function expects three parameters:
# 1. The workflow inputs as json string
# 2. The workflow secrets as json string
# 3. The workflow event as json string
# It will flatten and process the JSON object and set global readonly associative arrays:
# - WORKFLOW_INPUTS
# - WORKFLOW_SECRETS
# - WORKFLOW_EVENT
prepare_globals () {
  group "Prepare global variables"

  # The function expects a json string as input, e.g. '{"foo": "bar", "hello": "world"}'.
  # It will set the local variables with the same name as the json keys, e.g. 'local inputs_foo="bar"'
  # This allows you to process the 'inputs_*' variables first, then set them in the global scope of the script.
  declare -Ag WORKFLOW_INPUTS
  json_to_assoc_array WORKFLOW_INPUTS "$1"
  declare -Arg WORKFLOW_INPUTS
  notice "WORKFLOW_INPUTS=${#WORKFLOW_INPUTS[@]}"

  declare -Ag WORKFLOW_SECRETS
  json_to_assoc_array WORKFLOW_SECRETS "$2"
  declare -Arg WORKFLOW_SECRETS
  notice "WORKFLOW_SECRETS=${#WORKFLOW_SECRETS[@]}"

  declare -Ag WORKFLOW_EVENT
  json_to_assoc_array WORKFLOW_EVENT "$3"
  declare -Arg WORKFLOW_EVENT
  notice "WORKFLOW_EVENT=${#WORKFLOW_EVENT[@]}"

  group_end

  return 0
}

prepare_deploy_vars () {
  group "Prepare deploy variables"

  # Enable globstar to allow ** globs which is needed in this function
  shopt -s globstar

  if [[ -z "${WORKFLOW_INPUTS[workspace_name]}" ]]; then
    notice "workspace_name not set. Using current directory as workspace_path and 'name' from ./package.json as workspace_name"
    workspace_path_relative="."
    workspace_path="$(pwd)"
    workspace_name="$(jq -rS '.name' ./package.json)"
  else
    local found_workspace="$(grep -rls "\"name\":.*\"${WORKFLOW_INPUTS[workspace_name]}\"" **/package.json | xargs -I {} dirname {})"
    if [[ -z "$found_workspace" ]]; then
      error "No workspace with name '${WORKFLOW_INPUTS[workspace_name]}' found."
      return 1
    fi
    workspace_path_relative="$found_workspace"
    workspace_path="$(cd "$found_workspace" && pwd)"
    workspace_name="${WORKFLOW_INPUTS[workspace_name]}"
  fi

  debug "workspace_name=$workspace_name"
  debug "workspace_path=$workspace_path"
  debug "workspace_path_relative=$workspace_path_relative"

  if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
    local default_fly_app_name="${GITHUB_REPOSITORY}-${workspace_name}-pr${WORKFLOW_EVENT[number]}"
  elif [[ "${GITHUB_EVENT_NAME}" == "push" || "${GITHUB_EVENT_NAME}" == "create" ]]; then
    local default_fly_app_name="${GITHUB_REPOSITORY}-${workspace_name}-${GITHUB_REF_TYPE}-${GITHUB_REF_NAME}"
  fi

  debug "default_fly_app_name=$default_fly_app_name"

  local raw_fly_app_name="${WORKFLOW_INPUTS[fly_app_name]:-$default_fly_app_name}"
  if [[ -z "$raw_fly_app_name" ]]; then
    error "Default for 'fly_app_name' could not be generated for github event '${GITHUB_EVENT_NAME}'. Please set 'fly_app_name' as input."
    return 1
  fi

  fly_app_name="$(echo $raw_fly_app_name | sed 's/[\.\/_]/-/g; s/[^a-zA-Z0-9-]//g' | tr '[:upper:]' '[:lower:]')"
  debug "fly_app_name=$fly_app_name"

  if [[ -z "${WORKFLOW_INPUTS[fly_config_file_path]}" ]]; then
    notice "fly_config_file_path NOT set. Using workspace_path='$workspace_path' and 'fly.toml' as default."
    local raw_fly_config_file_path="$workspace_path/fly.toml"
  else
    local raw_fly_config_file_path="$workspace_path/${WORKFLOW_INPUTS[fly_config_file_path]}"
  fi

  fly_config_file_path="$(realpath -e "$raw_fly_config_file_path")"
  if [[ $? -ne 0 ]]; then
    error "Could not resolve fly_config_file_path: '$raw_fly_config_file_path'"
    return 1
  fi
  debug "fly_config_file_path=$fly_config_file_path"

  if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
    git_commit_sha="${WORKFLOW_EVENT[pull_request_head_sha]}"
  else
    git_commit_sha="${GITHUB_SHA}"
  fi
  debug "git_commit_sha=$git_commit_sha"

  git_commit_sha_short="$(git rev-parse --short $git_commit_sha)"
  debug "git_commit_sha_short=$git_commit_sha_short"

  # Disable globstar again to avoid problems with the ** glob
  shopt -u globstar

  group_end
}
