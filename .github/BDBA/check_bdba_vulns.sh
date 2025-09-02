#!/bin/bash
# filepath: .github/scripts/check_bdba_vulns.sh

set -e

# BDBA Vulnerability Check Script
# This script processes BDBA scan results and generates GitHub Actions summary

ARTIFACTS_DIR="./bdba_artifacts"
VULN_FILE=""
VULN_COUNT=0

# Function to find vulnerability CSV file
find_vulnerability_file() {
    echo "Looking for BDBA Reports artifacts..."
    find "$ARTIFACTS_DIR" -name "*BDBA Reports*" -type d
    
    VULN_FILE=$(find "$ARTIFACTS_DIR" -name "*-vulns.csv" -type f | head -1)
    
    if [ -z "$VULN_FILE" ]; then
        echo "::warning::No vulnerability CSV file found in BDBA artifacts"
        echo "Available files in BDBA artifacts:"
        find "$ARTIFACTS_DIR" -type f | head -20
        
        write_no_file_summary
        exit 0
    fi
    
    echo "Found vulnerability file: $VULN_FILE"
}

# Function to write summary when no vulnerability file is found
write_no_file_summary() {
    cat >> "$GITHUB_STEP_SUMMARY" << 'EOF'
## 🔍 BDBA Vulnerability Scan Results

⚠️ **No vulnerability CSV file found in BDBA artifacts**

Please check the BDBA scan configuration.
EOF
}

# Function to count vulnerabilities (excluding triage vulnerabilities)
count_vulnerabilities() {
    if [ ! -f "$VULN_FILE" ]; then
        echo "::error::Vulnerability file not found: $VULN_FILE"
        exit 1
    fi
    
    # Count total lines and filtered vulnerabilities
    TOTAL_LINES=$(wc -l < "$VULN_FILE")
    
    # Use Python/awk to properly parse CSV with multiline fields
    VULN_COUNT=$(python3 -c "
import csv
import sys

count = 0
try:
    with open('$VULN_FILE', 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)
        next(reader)  # Skip header
        
        for row in reader:
            if len(row) >= 20:
                # Column 20 is index 19 (0-based)
                col20 = row[19].strip()
                # Count rows where column 20 is empty
                if not col20:
                    count += 1
            else:
                # If row has fewer than 20 columns, treat as no triage (count it)
                count += 1
                
except Exception as e:
    print(f'Error parsing CSV: {e}', file=sys.stderr)
    sys.exit(1)
    
print(count)
")
    
    # Calculate totals using Python for consistency
    TOTAL_DATA_LINES=$(python3 -c "
import csv
count = 0
try:
    with open('$VULN_FILE', 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)
        next(reader)  # Skip header
        for row in reader:
            count += 1
except:
    pass
print(count)
")
    
    EXCLUDED_COUNT=$((TOTAL_DATA_LINES - VULN_COUNT))
    
    echo "BDBA Vulnerability Analysis:"
    echo "=========================="
    echo "Total lines in file: $TOTAL_LINES"
    echo "Total data entries (excluding header): $TOTAL_DATA_LINES"
    echo "Excluded entries (column 20 not empty): $EXCLUDED_COUNT"
    echo "Vulnerability entries: $VULN_COUNT"
}

# Function to write basic summary header
write_summary_header() {
    cat >> "$GITHUB_STEP_SUMMARY" << EOF
## 🔍 BDBA Vulnerability Scan Results

**Scan Date:** $(date)  
**Total Vulnerabilities Found:** $VULN_COUNT

EOF
}

# Function to process vulnerabilities and write to summary
process_vulnerabilities() {
    echo ""
    echo "BDBA scan found $VULN_COUNT vulnerabilities!"
    echo ""
    
    # Add vulnerability table header to GitHub Summary
    cat >> "$GITHUB_STEP_SUMMARY" << 'EOF'
### ❌ Vulnerabilities Found

| # | CVE | CVSS3 | Component | Version | Latest_Version | Object_Full_Path | Vulnerability_URL |
|---|-----|-------|-----------|---------|----------------|------------------|-------------------|
EOF
    
    # Use Python to properly parse CSV and generate table
    python3 -c "
import csv
import sys

row_num = 0
try:
    with open('$VULN_FILE', 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)
        next(reader)  # Skip header
        
        for row in reader:
            if len(row) >= 20:
                # Column 20 is index 19 (0-based)
                col20 = row[19].strip()
                
                # Skip this row if column 20 is not empty
                if col20:
                    continue
            
            # Extract specific columns (0-based indexing)
            component = row[0] if len(row) > 0 else ''
            version = row[1] if len(row) > 1 else ''
            latest_version = row[2] if len(row) > 2 else ''
            cve = row[3] if len(row) > 3 else ''
            cvss3 = row[11] if len(row) > 11 else ''
            object_full_path = row[9] if len(row) > 9 else ''
            vulnerability_url = row[23] if len(row) > 23 else ''
            
            row_num += 1
            print(f'| {row_num} | {cve} | {cvss3} | {component} | {version} | {latest_version} | {object_full_path} | {vulnerability_url} |')
            
except Exception as e:
    print(f'Error processing CSV: {e}', file=sys.stderr)
    sys.exit(1)
" >> "$GITHUB_STEP_SUMMARY"
    
    # Add failure status to summary
    cat >> "$GITHUB_STEP_SUMMARY" << 'EOF'

**Action Required:** Review and fix the vulnerabilities listed above.
EOF
    
    exit 1
}

# Function to handle no vulnerabilities case
handle_no_vulnerabilities() {
    echo "✅ No vulnerabilities found by BDBA scan"
    echo ""
    
    # Add success message to summary
    cat >> "$GITHUB_STEP_SUMMARY" << 'EOF'
### ✅ No Vulnerabilities Found

**Status:** ✅ **PASSED**  
**Result:** No security vulnerabilities detected by BDBA scan

EOF
}

# Main execution function
main() {
    echo "Starting BDBA vulnerability check..."
    
    find_vulnerability_file
    count_vulnerabilities
    write_summary_header
    
    if [ "$VULN_COUNT" -gt 0 ]; then
        process_vulnerabilities
    else
        handle_no_vulnerabilities
    fi
    
    echo "BDBA vulnerability check completed."
}

# Run the main function
main "$@"