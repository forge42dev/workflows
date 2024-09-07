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
  list_assoc_array WORKFLOW_INPUTS

  declare -Ag WORKFLOW_SECRETS
  json_to_assoc_array WORKFLOW_SECRETS "$2"
  declare -Arg WORKFLOW_SECRETS
  list_assoc_array WORKFLOW_SECRETS

  declare -Ag WORKFLOW_EVENT
  json_to_assoc_array WORKFLOW_EVENT "$3"
  declare -Arg WORKFLOW_EVENT
  list_assoc_array WORKFLOW_EVENT

  group_end

  return 0
}

prepare_deploy_vars () {
  group "Prepare deploy variables"

  # Enable globstar to allow ** globs which is needed in this function
  shopt -s globstar

  if [[ -z "${WORKFLOW_INPUTS[workspace_name]}" ]]; then
    notice "workspace_name not set. Using current directory as workspace_path and 'name' from ./package.json as workspace_name"
    local workspace_path_relative="."
    local workspace_path="$(pwd)"
    local workspace_name="$(jq -rS '.name' ./package.json)"
  else
    local found_workspace="$(grep -rls "\"name\":.*\"${WORKFLOW_INPUTS[workspace_name]}\"" **/package.json | xargs -I {} dirname {})"
    if [[ -z "$found_workspace" ]]; then
      error "No workspace with name '${WORKFLOW_INPUTS[workspace_name]}' found."
      return 1
    fi
    local workspace_path_relative="$found_workspace"
    local workspace_path="$(cd "$found_workspace" && pwd)"
    local workspace_name="${WORKFLOW_INPUTS[workspace_name]}"
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

  local fly_app_name="$(echo $raw_fly_app_name | sed 's/[\.\/_]/-/g; s/[^a-zA-Z0-9-]//g' | tr '[:upper:]' '[:lower:]')"
  debug "fly_app_name=$fly_app_name"

  if [[ -z "${WORKFLOW_INPUTS[fly_config_file_path]}" ]]; then
    notice "fly_config_file_path NOT set. Using workspace_path='$workspace_path' and 'fly.toml' as default."
    local raw_fly_config_file_path="$workspace_path/fly.toml"
  else
    local raw_fly_config_file_path="$workspace_path/${WORKFLOW_INPUTS[fly_config_file_path]}"
  fi

  local fly_config_file_path="$(realpath -e "$raw_fly_config_file_path")"
  if [[ $? -ne 0 ]]; then
    error "Could not resolve fly_config_file_path: '$raw_fly_config_file_path'"
    return 1
  fi
  debug "fly_config_file_path=$fly_config_file_path"

  if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
    local git_commit_sha="${WORKFLOW_EVENT[pull_request_head_sha]}"
  else
    local git_commit_sha="${GITHUB_SHA}"
  fi
  debug "git_commit_sha=$git_commit_sha"

  local git_commit_sha_short="$(git rev-parse --short $git_commit_sha)"
  debug "git_commit_sha_short=$git_commit_sha_short"

  if [[ -z "${WORKFLOW_INPUTS[fly_org]}" ]]; then
    error "fly_org is not set. Please set 'fly_org' as input."
    return 1
  else
    local fly_org="${WORKFLOW_INPUTS[fly_org]}"
  fi

  if [[ -z "${WORKFLOW_INPUTS[fly_consul_attach]}" ]]; then
    error "fly_consul_attach is not set. Please set 'fly_consul_attach' as input."
    return 1
  else
    local fly_consul_attach="${WORKFLOW_INPUTS[fly_consul_attach]}"
  fi

  # Disable globstar again to avoid problems with the ** glob
  shopt -u globstar

  declare -rg WORKSPACE_NAME="$workspace_name"
  declare -rg WORKSPACE_PATH="$workspace_path"
  declare -rg WORKSPACE_PATH_RELATIVE="$workspace_path_relative"
  declare -rg FLY_ORG="$fly_org"
  declare -rg FLY_APP_NAME="$fly_app_name"
  declare -rg FLY_CONSUL_ATTACH="$fly_consul_attach"
  declare -rg FLY_CONFIG_FILE_PATH="$fly_config_file_path"
  declare -rg GIT_COMMIT_SHA="$git_commit_sha"
  declare -rg GIT_COMMIT_SHA_SHORT="$git_commit_sha_short"

  notice "WORKSPACE_NAME=$WORKSPACE_NAME"
  notice "WORKSPACE_PATH=$WORKSPACE_PATH"
  notice "WORKSPACE_PATH_RELATIVE=$WORKSPACE_PATH_RELATIVE"
  notice "FLY_APP_NAME=$FLY_APP_NAME"
  notice "FLY_CONFIG_FILE_PATH=$FLY_CONFIG_FILE_PATH"
  notice "GIT_COMMIT_SHA=$GIT_COMMIT_SHA"
  notice "GIT_COMMIT_SHA_SHORT=$GIT_COMMIT_SHA_SHORT"

  group_end
}
