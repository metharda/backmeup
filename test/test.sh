#!/usr/bin/env bash

set -e

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        BackMeUp Test Suite            "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Running tests in repository: $REPO_ROOT"
echo ""

echo "Test 1: Check bash syntax"
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

echo "Test 2: Check help command"
log_test "Testing help command..."
if "$REPO_ROOT/backmeup.sh" help &>/dev/null; then
    log_pass "Help command works"
else
    log_fail "Help command failed"
fi

echo "Test 3: Check backup command error handling"
log_test "Testing backup command error handling..."
if ! "$REPO_ROOT/backmeup.sh" backup &>/dev/null; then
    log_pass "Backup command properly requires arguments"
else
    log_fail "Backup command should fail without arguments"
fi

echo "Test 4: Source backup.sh and check functions"
log_test "Checking backup.sh functions..."
source "$REPO_ROOT/scripts/backup.sh"
FUNCTIONS_OK=true
for func in expand_path validate_directory check_compression_tool save_backup_config get_backup_config remove_backup_config list_backups create_backup_script_template start_backup update_backup delete_backup; do
    if ! declare -f "$func" &>/dev/null; then
        log_fail "Function $func not found"
        FUNCTIONS_OK=false
    fi
done
if $FUNCTIONS_OK; then
    log_pass "All backup.sh functions exist"
fi

echo "Test 5: Source cron.sh and check functions"
log_test "Checking cron.sh functions..."
source "$REPO_ROOT/scripts/cron.sh"
CRON_OK=true
for func in add_cron_entry remove_cron_entry list_cron_jobs; do
    if ! declare -f "$func" &>/dev/null; then
        log_fail "Function $func not found"
        CRON_OK=false
    fi
done
if $CRON_OK; then
    log_pass "All cron.sh functions exist"
fi

echo "Test 6: Test path expansion"
log_test "Testing path expansion..."
TEST_PATH=$(expand_path "~/test")
if [[ "$TEST_PATH" == "$HOME/test" ]]; then
    log_pass "Path expansion works correctly"
else
    log_fail "Path expansion failed"
fi

echo "Test 7: Check compression tools detection"
log_test "Testing compression tool detection..."
if check_compression_tool "tar.gz" &>/dev/null; then
    log_pass "Compression tool detection works"
else
    log_fail "Compression tool detection failed"
fi

echo "Test 8: Check config directory structure"
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