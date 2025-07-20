#!/bin/bash

# =============================================================================
# Fix OrgID and GPU Setup Script
# =============================================================================

# Color codes
readonly GREEN="\033[32m\033[1m"
readonly RED="\033[31m\033[1m"
readonly YELLOW="\033[33m\033[1m"
readonly CYAN="\033[36m\033[1m"
readonly NC="\033[0m"

readonly BASE_DIR="/root/Nodes"
readonly NUM_NODES="${NUM_NODES:-10}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix OrgID in userData.json
fix_orgid() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        log_error "Usage: fix_orgid <node_id>"
        return 1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    local user_data_file="$node_dir/modal-login/temp-data/userData.json"
    
    if [[ ! -f "$user_data_file" ]]; then
        log_error "userData.json not found: $user_data_file"
        return 1
    fi
    
    log_info "Checking userData.json for Node $node_id..."
    
    # Display current content
    echo -e "${CYAN}Current userData.json content:${NC}"
    cat "$user_data_file"
    echo ""
    
    # Check if orgId exists but is null/empty
    if command -v jq >/dev/null 2>&1; then
        local org_id=$(jq -r '.orgId // "null"' "$user_data_file" 2>/dev/null)
        local wallet=$(jq -r '.walletAddress // "null"' "$user_data_file" 2>/dev/null)
        
        echo -e "${CYAN}Parsed values:${NC}"
        echo "OrgID: $org_id"
        echo "Wallet: $wallet"
        echo ""
        
        if [[ "$org_id" == "null" || "$org_id" == "" ]]; then
            log_warn "OrgID is missing or null"
            
            # Try to extract from other fields
            local all_values=$(jq -r 'to_entries[] | "\(.key): \(.value)"' "$user_data_file" 2>/dev/null)
            echo -e "${CYAN}All fields in userData.json:${NC}"
            echo "$all_values"
            echo ""
            
            # Manual input if needed
            read -p "Enter OrgID manually (or press Enter to skip): " manual_orgid
            if [[ -n "$manual_orgid" ]]; then
                # Update userData.json with correct OrgID
                jq --arg orgid "$manual_orgid" '.orgId = $orgid' "$user_data_file" > "${user_data_file}.tmp"
                mv "${user_data_file}.tmp" "$user_data_file"
                log_info "✅ Updated OrgID to: $manual_orgid"
            fi
        else
            log_info "✅ OrgID found: $org_id"
        fi
    else
        # Fallback without jq
        log_warn "jq not found, using manual method"
        grep -E '"orgId"|"walletAddress"' "$user_data_file"
        echo ""
        read -p "Enter OrgID from the file above: " manual_orgid
        if [[ -n "$manual_orgid" ]]; then
            # Simple sed replacement (basic, assumes specific format)
            sed -i "s/\"orgId\":\s*\"[^\"]*\"/\"orgId\": \"$manual_orgid\"/" "$user_data_file"
            log_info "✅ Updated OrgID to: $manual_orgid"
        fi
    fi
}

# Fix OrgID for all nodes
fix_all_orgids() {
    log_info "Fixing OrgID for all nodes..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        echo -e "${CYAN}Node $i:${NC}"
        fix_orgid "$i"
        echo ""
    done
}

# Install NVIDIA drivers
install_nvidia_drivers() {
    log_info "Installing NVIDIA drivers..."
    
    # Detect Ubuntu version
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        ubuntu_version=$(echo $VERSION_ID | tr -d '.')
    else
        log_error "Cannot detect Ubuntu version"
        return 1
    fi
    
    log_info "Detected Ubuntu $VERSION_ID"
    
    # Add NVIDIA repository
    log_info "Adding NVIDIA repository..."
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${ubuntu_version}/x86_64/cuda-keyring_1.0-1_all.deb
    sudo dpkg -i cuda-keyring_1.0-1_all.deb
    sudo apt update
    
    # Install NVIDIA drivers
    log_info "Installing NVIDIA drivers and CUDA..."
    sudo apt install -y nvidia-driver-535 nvidia-dkms-535
    sudo apt install -y cuda-toolkit-12-2
    
    # Install additional CUDA libraries
    sudo apt install -y nvidia-cuda-toolkit
    
    log_info "✅ NVIDIA drivers installation completed"
    log_warn "⚠️ System reboot required to load NVIDIA drivers"
    
    # Check if drivers are loaded
    if command -v nvidia-smi >/dev/null 2>&1; then
        log_info "✅ nvidia-smi available"
        nvidia-smi
    else
        log_warn "nvidia-smi not yet available (reboot required)"
    fi
}

# Alternative: Install NVIDIA drivers via ubuntu-drivers
install_nvidia_auto() {
    log_info "Auto-installing NVIDIA drivers via ubuntu-drivers..."
    
    # Install ubuntu-drivers
    sudo apt update
    sudo apt install -y ubuntu-drivers-common
    
    # Detect available drivers
    log_info "Detecting available NVIDIA drivers..."
    ubuntu-drivers devices
    
    # Auto-install recommended driver
    log_info "Installing recommended NVIDIA driver..."
    sudo ubuntu-drivers autoinstall
    
    log_info "✅ NVIDIA driver auto-installation completed"
    log_warn "⚠️ System reboot required"
}

