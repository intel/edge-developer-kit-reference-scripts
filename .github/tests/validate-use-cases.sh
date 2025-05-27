#!/bin/bash

set -euo pipefail

# Define log levels
LOG_LEVEL_ERROR=0
LOG_LEVEL_WARN=1
LOG_LEVEL_INFO=2
LOG_LEVEL_DEBUG=3

# Set current log level (can be changed via environment variable)
CURRENT_LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Report file path
REPORT_FILE="${REPORT_FILE:-validation_report.csv}"

# Log file directory
LOG_DIR="${LOG_DIR:-./logs}"

# List of available use cases
AVAILABLE_USECASES=("rag-toolkit" "ai-video-analytics" "openwebui-ollama" "smart-parking" "digital-avatar")

# Create an associative array to store validation results
declare -A validation_results

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    if [ "$level" -le "$CURRENT_LOG_LEVEL" ]; then
        case $level in
            "$LOG_LEVEL_ERROR") echo -e "[$timestamp] ERROR: $message" ;;
            "$LOG_LEVEL_WARN")  echo -e "[$timestamp] WARNING: $message" ;;
            "$LOG_LEVEL_INFO")  echo -e "[$timestamp] INFO: $message" ;;
            "$LOG_LEVEL_DEBUG") echo -e "[$timestamp] DEBUG: $message" ;;
        esac
    fi
}

# Add validation result to the tracking array
record_validation() {
    local module_name=$1
    local status=$2  # "PASS" or "FAIL"
    
    validation_results["$module_name"]="$status"
    log $LOG_LEVEL_DEBUG "Recorded validation result: $module_name = $status"
}

# Generate a CSV report with all validation results
generate_report() {
    log $LOG_LEVEL_INFO "Generating validation report: $REPORT_FILE"
    
    # Create CSV header
    echo "Module,Status,Timestamp" > "$REPORT_FILE"
    
    # Current timestamp for the report
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Add each module result to the CSV
    for module in "${!validation_results[@]}"; do
        echo "$module,${validation_results[$module]},$timestamp" >> "$REPORT_FILE"
    done
    
    log $LOG_LEVEL_INFO "Report generated successfully with ${#validation_results[@]} entries"
    
    # Print report summary to console
    if [ "$CURRENT_LOG_LEVEL" -ge "$LOG_LEVEL_INFO" ]; then
        echo ""
        echo "===== VALIDATION SUMMARY ====="
        echo "Module                   | Status"
        echo "-------------------------|-------"
        for module in "${!validation_results[@]}"; do
            printf "%-25s | %s\n" "$module" "${validation_results[$module]}"
        done
        echo "============================="
    fi
}

