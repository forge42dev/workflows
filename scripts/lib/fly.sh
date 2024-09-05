# Check if the app already exists, if not, create it.
# We want to have that in a separate group, thats the reason why we use status and create
# in two separate steps
fly_app_exists () {
  group "Check if fly app '$fly_app_name' already exists"
  local fly_app_name = $1
  local fly_status=0
  if ! flyctl status --app "$fly_app_name"; then
    fly_status=1
  fi
  group_end
  return $fly_status
}

fly_app_create () {
  group "Create fly app '$fly_app_name'"
  local fly_app_name = $1
  local fly_org = $2
  if [ $fly_status -ne 0 ]; then
    warning "App '$fly_app_name' does not exist, creating it..."
    retry 5 2 "Create fly app '$fly_app_name'" flyctl apps create "$fly_app_name" --org "$fly_org"
  else
    notice "App '$fly_app_name' already exists, skipping creation."
  fi
  group_end
}


# Import secrets if any
fly_secrets_import () {
  group "Set the fly secrets if any are set"
  local fly_app_name = $1
  if [ -n "${{ secrets.fly_secrets }}" ]; then
    notice "fly_secrets=${{ secrets.fly_secrets }}"
    echo '${{ secrets.fly_secrets }}' | tr " " "\n" | flyctl secrets import --stage --app "$fly_app_name";
  else
    warning "No secrets to import!";
  fi
  group_end
}

fly_consul_attach () {
  group "Attach a consul cluster if requested"
  local fly_app_name = $1
  # Attach a consul cluster if requested
  if [ "${{ inputs.fly_consul_attach }}" == "true" ]; then
    retry 5 2 "Attaching a consul cluster" flyctl consul attach --app "$fly_app_name"
  fi
  group_end
}

# Deploy/Update the app
fly_deploy () {
  local fly_app_name = $1
  local fly_config_file_path = $2
  local workspace_name = $3
  local workspace_path_relative = $4
  local git_commit_sha = $5
  local git_commit_sha_short = $6

  retry 5 2 "Deploy the app to fly.io" flyctl deploy \
    --config "$fly_config_file_path" \
    --app "$fly_app_name" \
    --build-arg "WORKSPACE_NAME=$workspace_name" \
    --build-arg "WORKSPACE_PATH_RELATIVE=$workspace_path_relative" \
    --build-arg "GIT_COMMIT_SHA=$git_commit_sha" \
    --build-arg "GIT_COMMIT_SHA_SHORT=$git_commit_sha_short" \
    --remote-only \
    --now \
    --yes

  app_url="https://$(flyctl status --app "$fly_app_name" --json | jq -rS '.Hostname')/"
  return $app_url
}