# Check GPU after driver installation
check_gpu_status() {
    log_info "Checking GPU status..."
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        log_info "✅ nvidia-smi found"
        echo ""
        nvidia-smi
        echo ""
        
        # Test PyTorch CUDA in virtual environment
        if [[ -n "$VIRTUAL_ENV" ]]; then
            log_info "Testing PyTorch CUDA in virtual environment..."
            python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU device: {torch.cuda.get_device_name(0)}')
    print(f'GPU memory: {torch.cuda.get_device_properties(0).total_memory // 1024**3}GB')
else:
    print('CUDA not available in PyTorch')
"
        else
            log_warn "Virtual environment not activated"
        fi
    else
        log_error "❌ nvidia-smi not found"
        log_info "GPU drivers may not be installed or loaded"
    fi
}

# Create a sample userData.json template
create_userdata_template() {
    log_info "Creating userData.json template..."
    
    cat > userData_template.json << 'EOF'
{
    "walletAddress": "0x1234567890abcdef1234567890abcdef12345678",
    "orgId": "your-org-id-here",
    "apiKey": "your-api-key-here",
    "userId": "your-user-id-here",
    "timestamp": 1234567890
}
EOF
    
    log_info "✅ Created userData_template.json"
    echo ""
    echo "Edit this template and copy to your nodes if needed:"
    echo "cp userData_template.json /root/Nodes/rl-swarm-1/modal-login/temp-data/userData.json"
}

# Test node launch without GPU (CPU mode)
test_cpu_mode() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        node_id=1
    fi
    
    log_info "Testing Node $node_id in CPU mode..."
    
    # Check if virtual environment is activated
    if [[ -z "$VIRTUAL_ENV" ]]; then
        log_error "Virtual environment not activated!"
        log_info "Run: source activate_rl_swarm.sh"
        return 1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    cd "$node_dir" || {
        log_error "Node directory not found: $node_dir"
        return 1
    }
    
    # Extract ORG_ID
    local org_id=$(python -c "
import json
try:
    with open('modal-login/temp-data/userData.json', 'r') as f:
        data = json.load(f)
    print(data.get('orgId', ''))
except:
    print('')
" 2>/dev/null)
    
    if [[ -z "$org_id" || "$org_id" == "null" ]]; then
        log_error "OrgID still missing! Fix userData.json first"
        return 1
    fi
    
    # Set environment for CPU mode
    export NODE_ID="$node_id"
    export ORG_ID="$org_id"
    export IDENTITY_PATH="$node_dir/swarm.pem"
    export CUDA_VISIBLE_DEVICES=""  # Disable GPU
    export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
    
    log_info "Environment set for CPU mode:"
    echo "   NODE_ID: $NODE_ID"
    echo "   ORG_ID: $ORG_ID"
    echo "   CUDA_VISIBLE_DEVICES: (disabled)"
    echo ""
    
    # Test import first
    log_info "Testing imports..."
    python -c "
import sys
print(f'Python: {sys.executable}')

try:
    import torch
    print(f'PyTorch: {torch.__version__}')
    print(f'CUDA available: {torch.cuda.is_available()}')
    
    import transformers
    print(f'Transformers: {transformers.__version__}')
    
    import trl
    print(f'TRL: {trl.__version__}')
    
    print('✅ All imports successful')
except ImportError as e:
    print(f'❌ Import error: {e}')
    sys.exit(1)
"
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ Imports successful, trying to launch node..."
        
        # Try to launch (will show immediate errors)
        timeout 30 python -m rgym_exp.runner.swarm_launcher \
            --config-path configs \
            --config-name rg-swarm.yaml || log_warn "Node launch test completed (30s timeout)"
    else
        log_error "❌ Import test failed"
    fi
    
    cd - >/dev/null
}

# Show usage
show_usage() {
    echo "Fix OrgID and GPU Setup Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  fix-orgid <node_id>      Fix OrgID for specific node"
    echo "  fix-all-orgids           Fix OrgID for all nodes"
    echo "  install-nvidia           Install NVIDIA drivers manually"
    echo "  install-nvidia-auto      Auto-install NVIDIA drivers"
    echo "  check-gpu                Check GPU status"
    echo "  create-template          Create userData.json template"
    echo "  test-cpu <node_id>       Test node launch in CPU mode"
    echo ""
    echo "Examples:"
    echo "  $0 fix-orgid 1           # Fix OrgID for Node 1"
    echo "  $0 fix-all-orgids        # Fix OrgID for all nodes"
    echo "  $0 install-nvidia-auto   # Auto-install NVIDIA drivers"
    echo "  $0 test-cpu 1            # Test Node 1 in CPU mode"
}

# Main function
main() {
    local command="$1"
    local node_id="$2"
    
    case "$command" in
        "fix-orgid")
            fix_orgid "$node_id"
            ;;
        "fix-all-orgids")
            fix_all_orgids
            ;;
        "install-nvidia")
            install_nvidia_drivers
            ;;
        "install-nvidia-auto")
            install_nvidia_auto
            ;;
        "check-gpu")
            check_gpu_status
            ;;
        "create-template")
            create_userdata_template
            ;;
        "test-cpu")
            test_cpu_mode "$node_id"
            ;;
        "help"|"--help"|"-h"|"")
            show_usage
            ;;
        *)
            echo "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main
main "$@"
