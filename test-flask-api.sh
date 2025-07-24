#!/bin/bash

# Test script for Flask API endpoints
# This script tests the simple Flask API that responds to "hello" and "goodbye"

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
API_URL="${API_URL:-}"
TIMEOUT="${TIMEOUT:-10}"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

show_usage() {
    echo "Usage: $0 [API_URL]"
    echo ""
    echo "Examples:"
    echo "  $0 http://localhost:8080"
    echo "  $0 https://your-alb-url.com"
    echo "  API_URL=http://localhost:8080 $0"
    echo ""
    echo "Environment variables:"
    echo "  API_URL - Base URL of the API (required)"
    echo "  TIMEOUT - Request timeout in seconds (default: 10)"
}

test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_response=$4
    local description=$5
    
    log_test "$description"
    
    local response
    local http_code
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" "$API_URL$endpoint" || echo -e "\nERROR")
    else
        response=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_URL$endpoint" || echo -e "\nERROR")
    fi
    
    # Split response and HTTP code
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "ERROR" ]; then
        echo -e "${RED}✗ FAILED${NC} - Connection error or timeout"
        return 1
    fi
    
    echo "  HTTP Code: $http_code"
    echo "  Response: $response_body"
    
    # Check HTTP status code
    if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
        echo -e "${GREEN}✓ HTTP Status OK${NC}"
    else
        echo -e "${RED}✗ HTTP Status Failed${NC}"
        return 1
    fi
    
    # Check expected response if provided
    if [ -n "$expected_response" ]; then
        if echo "$response_body" | grep -q "$expected_response"; then
            echo -e "${GREEN}✓ Response Content OK${NC}"
        else
            echo -e "${RED}✗ Expected '$expected_response' but got '$response_body'${NC}"
            return 1
        fi
    fi
    
    echo ""
    return 0
}

run_tests() {
    local passed=0
    local total=0
    
    log_info "Starting API tests against: $API_URL"
    log_info "Timeout: ${TIMEOUT}s"
    echo ""
    
    # Test 1: Health check
    total=$((total + 1))
    if test_endpoint "GET" "/health" "" "healthy" "Health check endpoint"; then
        passed=$((passed + 1))
    fi
    
    # Test 2: Hello message
    total=$((total + 1))
    if test_endpoint "POST" "/" '{"message": "hello"}' '"hi"' "Send 'hello' message"; then
        passed=$((passed + 1))
    fi
    
    # Test 3: Goodbye message
    total=$((total + 1))
    if test_endpoint "POST" "/" '{"message": "goodbye"}' '"bye"' "Send 'goodbye' message"; then
        passed=$((passed + 1))
    fi
    
    # Test 4: Case insensitive hello
    total=$((total + 1))
    if test_endpoint "POST" "/" '{"message": "HELLO"}' '"hi"' "Send 'HELLO' (case insensitive)"; then
        passed=$((passed + 1))
    fi
    
    # Test 5: Case insensitive goodbye
    total=$((total + 1))
    if test_endpoint "POST" "/" '{"message": "GOODBYE"}' '"bye"' "Send 'GOODBYE' (case insensitive)"; then
        passed=$((passed + 1))
    fi
    
    # Test 6: Unknown message
    total=$((total + 1))
    if test_endpoint "POST" "/" '{"message": "unknown"}' '"unknown message"' "Send unknown message"; then
        passed=$((passed + 1))
    fi
    
    # Test 7: Invalid JSON
    total=$((total + 1))
    if test_endpoint "POST" "/" '{"invalid": "json"}' '"No message provided"' "Send invalid JSON structure"; then
        passed=$((passed + 1))
    fi
    
    # Test 8: Empty POST
    total=$((total + 1))
    if test_endpoint "POST" "/" '{}' '"No message provided"' "Send empty JSON"; then
        passed=$((passed + 1))
    fi
    
    # Summary
    echo "=================================="
    log_info "Test Results: $passed/$total tests passed"
    
    if [ "$passed" -eq "$total" ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    # Parse command line arguments
    if [ $# -eq 1 ]; then
        API_URL="$1"
    elif [ $# -gt 1 ]; then
        show_usage
        exit 1
    fi
    
    # Check if API_URL is set
    if [ -z "$API_URL" ]; then
        log_error "API_URL is required"
        echo ""
        show_usage
        exit 1
    fi
    
    # Remove trailing slash from URL
    API_URL="${API_URL%/}"
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install curl first."
        exit 1
    fi
    
    # Run the tests
    run_tests
}

# Run main function with all arguments
main "$@"