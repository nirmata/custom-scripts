#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TIMEOUT=10
MAX_RETRIES=3
REPORT_FILE="ingress_validation_report_$(date +%Y%m%d_%H%M%S).txt"
SUMMARY_FILE="ingress_validation_summary_$(date +%Y%m%d_%H%M%S).txt"

# Function to check URL
check_url() {
    local url=$1
    local retry_count=0
    local success=false

    # Add https:// if not present
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://$url"
    fi

    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        # Try with curl, following redirects, with timeout
        response=$(curl -s -L -w "%{http_code}" -o /dev/null \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
            --connect-timeout $TIMEOUT --max-time $TIMEOUT "$url" 2>/dev/null)
        
        if [ $? -eq 0 ] && [[ $response =~ ^2[0-9][0-9]$ ]]; then
            success=true
            echo -e "${GREEN}✓ $url - HTTP $response${NC}"
            echo "$url,SUCCESS,$response" >> "$REPORT_FILE"
            return 0
        else
            ((retry_count++))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo -e "${YELLOW}Retrying $url (Attempt $retry_count of $MAX_RETRIES)${NC}"
                sleep 2
            fi
        fi
    done

    echo -e "${RED}✗ $url - Failed after $MAX_RETRIES attempts${NC}"
    echo "$url,FAILED,$response" >> "$REPORT_FILE"
    return 1
}

# Main script
echo "Starting Ingress URL Validation..."
echo "Time: $(date)"
echo "----------------------------------------"

# Create/clear report files
echo "URL,Status,HTTP Code" > "$REPORT_FILE"
echo "Ingress Validation Summary - $(date)" > "$SUMMARY_FILE"

# Counter for statistics
total_urls=0
successful_urls=0
failed_urls=0

# Check if URLs file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <urls-file>"
    echo "URLs file should contain one URL per line"
    exit 1
fi

# Read URLs from file and check each one
while IFS= read -r url || [ -n "$url" ]; do
    # Skip empty lines and comments
    [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
    
    ((total_urls++))
    if check_url "$url"; then
        ((successful_urls++))
    else
        ((failed_urls++))
    fi
done < "$1"

# Generate summary
echo "----------------------------------------"
echo "Validation Complete!"
echo "Time: $(date)"
echo "Total URLs checked: $total_urls"
echo "Successful: $successful_urls"
echo "Failed: $failed_urls"
echo "----------------------------------------"

# Save summary to file
{
    echo "Ingress Validation Summary"
    echo "Time: $(date)"
    echo "----------------------------------------"
    echo "Total URLs checked: $total_urls"
    echo "Successful: $successful_urls"
    echo "Failed: $failed_urls"
    echo "----------------------------------------"
} >> "$SUMMARY_FILE"

echo "Detailed report saved to: $REPORT_FILE"
echo "Summary saved to: $SUMMARY_FILE"

# Exit with status 1 if any URLs failed
[ $failed_urls -gt 0 ] && exit 1
exit 0 