# Exponential backoff retry function
# retry <retries:integer> <base sleep time in seconds:integer> <"group name":string> <command...>
retry () {
  local retries=$1
  shift
  local base=$1
  shift
  local group_name=$1
  shift

  local count=1

  echo "::group::Try '$group_name ($count/$retries)'."
  echo "::notice::Using command: '$@'"

  until "$@"; do
    exit=$?

    echo "::error::'$group_name ($count/$retries)' exited with '$exit'."
    echo "::endgroup::"

    count=$(($count + 1))
    wait=$(($base ** $count))

    if [ $count -le $retries ]; then
      echo "::notice::Retry '$group_name ($count/$retries)' in '$wait' seconds."
      sleep $wait
      echo "::group::Retry '$group_name ($count/$retries)'."
      echo "::notice::Using command: '$@'"
    else
      echo "::error::No more retries left for '$group_name ($count/$retries)'. Exiting with exit code '$exit'."
      return $exit
    fi
  done
  echo "::endgroup::"
  return 0
}
