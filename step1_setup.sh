#!/bin/bash

# =============================================================================
# STEP 1: Setup Structure + Tmux + Repo + Auto Ports
# =============================================================================

# Configuration
readonly BASE_DIR="/root/Nodes"
readonly NUM_NODES=10
readonly REPO_URL="https://github.com/gensyn-ai/rl-swarm.git"
readonly VENV_PATH="$HOME/rl-swarm-venv"

# Base ports (auto-assigned)
readonly BASE_P2P_PORT=30000
readonly BASE_API_PORT=8000
readonly BASE_COMM_PORT=40000
readonly BASE_WEB_PORT=3000

# Color codes
readonly GREEN="\033[32m\033[1m"
readonly RED="\033[31m\033[1m"
readonly YELLOW="\033[33m\033[1m"
readonly CYAN="\033[36m\033[1m"
readonly NC="\033[0m"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Step 1: Install Dependencies
# =============================================================================

install_dependencies() {
    log_info "📦 Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y tmux git python3-full python3-dev python3-venv python3-pip
    sudo apt install -y build-essential curl wget jq rsync tree
    
    log_info "✅ System dependencies installed"
}

# =============================================================================
# Step 2: Create Virtual Environment
# =============================================================================

create_virtual_environment() {
    if [[ -d "$VENV_PATH" ]]; then
        log_info "🐍 Virtual environment already exists: $VENV_PATH"
        return 0
    fi
    
    log_info "🐍 Creating virtual environment..."
    python3 -m venv "$VENV_PATH"
    
    # Activate and install packages
    source "$VENV_PATH/bin/activate"
    
    log_info "📦 Installing Python packages..."
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install PyTorch with CUDA support
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    
    # Install core ML packages
    pip install transformers>=4.36.0 trl>=0.7.0 accelerate>=0.21.0 datasets>=2.14.0
    
    # Install Gensyn packages
    pip install gensyn-genrl==0.1.4 reasoning-gym>=0.1.20
    pip install git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd
    
    # Install additional packages
    pip install wandb hydra-core omegaconf pydantic web3 requests numpy pandas scipy
    
    log_info "✅ Virtual environment and packages installed"
}

# =============================================================================
# Step 3: Create Directory Structure
# =============================================================================

create_directory_structure() {
    log_info "📁 Creating directory structure for $NUM_NODES nodes..."
    
    # Remove existing base directory if exists
    if [[ -d "$BASE_DIR" ]]; then
        log_warn "Directory $BASE_DIR already exists"
        read -p "Remove and recreate? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            rm -rf "$BASE_DIR"
            log_info "Removed existing directory"
        else
            log_error "Setup cancelled"
            exit 1
        fi
    fi
    
    # Create base directory
    mkdir -p "$BASE_DIR"
    
    # Create node directories
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/node-$i"
        
        log_info "📁 Creating Node $i directory: $node_dir"
        
        mkdir -p "$node_dir"
        mkdir -p "$node_dir/logs"
        mkdir -p "$node_dir/data"  # For manual data placement
        
        log_info "✅ Node $i directory structure created"
    done
    
    log_info "✅ All directories created"
}

# =============================================================================
# Step 4: Clone Repositories
# =============================================================================

clone_repositories() {
    log_info "📥 Cloning repositories for all nodes..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/node-$i"
        local repo_dir="$node_dir/rl-swarm"
        
        log_info "📥 Cloning repository for Node $i..."
        
        if git clone "$REPO_URL" "$repo_dir"; then
            log_info "✅ Node $i: Repository cloned successfully"
            
            # Create additional required directories in repo
            mkdir -p "$repo_dir/modal-login/temp-data"
            mkdir -p "$repo_dir/configs"
            mkdir -p "$repo_dir/logs"
            
        else
            log_error "❌ Node $i: Failed to clone repository"
            exit 1
        fi
    done
    
    log_info "✅ All repositories cloned"
}

# =============================================================================
# Step 5: Auto-Configure Ports
# =============================================================================

configure_ports() {
    log_info "🔧 Auto-configuring ports for all nodes..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/node-$i"
        local config_dir="$node_dir/rl-swarm/configs"
        local config_file="$config_dir/node-config.yaml"
        
        # Calculate ports for this node
        local p2p_port=$((BASE_P2P_PORT + i - 1))
        local api_port=$((BASE_API_PORT + i - 1))
        local comm_port=$((BASE_COMM_PORT + i - 1))
        local web_port=$((BASE_WEB_PORT + i - 1))
        
        log_info "🔧 Node $i ports: P2P=$p2p_port, API=$api_port, COMM=$comm_port, WEB=$web_port"
        
        # Create config with auto ports
        cat > "$config_file" << EOF
# Auto-generated config for Node $i
log_dir: $node_dir/logs

training:
  max_round: 100
  max_stage: 1
  num_generations: 2
  seed: $((42 + i))
  fp16: false

blockchain:
  alchemy_url: "https://gensyn-testnet.g.alchemy.com/public"
  contract_address: "0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
  org_id: null
  modal_proxy_url: "http://localhost:$web_port/api/"

communications:
  p2p_port: $p2p_port
  api_port: $api_port
  comm_port: $comm_port

game_manager:
  _target_: rgym_exp.src.manager.SwarmGameManager
  max_stage: 1
  max_round: 100
  log_dir: $node_dir/logs
  run_mode: "train_and_evaluate"
  
  trainer:
    _target_: rgym_exp.src.trainer.GRPOTrainerModule
    models:
      - _target_: transformers.AutoModelForCausalLM.from_pretrained
        pretrained_model_name_or_path: "Gensyn/Qwen2.5-1.5B-Instruct"
        torch_dtype: float32
        device_map: "cpu"
        low_cpu_mem_usage: true
    config:
      _target_: trl.trainer.GRPOConfig
      output_dir: "$node_dir/logs/checkpoints"
      logging_dir: $node_dir/logs
      per_device_train_batch_size: 1
      logging_steps: 10
      save_steps: 100
      num_train_epochs: 1
      run_name: "node_$i"
    num_generations: 2
    
  data_manager:
    _target_: rgym_exp.src.data.ReasoningGymDataManager
    num_train_samples: 1
    num_generations: 2
    seed: $((42 + i))
    
  communication:
    _target_: genrl.communication.hivemind.hivemind_backend.HivemindBackend
    identity_path: "$node_dir/rl-swarm/swarm.pem"
    startup_timeout: 120

# Node $i Configuration
# P2P Port: $p2p_port
# API Port: $api_port  
# Communication Port: $comm_port
# Web Port: $web_port
EOF
        
        log_info "✅ Node $i: Config created with auto ports"
    done
    
    log_info "✅ All ports configured"
}

# =============================================================================
# Step 6: Create Data Placement Guide
# =============================================================================

create_data_guide() {
    log_info "📋 Creating data placement guide..."
    
    cat > "$BASE_DIR/DATA_PLACEMENT_GUIDE.md" << 'EOF'
# Data Placement Guide

## Required Files for Each Node

Place your files in the following locations:

### Node 1:
```
/root/Nodes/node-1/rl-swarm/swarm.pem
/root/Nodes/node-1/rl-swarm/modal-login/temp-data/userData.json
/root/Nodes/node-1/rl-swarm/modal-login/temp-data/userApiKey.json
```

### Node 2:
```
/root/Nodes/node-2/rl-swarm/swarm.pem
/root/Nodes/node-2/rl-swarm/modal-login/temp-data/userData.json
/root/Nodes/node-2/rl-swarm/modal-login/temp-data/userApiKey.json
```

### Node 3-10:
Similar pattern for nodes 3 through 10...

## File Descriptions:

1. **swarm.pem**: Identity file (set permissions to 600)
2. **userData.json**: User authentication data
3. **userApiKey.json**: API key for authentication

## Quick Copy Commands:

If you have the same files for all nodes:
```bash
# Copy to all nodes (replace paths with your actual files)
for i in {1..10}; do
    cp /path/to/your/swarm.pem /root/Nodes/node-$i/rl-swarm/swarm.pem
    chmod 600 /root/Nodes/node-$i/rl-swarm/swarm.pem
    
    cp /path/to/your/userData.json /root/Nodes/node-$i/rl-swarm/modal-login/temp-data/
    cp /path/to/your/userApiKey.json /root/Nodes/node-$i/rl-swarm/modal-login/temp-data/
done
```

## Verification:

Check if files are placed correctly:
```bash
./verify_data_placement.sh
```
EOF
    
    log_info "✅ Data placement guide created: $BASE_DIR/DATA_PLACEMENT_GUIDE.md"
}

# =============================================================================
# Step 7: Create Verification Script
# =============================================================================

create_verification_script() {
    log_info "🔍 Creating data verification script..."
    
    cat > "$BASE_DIR/verify_data_placement.sh" << 'EOF'
#!/bin/bash

# Verify data placement for all nodes
NUM_NODES=10
BASE_DIR="/root/Nodes"

echo "🔍 Verifying data placement for all nodes..."
echo ""

all_good=true

for (( i=1; i<=NUM_NODES; i++ )); do
    node_dir="$BASE_DIR/node-$i"
    echo "Node $i:"
    
    # Check swarm.pem
    identity_file="$node_dir/rl-swarm/swarm.pem"
    if [[ -f "$identity_file" ]]; then
        perms=$(stat -c %a "$identity_file" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            echo "  ✅ swarm.pem (permissions: $perms)"
        else
            echo "  ⚠️  swarm.pem (wrong permissions: $perms, should be 600)"
            all_good=false
        fi
    else
        echo "  ❌ swarm.pem (missing)"
        all_good=false
    fi
    
    # Check userData.json
    userdata_file="$node_dir/rl-swarm/modal-login/temp-data/userData.json"
    if [[ -f "$userdata_file" ]]; then
        echo "  ✅ userData.json"
    else
        echo "  ❌ userData.json (missing)"
        all_good=false
    fi
    
    # Check userApiKey.json
    apikey_file="$node_dir/rl-swarm/modal-login/temp-data/userApiKey.json"
    if [[ -f "$apikey_file" ]]; then
        echo "  ✅ userApiKey.json"
    else
        echo "  ❌ userApiKey.json (missing)"
        all_good=false
    fi
    
    echo ""
done

if [[ "$all_good" == "true" ]]; then
    echo "🎉 All files are properly placed!"
    echo "Ready to run: ./run_and_manage.sh"
else
    echo "⚠️  Some files are missing. Please check the DATA_PLACEMENT_GUIDE.md"
fi
EOF
    
    chmod +x "$BASE_DIR/verify_data_placement.sh"
    log_info "✅ Verification script created"
}

# =============================================================================
# Step 8: Create Port Summary
# =============================================================================

create_port_summary() {
    log_info "📊 Creating port summary..."
    
    cat > "$BASE_DIR/PORT_SUMMARY.md" << 'EOF'
# Port Assignment Summary

## Port Ranges:
- P2P Ports: 30000-30009
- API Ports: 8000-8009  
- Communication Ports: 40000-40009
- Web Ports: 3000-3009

## Detailed Assignment:

| Node | P2P Port | API Port | Comm Port | Web Port |
|------|----------|----------|-----------|----------|
| 1    | 30000    | 8000     | 40000     | 3000     |
| 2    | 30001    | 8001     | 40001     | 3001     |
| 3    | 30002    | 8002     | 40002     | 3002     |
| 4    | 30003    | 8003     | 40003     | 3003     |
| 5    | 30004    | 8004     | 40004     | 3004     |
| 6    | 30005    | 8005     | 40005     | 3005     |
| 7    | 30006    | 8006     | 40006     | 3006     |
| 8    | 30007    | 8007     | 40007     | 3007     |
| 9    | 30008    | 8008     | 40008     | 3008     |
| 10   | 30009    | 8009     | 40009     | 3009     |

## Check Port Usage:
```bash
# Check if ports are in use
netstat -tulpn | grep -E ":(3000[0-9]|800[0-9]|4000[0-9]|300[0-9])"
```
EOF
    
    log_info "✅ Port summary created: $BASE_DIR/PORT_SUMMARY.md"
}

# =============================================================================
# Main Function
# =============================================================================

display_completion_summary() {
    echo ""
    echo -e "${CYAN}🎉 STEP 1 COMPLETED SUCCESSFULLY!${NC}"
    echo "=================================="
    echo ""
    echo "📁 Structure Created:"
    echo "   Base Directory: $BASE_DIR"
    echo "   Nodes: $NUM_NODES directories (node-1 to node-$NUM_NODES)"
    echo "   Virtual Environment: $VENV_PATH"
    echo ""
    echo "📦 Each Node Contains:"
    echo "   - rl-swarm/ (full repository)"
    echo "   - logs/ (for node logs)"  
    echo "   - data/ (for manual data placement)"
    echo ""
    echo "🔧 Auto-configured:"
    echo "   - Unique ports for each node"
    echo "   - Individual configs"
    echo "   - Python packages installed"
    echo ""
    echo "📋 Next Steps:"
    echo "============="
    echo ""
    echo "1. 📄 Read the data placement guide:"
    echo "   cat $BASE_DIR/DATA_PLACEMENT_GUIDE.md"
    echo ""
    echo "2. 📥 Place your data files manually in each node directory"
    echo ""
    echo "3. 🔍 Verify data placement:"
    echo "   cd $BASE_DIR && ./verify_data_placement.sh"
    echo ""
    echo "4. 🚀 When ready, I'll provide the run & manage script!"
    echo ""
    echo "📊 Port assignments: $BASE_DIR/PORT_SUMMARY.md"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Place your data files before proceeding to Step 2!${NC}"
}

main() {
    echo -e "${CYAN}"
    cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    STEP 1: SETUP STRUCTURE + TMUX + REPO + PORTS
    Preparing 10-node RL-Swarm environment...

EOF
    echo -e "$NC"
    
    log_info "🚀 Starting Step 1 setup..."
    echo ""
    
    install_dependencies
    echo ""
    
    create_virtual_environment  
    echo ""
    
    create_directory_structure
    echo ""
    
    clone_repositories
    echo ""
    
    configure_ports
    echo ""
    
    create_data_guide
    echo ""
    
    create_verification_script
    echo ""
    
    create_port_summary
    echo ""
    
    display_completion_summary
}

# Execute main function
main "$@"
