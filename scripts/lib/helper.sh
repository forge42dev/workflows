group () { echo "::group::$1"; }
group_end () { echo "::endgroup::"; }
debug () { echo "::debug::$1"; }
notice () { echo "::notice::$1"; }
warning () { echo "::warning::$1"; }
error () { echo "::error::$1"; }

list_assoc_array () {
  local -n assoc_array_ref=$1
  local key
  echo "$1 (${#assoc_array_ref[@]}):"
  for key in "${!assoc_array_ref[@]}"
  do
    echo -e "\t$key: '${assoc_array_ref[$key]}'"
  done
}

json_to_assoc_array () {
  local assoc_array_name=$1
  local -n assoc_array_ref=$1
  local json="${2}"
  local assoc_array_def=$(echo "$json" | jq -r '. | paths(type == "string" or type == "number" or type == "boolean") as $p | [($p|map(tostring)|join("_")), getpath($p)] | { (.[0]): .[1] }' | jq -rs "add | to_entries | map(\"${assoc_array_name}[\\\"\(.key)\\\"]=\\\"\(.value)\\\";\") | .[]")
  eval "$assoc_array_def"
}

cleanup () {
  echo "Cleaning up..."
}
