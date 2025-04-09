# Ingress URL Validator

A shell script to automatically validate multiple ingress URLs and generate detailed reports.

## Features

- Validates multiple URLs in parallel
- Automatically adds `https://` prefix if not present
- Retries failed URLs up to 3 times
- Generates detailed CSV reports
- Color-coded terminal output
- Browser-like headers to avoid blocking
- Handles timeouts and connection errors
- Follows redirects automatically

## Usage

1. Create a text file with your ingress URLs (one per line):
```txt
pe420.nirmata.co
pe421.nirmata.co
pe422.nirmata.co
```

2. Run the script:
```bash
./validate_ingress.sh your_urls.txt
```

## Output

The script generates two files:
1. `ingress_validation_report_TIMESTAMP.txt`: Detailed CSV report with all URLs and their status
2. `ingress_validation_summary_TIMESTAMP.txt`: Summary report with statistics

## Configuration

You can modify these variables in the script:
- `TIMEOUT`: Connection timeout in seconds (default: 10)
- `MAX_RETRIES`: Number of retry attempts for failed URLs (default: 3)

## Example Output

```
Starting Ingress URL Validation...
Time: Wed Apr  9 11:11:33 IST 2025
----------------------------------------
✓ https://pe420.nirmata.co - HTTP 200
✓ https://pe421.nirmata.co - HTTP 200
✓ https://pe422.nirmata.co - HTTP 200
----------------------------------------
Validation Complete!
Total URLs checked: 3
Successful: 3
Failed: 0
----------------------------------------
``` 