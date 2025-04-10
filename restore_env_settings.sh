# Function to validate token
validate_token() {
    log_message "Validating API token..."
    local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/users/api/users/whoami")
    local status_code=$(echo "$response" | jq -r '.statusCode // 0')
    
    if [ "$status_code" -ne 0 ] && [ "$status_code" -ne 200 ]; then
        log_message "Error: Not authorized. Please check your token."
        echo "$response"
        exit 1
    fi
    
    log_message "Token validation successful."
} 