validate_rag_toolkit() {
    local module_name="rag-toolkit"
    log $LOG_LEVEL_INFO "Validating $module_name use case..."
    
    # Add detailed logging for debugging if needed
    log $LOG_LEVEL_DEBUG "Checking $module_name directory structure"
    
    local success=true
    
    if [[ ! -d "./usecases/ai/rag-toolkit" ]]; then
        log $LOG_LEVEL_ERROR "$module_name directory not found"
        success=false
    fi

    cd ./usecases/ai/rag-toolkit || {
        log $LOG_LEVEL_ERROR "Failed to change directory to $module_name"
        success=false
    }

    # Setup environment
    if [[ -d ".venv" ]]; then
        log $LOG_LEVEL_INFO "Removing existing .venv directory"
        rm -rf .venv
    fi

    if [[ -d "data" ]]; then
        log $LOG_LEVEL_INFO "Removing existing data directory"
        rm -rf data
    fi

    log $LOG_LEVEL_INFO "Setting up environment for $module_name module..."
    export LLM_DEVICE="CPU"
    ./setup.sh || {
        log $LOG_LEVEL_ERROR "Failed to run setup script for $module_name"
        success=false
    }

    log $LOG_LEVEL_INFO "Running $module_name module completed"

    sleep 5

    # Cleanup the module
    log $LOG_LEVEL_INFO "Cleaning up $module_name module..."
    docker compose down || {
        log $LOG_LEVEL_ERROR "Failed to clean up $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Cleaning up $module_name module completed"
    cd - || {
        log $LOG_LEVEL_ERROR "Failed to return to previous directory"
        success=false
    }
    
    # Record the validation result
    if [ "$success" = true ]; then
        record_validation "$module_name" "PASS"
    else
        record_validation "$module_name" "FAIL"
    fi
}

validate_ai_video_analytics() {
    local module_name="ai-video-analytics"
    log $LOG_LEVEL_INFO "Validating $module_name use case..."
    
    # Add detailed logging for debugging if needed
    log $LOG_LEVEL_DEBUG "Checking $module_name directory structure"
    
    local success=true
    
    if [[ ! -d "./usecases/ai/ai-video-analytics" ]]; then
        log $LOG_LEVEL_ERROR "$module_name directory not found"
        success=false
    fi

    cd ./usecases/ai/ai-video-analytics || {
        log $LOG_LEVEL_ERROR "Failed to change directory to $module_name"
        success=false
    }

    # Build the module
    log $LOG_LEVEL_INFO "Building $module_name module..."
    docker compose build --no-cache || {
        log $LOG_LEVEL_ERROR "Failed to build $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Building $module_name module completed"

    # Run the module
    log $LOG_LEVEL_INFO "Running $module_name module on CPU..."
    export DEVICE="CPU"
    docker compose up -d || {
        log $LOG_LEVEL_ERROR "Failed to run $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Running $module_name module completed"

    sleep 5

    # Cleanup the module
    log $LOG_LEVEL_INFO "Cleaning up $module_name module..."
    docker compose down || {
        log $LOG_LEVEL_ERROR "Failed to clean up $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Cleaning up $module_name module completed"
    
    cd - || {
        log $LOG_LEVEL_ERROR "Failed to return to previous directory"
        success=false
    }
    
    # Record the validation result
    if [ "$success" = true ]; then
        record_validation "$module_name" "PASS"
    else
        record_validation "$module_name" "FAIL"
    fi
}

validate_openwebui_ollama(){
    local module_name="openwebui-ollama"
    log $LOG_LEVEL_INFO "Validating $module_name use case..."
    
    # Add detailed logging for debugging if needed
    log $LOG_LEVEL_DEBUG "Checking $module_name directory structure"
    
    local success=true
    
    if [[ ! -d "./usecases/ai/openwebui-ollama" ]]; then
        log $LOG_LEVEL_ERROR "$module_name directory not found"
        success=false
    fi

    cd ./usecases/ai/openwebui-ollama || {
        log $LOG_LEVEL_ERROR "Failed to change directory to $module_name"
        success=false
    }

    # Build the module
    log $LOG_LEVEL_INFO "Building $module_name module..."
    docker compose build --no-cache || {
        log $LOG_LEVEL_ERROR "Failed to build $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Building $module_name module completed"

    # Run the module
    log $LOG_LEVEL_INFO "Running $module_name module on CPU..."
    local render_gid
    render_gid=$(getent group render | cut -d: -f3)
    export RENDER_GROUP_ID="$render_gid"
    docker compose up -d || {
        log $LOG_LEVEL_ERROR "Failed to run $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Running $module_name module completed"

    sleep 5

    # Cleanup the module
    log $LOG_LEVEL_INFO "Cleaning up $module_name module..."
    docker compose down || {
        log $LOG_LEVEL_ERROR "Failed to clean up $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Cleaning up $module_name module completed"
    
    cd - || {
        log $LOG_LEVEL_ERROR "Failed to return to previous directory"
        success=false
    }
    
    # Record the validation result
    if [ "$success" = true ]; then
        record_validation "$module_name" "PASS"
    else
        record_validation "$module_name" "FAIL"
    fi
}

validate_smart_parking() {
    local module_name="smart-parking"
    log $LOG_LEVEL_INFO "Validating $module_name use case..."
    
    # Add detailed logging for debugging if needed
    log $LOG_LEVEL_DEBUG "Checking $module_name directory structure"
    
    local success=true
    
    if [[ ! -d "./usecases/ai/smart-parking" ]]; then
        log $LOG_LEVEL_ERROR "$module_name directory not found"
        success=false
    fi

    cd ./usecases/ai/smart-parking || {
        log $LOG_LEVEL_ERROR "Failed to change directory to $module_name"
        success=false
    }
    bash setup/generate-certs.sh || {
        log $LOG_LEVEL_ERROR "Failed to generate certificates for $module_name"
        success=false
    }

    wget https://videos.pexels.com/video-files/30937634/13228649_1920_1080_30fps.mp4 -O server/resources/carpark_video_1.mp4 || {
        log $LOG_LEVEL_ERROR "Failed to download video for $module_name"
        success=false
    }

    if [[ ! -f "docker-compose.yml" && ! -f "docker-compose.yaml" ]]; then
        log $LOG_LEVEL_ERROR "No docker-compose.yml or docker-compose.yaml found in $module_name"
        success=false
    fi
    sed -i "/DISPLAY=\${DISPLAY:?err}/s/^\([[:space:]]*\)/\1# /" docker-compose.yml

    # Build the module
    log $LOG_LEVEL_INFO "Building $module_name module..."
    docker compose build --no-cache || {
        log $LOG_LEVEL_ERROR "Failed to build $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Building $module_name module completed"

    # Run the module
    docker compose up -d || {
        log $LOG_LEVEL_ERROR "Failed to run $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Running $module_name module completed"

    sleep 5

    # Cleanup the module
    log $LOG_LEVEL_INFO "Cleaning up $module_name module..."
    docker compose down -v || {
        log $LOG_LEVEL_ERROR "Failed to clean up $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Cleaning up $module_name module completed"
    
    cd - || {
        log $LOG_LEVEL_ERROR "Failed to return to previous directory"
        success=false
    }
    
    # Record the validation result
    if [ "$success" = true ]; then
        record_validation "$module_name" "PASS"
    else
        record_validation "$module_name" "FAIL"
    fi
}

validate_digital_avatar() {
    local module_name="digital-avatar"
    log $LOG_LEVEL_INFO "Validating $module_name use case..."
    
    # Add detailed logging for debugging if needed
    log $LOG_LEVEL_DEBUG "Checking $module_name directory structure"
    
    local success=true
    
    if [[ ! -d "./usecases/ai/digital-avatar" ]]; then
        log $LOG_LEVEL_ERROR "$module_name directory not found"
        success=false
    fi
    # Check if video.mp4 exists, if not, download it
    if [[ ! -f "./.github/tests/assets/video.mp4" && ! -f "./.github/tests/assets/video.mp4" ]]; then
        log $LOG_LEVEL_ERROR "No video.mp4 found in $module_name"
        success=false
    fi
    cp -r ./.github/tests/assets/video.mp4 ./usecases/ai/digital-avatar/assets || {
        log $LOG_LEVEL_ERROR "Failed to copy video.mp4 to $module_name"
        success=false
    }
    cd ./usecases/ai/digital-avatar/weights || {
        log $LOG_LEVEL_ERROR "Failed to change directory to $module_name"
        success=false
    }
    # Always re-download wav2lip.pth
    if [[ -f "wav2lip.pth" ]]; then
        log $LOG_LEVEL_INFO "wav2lip.pth exists, removing before re-downloading"
        rm -f wav2lip.pth
    fi
    wget -O wav2lip.pth "https://huggingface.co/numz/wav2lip_studio/resolve/main/Wav2lip/wav2lip.pth?download=true" || {
        log $LOG_LEVEL_ERROR "Failed to download wav2lip.pth for $module_name"
        success=false
    }

    # Always re-download wav2lip_gan.pth
    if [[ -f "wav2lip_gan.pth" ]]; then
        log $LOG_LEVEL_INFO "wav2lip_gan.pth exists, removing before re-downloading"
        rm -f wav2lip_gan.pth
    fi
    wget -O wav2lip_gan.pth "https://huggingface.co/numz/wav2lip_studio/resolve/main/Wav2lip/wav2lip_gan.pth?download=true" || {
        log $LOG_LEVEL_ERROR "Failed to download wav2lip_gan.pth for $module_name"
        success=false
    }
    pwd
    cd ../ || {
        log $LOG_LEVEL_ERROR "Failed to change directory to $module_name"
        success=false
    }

    cp .env.template .env || {
        log $LOG_LEVEL_ERROR "Failed to copy .env.template to .env for $module_name"
        success=false
    }
    sed -i 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=Intel1234/' .env
    sed -i 's/^FRONTEND_PAYLOAD_SECRET=.*/FRONTEND_PAYLOAD_SECRET=Intel1234/' .env
    # Build the module
    log $LOG_LEVEL_INFO "Building $module_name module..."
    docker compose build --no-cache || {
        log $LOG_LEVEL_ERROR "Failed to build $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Building $module_name module completed"
    local render_gid
    render_gid=$(getent group render | cut -d: -f3)
    export RENDER_GROUP_ID="$render_gid"
    # Run the module
    docker compose up -d || {
        log $LOG_LEVEL_ERROR "Failed to run $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Running $module_name module completed"

    sleep 5

    # Cleanup the module
    log $LOG_LEVEL_INFO "Cleaning up $module_name module..."
    docker compose down -v || {
        log $LOG_LEVEL_ERROR "Failed to clean up $module_name module"
        success=false
    }
    log $LOG_LEVEL_INFO "Cleaning up $module_name module completed"
    
    cd - || {
        log $LOG_LEVEL_ERROR "Failed to return to previous directory"
        success=false
    }
    
    # Record the validation result
    if [ "$success" = true ]; then
        record_validation "$module_name" "PASS"
    else
        record_validation "$module_name" "FAIL"
    fi
}

# Display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -a, --all               Validate all use cases"
    echo "  -u, --usecase USECASE   Validate specific use case(s)"
    echo "                          Multiple use cases can be comma-separated"
    echo ""
    echo "Available use cases:"
    for usecase in "${AVAILABLE_USECASES[@]}"; do
        echo "  - $usecase"
    done
    echo ""
    echo "Examples:"
    echo "  $0 --all                Validate all use cases"
    echo "  $0 -u rag-toolkit       Validate only the rag-toolkit use case"
    echo "  $0 --usecase rag-toolkit,digital-avatar   Validate specific use cases"
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    SELECTED_USECASES=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--all)
                SELECTED_USECASES=("${AVAILABLE_USECASES[@]}")
                break
                ;;
            -u|--usecase)
                if [[ -z "$2" || "$2" == -* ]]; then
                    log $LOG_LEVEL_ERROR "Error: No use case provided with --usecase option"
                    show_usage
                    exit 1
                fi
                
                IFS=',' read -ra SPECIFIED_USECASES <<< "$2"
                for usecase in "${SPECIFIED_USECASES[@]}"; do
                    if [[ " ${AVAILABLE_USECASES[*]} " == *" $usecase "* ]]; then
                        SELECTED_USECASES+=("$usecase")
                    else
                        log $LOG_LEVEL_ERROR "Error: Unknown use case '$usecase'"
                        show_usage
                        exit 1
                    fi
                done
                shift
                ;;
            *)
                log $LOG_LEVEL_ERROR "Error: Unknown option '$1'"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    
    if [[ ${#SELECTED_USECASES[@]} -eq 0 ]]; then
        log $LOG_LEVEL_ERROR "Error: No valid use cases selected"
        show_usage
        exit 1
    fi
}

# Run validation for selected use cases
run_validations() {
    for usecase in "${SELECTED_USECASES[@]}"; do
        case "$usecase" in
            rag-toolkit)
                validate_rag_toolkit
                ;;
            ai-video-analytics)
                validate_ai_video_analytics
                ;;
            openwebui-ollama)
                validate_openwebui_ollama
                ;;
            smart-parking)
                validate_smart_parking
                ;;
            digital-avatar)
                validate_digital_avatar
                ;;
            # Additional use cases can be added here as they are implemented
            *)
                log $LOG_LEVEL_WARN "Warning: No validation function found for use case '$usecase'"
                ;;
        esac
    done
}

main() {
    log $LOG_LEVEL_INFO "Starting validation of use cases..."

    # Parse command line arguments
    parse_args "$@"
    
    # Clean up and prepare environment
    log $LOG_LEVEL_INFO "Cleaning up previous validation results..."
    rm -f "$REPORT_FILE"

    log $LOG_LEVEL_INFO "Previous validation results cleaned up"
    rm -rf "$LOG_DIR"

    log $LOG_LEVEL_INFO "Creating log directory..."
    mkdir -p "$LOG_DIR"
    
    # Run validations for selected use cases
    log $LOG_LEVEL_INFO "Selected use cases for validation: ${SELECTED_USECASES[*]}"
    run_validations
    
    # Generate the final report
    generate_report
    
    log $LOG_LEVEL_INFO "Validation complete"
}

# Pass command line arguments to main
main "$@"
