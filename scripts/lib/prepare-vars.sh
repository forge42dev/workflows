# This function expects three parameters:
# 1. The workflow inputs as json string
# 2. The workflow context as json string
# 3. The workflow secrets as json string
# It will flatten and process the JSON object and set global readonly associative arrays:
# - WORKFLOW_INPUTS
# - WORKFLOW_CONTEXT
# - WORKFLOW_SECRETS
# The keys of the associative arrays are the same as the keys in the JSON.
# For instance, the following passed json context '{ "github": { "event": { "number": "42" } } }',
# can be accessed as:
# echo ${WORKFLOW_CONTEXT["github_event_number"]} # 42
prepare_vars () {
  group "Prepare variables needed for deployment"

  # Enable globstar to allow ** globs which is needed in this function
  shopt -s globstar

  # The function expects a json string as input, e.g. '{"foo": "bar", "hello": "world"}'.
  # It will set the local variables with the same name as the json keys, e.g. 'local inputs_foo="bar"'
  # This allows you to process the 'inputs_*' variables first, then set them in the global scope of the script.
  declare -A WORKFLOW_INPUTS
  json_to_assoc_array WORKFLOW_INPUTS "$1"
  declare -r WORKFLOW_INPUTS

  declare -A WORKFLOW_CONTEXT
  json_to_assoc_array WORKFLOW_CONTEXT "$2"
  declare -r WORKFLOW_CONTEXT

  declare -A WORKFLOW_SECRETS
  json_to_assoc_array WORKFLOW_SECRETS "$3"
  declare -r WORKFLOW_SECRETS

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

  notice "workspace_name=$workspace_name"
  notice "workspace_path=$workspace_path"
  notice "workspace_path_relative=$workspace_path_relative"

  if [[ "${WORKFLOW_CONTEXT[github_event_name]}" == "pull_request" ]]; then
    local default_fly_app_name="${WORKFLOW_CONTEXT[github_repository]}-${workspace_name}-pr${WORKFLOW_CONTEXT[github_event_number]}"
  elif [[ "${WORKFLOW_CONTEXT[github_event_name]}" == "push" || "${WORKFLOW_CONTEXT[github_event_name]}" == "create" ]]; then
    local default_fly_app_name="${WORKFLOW_CONTEXT[github_repository]}-${workspace_name}-${WORKFLOW_CONTEXT[github_ref_type]}-${WORKFLOW_CONTEXT[github_ref_name]}"
  fi

  local raw_fly_app_name="${WORKFLOW_INPUTS[fly_app_name]:-$default_fly_app_name}"
  if [[ -z "$raw_fly_app_name" ]]; then
    error "Default for 'fly_app_name' could not be generated for github event '${WORKFLOW_CONTEXT[github_event_name]}'. Please set 'fly_app_name' in the input."
    return 1
  fi

  fly_app_name="$(echo $raw_fly_app_name | sed 's/[\.\/_]/-/g; s/[^a-zA-Z0-9-]//g' | tr '[:upper:]' '[:lower:]')"
  notice "fly_app_name=$fly_app_name"

  if [[ -z "${WORKFLOW_INPUTS[fly_config_file_path]}" ]]; then
    notice "fly_config_file_path NOT set. Using workspace_path='$workspace_path' and 'fly.toml' as default."
    local raw_fly_config_file_path="$workspace_path/fly.toml"
  else
    notice "fly_config_file_path set. Using workspace_path='$workspace_path' and '${WORKFLOW_INPUTS[fly_config_file_path]}' as default."
    local raw_fly_config_file_path="$workspace_path/${WORKFLOW_INPUTS[fly_config_file_path]}"
  fi

  fly_config_file_path="$(realpath -e "$raw_fly_config_file_path")"
  if [[ $? -ne 0 ]]; then
    error "Could not resolve fly_config_file_path: '$raw_fly_config_file_path'"
    return 1
  fi
  notice "fly_config_file_path=$fly_config_file_path"

  if [ "${WORKFLOW_CONTEXT[github_event_name]}" == "pull_request" ]; then
    git_commit_sha="${WORKFLOW_CONTEXT[github_event_pull_request_head_sha]}"
  else
    git_commit_sha="${WORKFLOW_CONTEXT[github_sha]}"
  fi
  notice "git_commit_sha=$git_commit_sha"

  git_commit_sha_short="$(git rev-parse --short $git_commit_sha)"
  notice "git_commit_sha_short=$git_commit_sha_short"

  # Disable globstar again to avoid problems with the ** glob
  shopt -u globstar

  list_assoc_array WORKFLOW_INPUTS
  list_assoc_array WORKFLOW_CONTEXT
  list_assoc_array WORKFLOW_SECRETS

  end_group
}
