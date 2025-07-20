#!/bin/bash

# =============================================================================
# Virtual Environment Setup for RL-Swarm (Python 3.12 Compatible)
# =============================================================================

# Color codes
readonly GREEN="\033[32m\033[1m"
readonly RED="\033[31m\033[1m"
readonly YELLOW="\033[33m\033[1m"
readonly CYAN="\033[36m\033[1m"
readonly NC="\033[0m"

# Configuration
readonly VENV_PATH="$HOME/rl-swarm-venv"
readonly REQUIREMENTS_FILE="requirements.txt"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Install system dependencies
install_system_dependencies() {
    log_step "Step 1: Installing system dependencies"
    
    log_info "Updating package list..."
    sudo apt update
    
    log_info "Installing Python development packages..."
    sudo apt install -y python3-full python3-dev python3-venv python3-pip
    
    log_info "Installing build essentials..."
    sudo apt install -y build-essential git curl wget
    
    log_info "Installing additional development tools..."
    sudo apt install -y pkg-config libffi-dev libssl-dev
    
    log_info "✅ System dependencies installed"
}

# Create virtual environment
create_virtual_environment() {
    log_step "Step 2: Creating virtual environment"
    
    if [[ -d "$VENV_PATH" ]]; then
        log_warn "Virtual environment already exists at $VENV_PATH"
        read -p "Remove and recreate? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_PATH"
        else
            log_info "Using existing virtual environment"
            return 0
        fi
    fi
    
    log_info "Creating virtual environment at $VENV_PATH..."
    python3 -m venv "$VENV_PATH"
    
    if [[ -d "$VENV_PATH" ]]; then
        log_info "✅ Virtual environment created successfully"
    else
        log_error "❌ Failed to create virtual environment"
        exit 1
    fi
}

# Activate virtual environment
activate_venv() {
    log_info "Activating virtual environment..."
    source "$VENV_PATH/bin/activate"
    
    # Verify activation
    if [[ "$VIRTUAL_ENV" == "$VENV_PATH" ]]; then
        log_info "✅ Virtual environment activated"
        log_info "Python: $(which python)"
        log_info "Pip: $(which pip)"
    else
        log_error "❌ Failed to activate virtual environment"
        exit 1
    fi
}

# Create requirements file
create_requirements_file() {
    log_step "Step 3: Creating requirements file"
    
    cat > "$REQUIREMENTS_FILE" << 'EOF'
# Core ML packages
torch>=2.0.0
torchvision>=0.15.0
torchaudio>=2.0.0
transformers>=4.36.0
accelerate>=0.21.0
datasets>=2.14.0

# TRL and related
trl>=0.7.0
peft>=0.6.0

# Gensyn packages
gensyn-genrl==0.1.4
reasoning-gym>=0.1.20

# Hivemind (custom version)
git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd

# Configuration and utilities
hydra-core>=1.3.0
omegaconf>=2.3.0
wandb>=0.15.0
pydantic>=2.0.0

# Web3 and blockchain
web3>=6.0.0
requests>=2.28.0

# Scientific computing
numpy>=1.24.0
pandas>=2.0.0
scipy>=1.10.0

# Additional utilities
psutil>=5.9.0
colorama>=0.4.6
tqdm>=4.64.0
python-dotenv>=1.0.0
PyYAML>=6.0
jinja2>=3.1.0
EOF
    
    log_info "✅ Requirements file created: $REQUIREMENTS_FILE"
}

# Install packages in virtual environment
install_packages() {
    log_step "Step 4: Installing packages in virtual environment"
    
    # Activate if not already activated
    if [[ -z "$VIRTUAL_ENV" ]]; then
        activate_venv
    fi
    
    log_info "Upgrading pip..."
    pip install --upgrade pip
    
    log_info "Installing PyTorch with CUDA support..."
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    
    log_info "Installing packages from requirements file..."
    pip install -r "$REQUIREMENTS_FILE"
    
    log_info "✅ All packages installed in virtual environment"
}

# Test installation
test_installation() {
    log_step "Step 5: Testing installation"
    
    # Activate if not already activated
    if [[ -z "$VIRTUAL_ENV" ]]; then
        activate_venv
    fi
    
    log_info "Testing core imports..."
    
    python << 'EOF'
import sys
print(f"Python executable: {sys.executable}")
print(f"Virtual environment: {sys.prefix}")
print()

try:
    import torch
    print(f"✅ PyTorch {torch.__version__}")
    print(f"✅ CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"✅ GPU device: {torch.cuda.get_device_name(0)}")
        gpu_memory = torch.cuda.get_device_properties(0).total_memory // 1024**3
        print(f"✅ GPU memory: {gpu_memory}GB")
    
    import transformers
    print(f"✅ Transformers {transformers.__version__}")
    
    import trl
    print(f"✅ TRL {trl.__version__}")
    
    import hivemind
    print(f"✅ Hivemind {hivemind.__version__}")
    
    import hydra
    print(f"✅ Hydra {hydra.__version__}")
    
    print("\n🎉 All packages working in virtual environment!")
    
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)
EOF
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ Installation test passed!"
    else
        log_error "❌ Installation test failed!"
        exit 1
    fi
}

# Create activation scripts
create_activation_scripts() {
    log_step "Step 6: Creating activation scripts"
    
    # Create activation script
    cat > activate_rl_swarm.sh << EOF
#!/bin/bash

# RL-Swarm Virtual Environment Activation Script
echo "🐍 Activating RL-Swarm virtual environment..."

# Activate virtual environment
source "$VENV_PATH/bin/activate"

# Verify activation
if [[ "\$VIRTUAL_ENV" == "$VENV_PATH" ]]; then
    echo "✅ Virtual environment activated!"
    echo "Python: \$(which python)"
    echo "Pip: \$(which pip)"
    echo ""
    echo "You can now run:"
    echo "  - ./separate_nodes_setup.sh setup"
    echo "  - ./batch_copy_helper.sh copy-all ..."
    echo "  - ./launch_node_venv.sh <node_id>"
    echo ""
    echo "To deactivate: deactivate"
else
    echo "❌ Failed to activate virtual environment"
    exit 1
fi
EOF
    
    chmod +x activate_rl_swarm.sh
    log_info "✅ Created activate_rl_swarm.sh"
    
    # Create venv-compatible node launcher
    cat > launch_node_venv.sh << EOF
#!/bin/bash

# Virtual Environment Node Launcher
NODE_ID="\$1"
BASE_DIR="/root/Nodes"

if [[ -z "\$NODE_ID" ]]; then
    echo "Usage: \$0 <node_id>"
    echo "Make sure to activate venv first: source activate_rl_swarm.sh"
    exit 1
fi

# Check if virtual environment is activated
if [[ -z "\$VIRTUAL_ENV" ]]; then
    echo "❌ Virtual environment not activated!"
    echo "Run: source activate_rl_swarm.sh"
    exit 1
fi

NODE_DIR="\$BASE_DIR/rl-swarm-\$NODE_ID"

if [[ ! -d "\$NODE_DIR" ]]; then
    echo "❌ Node directory not found: \$NODE_DIR"
    exit 1
fi

echo "🚀 Launching Node \$NODE_ID with virtual environment..."
echo "🐍 Using: \$VIRTUAL_ENV"

# Change to node directory
cd "\$NODE_DIR" || exit 1

# Extract ORG_ID
ORG_ID=\$(python -c "
import json
try:
    with open('modal-login/temp-data/userData.json', 'r') as f:
        data = json.load(f)
    print(data.get('orgId', ''))
except:
    print('')
" 2>/dev/null)

# Set environment variables
export NODE_ID="\$NODE_ID"
export ORG_ID="\$ORG_ID"
export IDENTITY_PATH="\$NODE_DIR/swarm.pem"
export CUDA_VISIBLE_DEVICES=0
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export PYTHONPATH="\$NODE_DIR:\$PYTHONPATH"

echo "🔧 Environment:"
echo "   NODE_ID: \$NODE_ID"
echo "   ORG_ID: \$ORG_ID"
echo "   VIRTUAL_ENV: \$VIRTUAL_ENV"
echo ""

# Create logs directory
mkdir -p logs

# Launch node
LOG_FILE="logs/swarm_launcher.log"
echo "📝 Log file: \$LOG_FILE"

python -m rgym_exp.runner.swarm_launcher \\
    --config-path configs \\
    --config-name rg-swarm.yaml \\
    > "\$LOG_FILE" 2>&1 &

PID=\$!
echo \$PID > logs/node.pid

echo "✅ Node \$NODE_ID started (PID: \$PID)"
echo "📊 Monitor with: tail -f \$NODE_DIR/\$LOG_FILE"

cd - >/dev/null
EOF
    
    chmod +x launch_node_venv.sh
    log_info "✅ Created launch_node_venv.sh"
    
    # Create launch all nodes script
    cat > launch_all_nodes_venv.sh << 'EOF'
#!/bin/bash

# Launch all nodes with virtual environment
NUM_NODES="${NUM_NODES:-10}"

# Check if virtual environment is activated
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "❌ Virtual environment not activated!"
    echo "Run: source activate_rl_swarm.sh"
    exit 1
fi

echo "🚀 Launching $NUM_NODES nodes with virtual environment..."
echo "🐍 Using: $VIRTUAL_ENV"
echo ""

for (( i=1; i<=NUM_NODES; i++ )); do
    echo "Launching Node $i..."
    ./launch_node_venv.sh $i
    sleep 3
done

echo ""
echo "✅ All $NUM_NODES nodes launched!"
echo "Check status with: ./check_nodes_status.sh"
EOF
    
    chmod +x launch_all_nodes_venv.sh
    log_info "✅ Created launch_all_nodes_venv.sh"
    
    # Create status checker
    cat > check_nodes_status.sh << 'EOF'
#!/bin/bash

# Check status of all nodes
NUM_NODES="${NUM_NODES:-10}"
BASE_DIR="/root/Nodes"

echo "📊 Node Status Report"
echo "===================="
echo ""

running=0
for (( i=1; i<=NUM_NODES; i++ )); do
    node_dir="$BASE_DIR/rl-swarm-$i"
    pid_file="$node_dir/logs/node.pid"
    
    if [[ -f "$pid_file" ]]; then
        pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            cpu=$(ps -p "$pid" -o %cpu --no-headers | tr -d ' ')
            mem=$(ps -p "$pid" -o %mem --no-headers | tr -d ' ')
            echo "✅ Node $i: Running (PID: $pid) CPU: ${cpu}% MEM: ${mem}%"
            running=$((running + 1))
        else
            echo "❌ Node $i: Dead (PID file exists but process stopped)"
        fi
    else
        echo "⭕ Node $i: Not started"
    fi
done

echo ""
echo "📈 Summary: $running/$NUM_NODES nodes running"

# GPU status
if command -v nvidia-smi >/dev/null 2>&1; then
    echo ""
    echo "🎮 GPU Status:"
    nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits | while read memory_used memory_total gpu_util; do
        memory_percent=$((memory_used * 100 / memory_total))
        echo "   Memory: ${memory_used}MB/${memory_total}MB (${memory_percent}%) | Utilization: ${gpu_util}%"
    done
fi
EOF
    
    chmod +x check_nodes_status.sh
    log_info "✅ Created check_nodes_status.sh"
}

# Update existing scripts for venv
update_scripts_for_venv() {
    log_step "Step 7: Updating existing scripts for virtual environment"
    
    # Update debug script
    if [[ -f "debug_node.sh" ]]; then
        # Create venv-compatible version
        cp debug_node.sh debug_node_venv.sh
        
        # Add venv check at the top
        sed -i '1a\\n# Check virtual environment\nif [[ -z "$VIRTUAL_ENV" ]]; then\n    echo "❌ Virtual environment not activated!"\n    echo "Run: source activate_rl_swarm.sh"\n    exit 1\nfi\n' debug_node_venv.sh
        
        log_info "✅ Created debug_node_venv.sh"
    fi
    
    log_info "✅ Scripts updated for virtual environment"
}

# Main function
main() {
    echo -e "${CYAN}"
    cat << "EOF"
    🐍 VIRTUAL ENVIRONMENT SETUP
    RL-Swarm for Python 3.12 (Externally Managed)
    
EOF
    echo -e "$NC"
    
    log_info "Setting up RL-Swarm with virtual environment..."
    echo ""
    
    # Install system dependencies
    install_system_dependencies
    echo ""
    
    # Create virtual environment
    create_virtual_environment
    echo ""
    
    # Activate virtual environment
    activate_venv
    echo ""
    
    # Create requirements
    create_requirements_file
    echo ""
    
    # Install packages
    install_packages
    echo ""
    
    # Test installation
    test_installation
    echo ""
    
    # Create scripts
    create_activation_scripts
    echo ""
    
    # Update existing scripts
    update_scripts_for_venv
    echo ""
    
    log_info "🎉 Virtual environment setup completed!"
    echo ""
    echo "📋 Usage Instructions:"
    echo "==============================="
    echo ""
    echo "1. Activate virtual environment:"
    echo "   source activate_rl_swarm.sh"
    echo ""
    echo "2. Setup node directories:"
    echo "   ./separate_nodes_setup.sh setup"
    echo ""
    echo "3. Copy your files:"
    echo "   ./batch_copy_helper.sh copy-all /path/to/swarm.pem /path/to/userData.json /path/to/userApiKey.json"
    echo ""
    echo "4. Launch nodes:"
    echo "   ./launch_all_nodes_venv.sh"
    echo "   # Or launch individual: ./launch_node_venv.sh 1"
    echo ""
    echo "5. Check status:"
    echo "   ./check_nodes_status.sh"
    echo ""
    echo "6. Debug if needed:"
    echo "   ./debug_node_venv.sh logs 1"
    echo ""
    echo "💡 Remember to ALWAYS activate the virtual environment first!"
    echo "   Virtual environment path: $VENV_PATH"
}

# Show usage
show_usage() {
    echo "Virtual Environment Setup for RL-Swarm"
    echo ""
    echo "This script creates a Python virtual environment and installs"
    echo "all required packages for RL-Swarm multi-node setup."
    echo ""
    echo "Solves the 'externally-managed-environment' issue in Python 3.12+"
    echo ""
    echo "Usage: $0 [--help]"
}

# Check for help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# Execute main
main "$@"
