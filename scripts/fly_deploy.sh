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
if [[ ${#WORKFLOW_INPUTS[@]} -eq 0 || ${#WORKFLOW_EVENT[@]} -eq 0 ]]; then
  error "Something went wrong preparing the workflow inputs, or event."
  exit 1
fi

prepare_deploy_vars
if [[ -z "$WORKSPACE_NAME" || -z "$WORKSPACE_PATH_RELATIVE" || -z "$FLY_APP_NAME" || -z "$FLY_CONFIG_FILE_PATH" || -z "$GIT_COMMIT_SHA" || -z "$GIT_COMMIT_SHA_SHORT" ]]; then
  error "Something went wrong preparing the necessary deploy variables."
  exit 1
fi

if ! does_fly_app_exists "$FLY_APP_NAME"; then
  retry 5 2 "Create fly app '$FLY_APP_NAME'" flyctl apps create "$FLY_APP_NAME" --org "$FLY_ORG"
else
  notice "App '$FLY_APP_NAME' already exists, skipping creation."
fi

if [ -n "${WORKFLOW_SECRETS[fly_secrets]}" ]; then
  group "Set configured secrets on $FLY_APP_NAME"
  debug "fly_secrets=${WORKFLOW_SECRETS[fly_secrets]}"
  echo "${WORKFLOW_SECRETS[fly_secrets]}" | tr " " "\n" | flyctl secrets import --stage --app "$FLY_APP_NAME";
  group_end
else
  warning "No secrets imported on $FLY_APP_NAME!";
fi

# Attach a consul cluster if requested
if [[ "${WORKFLOW_INPUTS[fly_consul_attach]}" == "true" ]]; then
  retry 5 2 "Attaching a consul cluster to $FLY_APP_NAME" flyctl consul attach --app "$FLY_APP_NAME"
fi

# Deploy the app to fly.io
retry 5 2 "Deploy the app to fly.io" flyctl deploy \
  --config "$FLY_CONFIG_FILE_PATH" \
  --app "$FLY_APP_NAME" \
  --build-arg "WORKSPACE_NAME=$WORKSPACE_NAME" \
  --build-arg "WORKSPACE_PATH_RELATIVE=$WORKSPACE_PATH_RELATIVE" \
  --build-arg "GIT_COMMIT_SHA=$GIT_COMMIT_SHA" \
  --build-arg "GIT_COMMIT_SHA_SHORT=$GIT_COMMIT_SHA_SHORT" \
  --remote-only \
  --yes

declare -rg FLY_APP_URL=$(get_fly_app_url "$FLY_APP_NAME")

notice FLY_APP_NAME=$FLY_APP_NAME
echo "fly_app_name=$FLY_APP_NAME" >> $GITHUB_OUTPUT

notice FLY_APP_URL=$FLY_APP_URL
echo "fly_app_url=$FLY_APP_URL" >> $GITHUB_OUTPUT

notice WORKSPACE_NAME=$WORKSPACE_NAME
echo "workspace_name=$WORKSPACE_NAME" >> $GITHUB_OUTPUT

notice WORKSPACE_PATH_RELATIVE=$WORKSPACE_PATH_RELATIVE
echo "workspace_path=$WORKSPACE_PATH_RELATIVE" >> $GITHUB_OUTPUT

echo "### Deployed ${FLY_APP_NAME} :rocket:" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "Fly App URL: $FLY_APP_URL" >> $GITHUB_STEP_SUMMARY
