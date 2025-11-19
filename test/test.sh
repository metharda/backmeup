#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       Small BackMeUp Test Suite        "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Running tests in repository: $REPO_ROOT"
echo ""

log_info "Test 1: Check bash syntax"
log_test "Checking bash syntax..."
SYNTAX_OK=true
while IFS= read -r script; do
    if [[ -f "$script" ]]; then
        if ! bash -n "$script" 2>/dev/null; then
            log_fail "Syntax error in $script"
            SYNTAX_OK=false
        fi
    fi
done < <(find "$REPO_ROOT" -type f -name "*.sh" -not -path "*/.git/*")

if $SYNTAX_OK; then
    log_pass "All scripts have valid syntax"
fi

log_info "Test 2: Check help command"
log_test "Testing help command..."
if "$REPO_ROOT/backmeup.sh" help &>/dev/null; then
    log_pass "Help command works"
else
    log_fail "Help command failed"
fi

log_info "Test 3: Check backup command error handling"
log_test "Testing backup command error handling..."
if timeout 2 "$REPO_ROOT/backmeup.sh" backup start &>/dev/null; then
    log_fail "Backup command should fail without arguments"
else
    log_pass "Backup command properly requires arguments"
fi

log_info "Test 4: Test path expansion"
log_test "Testing path expansion..."
source "$REPO_ROOT/scripts/backup.sh"
TEST_PATH=$(expand_path "~/test")
if [[ "$TEST_PATH" == "$HOME/test" ]]; then
    log_pass "Path expansion works correctly"
else
    log_fail "Path expansion failed"
fi

log_info "Test 5: Check compression tools detection"
log_test "Testing compression tool detection..."
if check_compression_tool "tar.gz" &>/dev/null; then
    log_pass "Compression tool detection works"
else
    log_fail "Compression tool detection failed"
fi

log_info "Test 6: Check config directory structure"
log_test "Testing config directory structure..."
TEST_CONFIG_DIR="$HOME/.config/backmeup"
TEST_CONFIG_FILE="$TEST_CONFIG_DIR/backups.conf"
if mkdir -p "$TEST_CONFIG_DIR" 2>/dev/null && touch "$TEST_CONFIG_FILE" 2>/dev/null; then
    log_pass "Config directory structure valid"
    rm -f "$TEST_CONFIG_FILE"
else
    log_fail "Config directory structure invalid"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "             Test Results              "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi