group () { echo "::group::$1"; }
end_group () { echo "::endgroup::"; }
debug () { echo "::debug::$1"; }
notice () { echo "::notice::$1"; }
warning () { echo "::warning::$1"; }
error () { echo "::error::$1"; }
