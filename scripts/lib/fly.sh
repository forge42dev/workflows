# Check if the app already exists
does_fly_app_exists () {
  local fly_app_name=$1
  flyctl status --app "$fly_app_name" > /dev/null 2>&1
  return $?
}

# Get a FQDN of the app
get_fly_app_url () {
  local fly_app_name=$1
  local app_url="https://$(flyctl status --app "$fly_app_name" --json | jq -rS '.Hostname')/"
  local status=$?
  echo $app_url
  return $status
}
