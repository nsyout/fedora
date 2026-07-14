#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/update-tools.sh"
trap 'rm -rf "$TEST_ROOT" "$BUILD_DIR"' EXIT

fail() {
	echo "not ok - $*" >&2
	exit 1
}

assert_equal() {
	local expected="$1"
	local actual="$2"
	local message="$3"
	[[ "$actual" == "$expected" ]] || fail "$message (expected: $expected, actual: $actual)"
}

fixture_source="$TEST_ROOT/ghostty-source"
mkdir -p "$fixture_source"
printf '%s\n' '.{ .name = .ghostty, .minimum_zig_version = "0.15.2", }' >"$fixture_source/build.zig.zon"
actual=$(ghostty_required_zig_version "$fixture_source")
assert_equal "0.15.2" "$actual" "reads Ghostty minimum Zig version"

# shellcheck disable=SC2329
curl() {
	printf '%s\n' '[{"name":"tip"},{"name":"v9.8.7"},{"name":"v10.0.0"},{"name":"v10.0.0-beta.1"}]'
}
actual=$(github_latest_stable_tag "ghostty-org/ghostty")
assert_equal "v10.0.0" "$actual" "selects highest stable semantic version tag"
unset -f curl

fake_bin="$TEST_ROOT/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/zig" <<'EOF'
#!/usr/bin/env bash
echo "0.15.2"
EOF
chmod +x "$fake_bin/zig"
PATH="$fake_bin:$PATH"
actual=$(zig_for_version "0.15.2")
assert_equal "$fake_bin/zig" "$actual" "uses matching system Zig"

cat >"$fake_bin/zig" <<'EOF'
#!/usr/bin/env bash
echo "0.16.0"
EOF
cached_dir="$HOME/.local/share/dot/zig/0.15.2"
mkdir -p "$cached_dir"
cat >"$cached_dir/zig" <<'EOF'
#!/usr/bin/env bash
echo "0.15.2"
EOF
chmod +x "$fake_bin/zig" "$cached_dir/zig"
actual=$(zig_for_version "0.15.2")
assert_equal "$cached_dir/zig" "$actual" "uses cached Zig when system version differs"

# shellcheck disable=SC2329
update_failure_fixture() {
	false
	touch "$TEST_ROOT/errexit-was-disabled"
}
_updated_tools=()
_skipped_tools=()
_failed_tools=()
_run_tool_update "failure-fixture"
assert_equal "failure-fixture" "${_failed_tools[0]}" "records updater failures"
[[ ! -e "$TEST_ROOT/errexit-was-disabled" ]] || fail "tool updater runs without fail-fast behavior"

if main unsupported-tool >"$TEST_ROOT/main.out" 2>&1; then
	fail "main propagates tool failures"
fi

echo "ok - update-tools"
