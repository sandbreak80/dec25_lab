# Common functions for AppDynamics VA deployment scripts

# Exit on error
set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

log_step() {
    echo ""
    echo -e "${CYAN}▶${NC} $1"
}

# SSH wrapper with error handling
ssh_exec() {
    local host=$1
    shift
    local cmd="$@"
    
    if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no appduser@"$host" "$cmd" 2>/dev/null; then
        log_error "SSH command failed on $host: $cmd"
        return 1
    fi
}

# SCP wrapper with error handling
scp_file() {
    local source=$1
    local dest=$2
    
    if ! scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$source" "$dest" 2>/dev/null; then
        log_error "SCP failed: $source -> $dest"
        return 1
    fi
}

# Wait for condition with timeout
wait_for() {
    local timeout=$1
    local interval=$2
    shift 2
    local cmd="$@"
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if eval "$cmd" 2>/dev/null; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Generate secure password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-"$length"
}

# Validate IP address
is_valid_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Prompt for confirmation
confirm() {
    local prompt="$1"
    local response
    
    read -p "$prompt [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' '-'
    printf "] %d%%" $percentage
}

# Spinner for long-running tasks
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Retry command with backoff
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local cmd="$@"
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then
            return 0
        fi
        
        log_warning "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_attempts attempts: $cmd"
    return 1
}

# Create backup
create_backup() {
    local file=$1
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$file" ]; then
        cp "$file" "$backup"
        log_success "Backup created: $backup"
    fi
}

# Validate YAML file
validate_yaml() {
    local file=$1
    
    if command_exists yq; then
        if yq eval "$file" > /dev/null 2>&1; then
            return 0
        else
            log_error "Invalid YAML: $file"
            return 1
        fi
    elif command_exists python3; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            return 0
        else
            log_error "Invalid YAML: $file"
            return 1
        fi
    else
        log_warning "No YAML validator available, skipping validation"
        return 0
    fi
}

# Get AWS instance details
get_aws_instance_ip() {
    local instance_id=$1
    local profile=${AWS_PROFILE:-default}
    
    aws --profile "$profile" ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text 2>/dev/null
}

# Export functions for use in other scripts
export -f log_info log_success log_error log_warning log_header log_step
export -f ssh_exec scp_file wait_for generate_password is_valid_ip
export -f command_exists confirm show_progress spinner retry
export -f create_backup validate_yaml get_aws_instance_ip
