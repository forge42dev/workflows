# Check if the app already exists, if not, create it.
# We want to have that in a separate group, thats the reason why we use status and create
# in two separate steps
fly_app_exists () {
  group "Check if fly app '$FLY_APP_NAME' already exists"
  flyctl status --app "$FLY_APP_NAME" > /dev/null 2>&1
  local status=$?
  group_end
  return $status
}

fly_app_create () {
  group "Create fly app '$FLY_APP_NAME' if it does not exist"
  if ! fly_app_exists; then
    retry 5 2 "Create fly app '$FLY_APP_NAME'" flyctl apps create "$FLY_APP_NAME" --org "$FLY_ORG"
    local status=$?
  else
    notice "App '$FLY_APP_NAME' already exists, skipping creation."
    local status=0
  fi
  group_end
  return $status
}


# Import secrets if any
fly_secrets_import () {
  group "Set the fly secrets if any are set"
  local status=0
  if [ -n "${WORKFLOW_SECRETS[fly_secrets]}" ]; then
    debug "fly_secrets=${WORKFLOW_SECRETS[fly_secrets]}"
    echo "${WORKFLOW_SECRETS[fly_secrets]}" | tr " " "\n" | flyctl secrets import --stage --app "$FLY_APP_NAME";
    local status=$?
  else
    warning "No secrets imported on $FLY_APP_NAME!";
  fi
  group_end
  return $status
}

fly_consul_attach () {
  group "Attach a consul cluster if requested"
  local status=0
  # Attach a consul cluster if requested
  if [[ "${WORKFLOW_INPUTS[fly_consul_attach]}" == "true" ]]; then
    retry 5 2 "Attaching a consul cluster" flyctl consul attach --app "$FLY_APP_NAME"
    local status=$?
  fi
  group_end
  return $status
}

# Deploy/Update the app
fly_deploy () {
  retry 5 2 "Deploy the app to fly.io" flyctl deploy \
    --config "$FLY_CONFIG_FILE_PATH" \
    --app "$FLY_APP_NAME" \
    --build-arg "WORKSPACE_NAME=$WORKSPACE_NAME" \
    --build-arg "WORKSPACE_PATH_RELATIVE=$WORKSPACE_PATH_RELATIVE" \
    --build-arg "GIT_COMMIT_SHA=$GIT_COMMIT_SHA" \
    --build-arg "GIT_COMMIT_SHA_SHORT=$GIT_COMMIT_SHA_SHORT" \
    --remote-only \
    --now \
    --yes
  return $?
}

fly_app_url () {
  local app_url="https://$(flyctl status --app "$FLY_APP_NAME" --json | jq -rS '.Hostname')/"
  local status=$?
  echo $app_url
  return $status
}
