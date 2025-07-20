#!/bin/bash

# =============================================================================
# Python3 Compatible Environment Setup for RL-Swarm
# =============================================================================

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

# Detect Python command
detect_python() {
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
        PIP_CMD="pip3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
        PIP_CMD="pip"
    else
        log_error "No Python found. Please install Python3."
        exit 1
    fi
    
    log_info "Using Python command: $PYTHON_CMD"
    log_info "Python version: $($PYTHON_CMD --version)"
}

# Check Python version
check_python_version() {
    local python_version=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local major=$(echo $python_version | cut -d. -f1)
    local minor=$(echo $python_version | cut -d. -f2)
    
    if [[ $major -eq 3 ]] && [[ $minor -ge 8 ]]; then
        log_info "✅ Python version $python_version is compatible"
        return 0
    else
        log_error "❌ Python version $python_version is too old. Need Python 3.8+"
        return 1
    fi
}

# Install dependencies with python3
install_dependencies() {
    log_info "Installing dependencies with $PYTHON_CMD and $PIP_CMD..."
    
    # Upgrade pip
    $PYTHON_CMD -m pip install --upgrade pip
    
    # Install PyTorch with CUDA
    log_info "Installing PyTorch with CUDA support..."
    $PIP_CMD install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    
    # Install core packages
    log_info "Installing core ML packages..."
    $PIP_CMD install transformers>=4.36.0
    $PIP_CMD install trl>=0.7.0
    $PIP_CMD install accelerate>=0.21.0
    $PIP_CMD install datasets>=2.14.0
    
    # Install Gensyn packages
    log_info "Installing Gensyn packages..."
    $PIP_CMD install gensyn-genrl==0.1.4
    $PIP_CMD install reasoning-gym>=0.1.20
    
    # Install Hivemind
    log_info "Installing Hivemind..."
    $PIP_CMD install git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd
    
    # Install additional dependencies
    log_info "Installing additional dependencies..."
    $PIP_CMD install wandb>=0.15.0 hydra-core>=1.3.0 omegaconf>=2.3.0
    $PIP_CMD install pydantic>=2.0.0 web3>=6.0.0 requests>=2.28.0
    $PIP_CMD install numpy>=1.24.0 pandas>=2.0.0 scipy>=1.10.0
    
    log_info "✅ All dependencies installed"
}

# Test installation
test_installation() {
    log_info "Testing installation..."
    
    # Test imports
    $PYTHON_CMD << 'EOF'
try:
    import torch
    print(f"✅ PyTorch {torch.__version__}")
    print(f"✅ CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"✅ GPU device: {torch.cuda.get_device_name(0)}")
        print(f"✅ GPU memory: {torch.cuda.get_device_properties(0).total_memory // 1024**3}GB")
    
    import transformers
    print(f"✅ Transformers {transformers.__version__}")
    
    import trl
    print(f"✅ TRL {trl.__version__}")
    
    try:
        import hivemind
        print(f"✅ Hivemind {hivemind.__version__}")
    except ImportError:
        print("⚠️ Hivemind import failed (may need restart)")
    
    print("\n🎉 Core dependencies working!")
    
except ImportError as e:
    print(f"❌ Import error: {e}")
    exit(1)
EOF
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ Installation test passed!"
        return 0
    else
        log_error "❌ Installation test failed!"
        return 1
    fi
}

# Update existing scripts to use python3
update_scripts_for_python3() {
    log_info "Updating scripts to use python3..."
    
    # Update debug_node.sh
    if [[ -f "debug_node.sh" ]]; then
        sed -i 's/python --version/python3 --version/g' debug_node.sh
        sed -i 's/python -c/python3 -c/g' debug_node.sh
        sed -i 's/python -m/python3 -m/g' debug_node.sh
        log_info "✅ Updated debug_node.sh"
    fi
    
    # Update separate_nodes_setup.sh
    if [[ -f "separate_nodes_setup.sh" ]]; then
        sed -i 's/python -m/python3 -m/g' separate_nodes_setup.sh
        sed -i 's/python -c/python3 -c/g' separate_nodes_setup.sh
        log_info "✅ Updated separate_nodes_setup.sh"
    fi
    
    # Create python3 compatible config template
    create_python3_config_template
}

# Create python3 compatible config template  
create_python3_config_template() {
    log_info "Creating python3 compatible node config template..."
    
    cat > python3_node_config_template.yaml << 'EOF'
log_dir: NODE_DIR/logs

training:
  max_round: 1000000
  max_stage: 1
  hf_push_frequency: 10
  num_generations: 1
  num_transplant_trees: 1
  seed: 42
  fp16: true

blockchain:
  alchemy_url: "https://gensyn-testnet.g.alchemy.com/public"
  contract_address: ${oc.env:SWARM_CONTRACT,"0xFaD7C5e93f28257429569B854151A1B8DCD404c2"}
  org_id: ${oc.env:ORG_ID,null}
  mainnet_chain_id: 685685
  modal_proxy_url: "http://localhost:WEB_PORT/api/"

communications:
  p2p_port: P2P_PORT
  api_port: API_PORT
  comm_port: COMM_PORT
  initial_peers:
    - '/ip4/127.0.0.1/tcp/30000/p2p/${oc.env:NODE_0_PEER_ID,QmDefaultPeer0}'
    - '/ip4/127.0.0.1/tcp/30001/p2p/${oc.env:NODE_1_PEER_ID,QmDefaultPeer1}'
    - '/ip4/127.0.0.1/tcp/30002/p2p/${oc.env:NODE_2_PEER_ID,QmDefaultPeer2}'
    - '/ip4/38.101.215.12/tcp/30011/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ'
    - '/ip4/38.101.215.13/tcp/30012/p2p/QmWhiaLrx3HRZfgXc2i7KW5nMUNK7P9tRc71yFJdGEZKkC'
    - '/ip4/38.101.215.14/tcp/30013/p2p/QmQa1SCfYTxx7RvU7qJJRo79Zm1RAwPpkeLueDVJuBBmFp'

eval:
  judge_base_url: https://swarm-judge-102957787771.us-east1.run.app

hydra:
  run:
    dir: NODE_DIR/logs

game_manager:
  _target_: rgym_exp.src.manager.SwarmGameManager
  max_stage: ${training.max_stage}
  max_round: ${training.max_round}
  log_dir: NODE_DIR/logs
  hf_token: ${oc.env:HUGGINGFACE_ACCESS_TOKEN,null}
  hf_push_frequency: ${training.hf_push_frequency}
  run_mode: "train_and_evaluate"
  bootnodes: ${communications.initial_peers}
  
  game_state: 
    _target_: genrl.state.game_state.GameState
    round: 0
    stage: 0
    
  reward_manager:
    _target_: genrl.rewards.DefaultRewardManager
    reward_fn_store:
      _target_: genrl.rewards.reward_store.RewardFnStore
      max_rounds: ${training.max_round}
      reward_fn_stores:
        - _target_: genrl.rewards.reward_store.RoundRewardFnStore
          num_stages: ${training.max_stage}
          reward_fns:
            - _target_: rgym_exp.src.rewards.RGRewards
            
  trainer:
    _target_: rgym_exp.src.trainer.GRPOTrainerModule
    models:
      - _target_: transformers.AutoModelForCausalLM.from_pretrained
        pretrained_model_name_or_path: "Gensyn/Qwen2.5-1.5B-Instruct"
        torch_dtype: float16
        device_map: "auto"
        low_cpu_mem_usage: true
        max_memory: {0: "8GB"}
    config:
      _target_: trl.trainer.GRPOConfig
      logging_dir: NODE_DIR/logs
      fp16: ${training.fp16}
      per_device_train_batch_size: 1
      per_device_eval_batch_size: 1
      gradient_accumulation_steps: 2
      dataloader_num_workers: 2
      logging_steps: 50
      save_steps: 1000
      eval_steps: 500
      max_length: 1024
      max_new_tokens: 256
      output_dir: "NODE_DIR/logs/checkpoints"
      run_name: "node_NODE_ID"
    log_with: wandb
    log_dir: NODE_DIR/logs
    epsilon: 0.2
    epsilon_high: 0.28
    num_generations: ${training.num_generations}
    judge_base_url: ${eval.judge_base_url}
    
  data_manager:
    _target_: rgym_exp.src.data.ReasoningGymDataManager
    yaml_config_path: "rgym_exp/src/datasets.yaml"
    num_train_samples: 1
    num_evaluation_samples: 0
    num_generations: ${training.num_generations}
    system_prompt_id: 'default'
    seed: ${training.seed}
    num_transplant_trees: ${training.num_transplant_trees}
    
  communication:
    _target_: genrl.communication.hivemind.hivemind_backend.HivemindBackend
    initial_peers: ${communications.initial_peers}
    identity_path: "NODE_DIR/swarm.pem"
    startup_timeout: 180
    beam_size: 20
    averaging_timeout: 30.0
    compression: true
    host_maddrs: ["/ip4/0.0.0.0/tcp/P2P_PORT"]
    announce_maddrs: ["/ip4/127.0.0.1/tcp/P2P_PORT"]
    
  coordinator:
    _target_: genrl.blockchain.coordinator.ModalSwarmCoordinator
    web3_url: ${blockchain.alchemy_url}
    contract_address: ${blockchain.contract_address}
    org_id: ${blockchain.org_id}
    modal_proxy_url: ${blockchain.modal_proxy_url}

# Resource limits for H100
resource_limits:
  cpu_per_node: 2
  memory_per_node: "24GB"
  gpu_memory_per_node: "8GB"

default_large_model_pool: 
  - "Gensyn/Qwen2.5-1.5B-Instruct"
  
default_small_model_pool:
  - "Gensyn/Qwen2.5-1.5B-Instruct"
EOF

    log_info "✅ Created python3 config template"
}

# Quick test with python3
quick_test() {
    log_info "Quick test with python3..."
    
    # Test basic Python
    $PYTHON_CMD --version
    
    # Test pip
    $PIP_CMD --version
    
    # Test if we can install a simple package
    $PIP_CMD install requests --quiet
    
    # Test imports
    $PYTHON_CMD -c "
import sys
print(f'Python executable: {sys.executable}')
print(f'Python version: {sys.version}')
print(f'Python path: {sys.path[0]}')

try:
    import requests
    print('✅ Basic imports working')
except ImportError as e:
    print(f'❌ Import error: {e}')
"
}

# Create python3 launcher script
create_python3_launcher() {
    log_info "Creating python3 compatible launcher..."
    
    cat > launch_node_python3.sh << 'EOF'
#!/bin/bash

# Python3 compatible node launcher
NODE_ID="$1"
BASE_DIR="/root/Nodes"

if [[ -z "$NODE_ID" ]]; then
    echo "Usage: $0 <node_id>"
    exit 1
fi

NODE_DIR="$BASE_DIR/rl-swarm-$NODE_ID"

if [[ ! -d "$NODE_DIR" ]]; then
    echo "Node directory not found: $NODE_DIR"
    exit 1
fi

echo "🚀 Launching Node $NODE_ID with python3..."

# Change to node directory
cd "$NODE_DIR" || exit 1

# Extract ORG_ID
ORG_ID=""
if [[ -f "modal-login/temp-data/userData.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
        ORG_ID=$(jq -r '.orgId // ""' "modal-login/temp-data/userData.json" 2>/dev/null)
    else
        ORG_ID=$(python3 -c "
import json
try:
    with open('modal-login/temp-data/userData.json', 'r') as f:
        data = json.load(f)
    print(data.get('orgId', ''))
except:
    print('')
" 2>/dev/null)
    fi
fi

# Set environment variables
export NODE_ID="$NODE_ID"
export ORG_ID="$ORG_ID"
export IDENTITY_PATH="$NODE_DIR/swarm.pem"
export CUDA_VISIBLE_DEVICES=0
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export PYTHONPATH="$NODE_DIR:$PYTHONPATH"

echo "🔧 Environment:"
echo "   NODE_ID: $NODE_ID"
echo "   ORG_ID: $ORG_ID"
echo "   IDENTITY_PATH: $IDENTITY_PATH"
echo ""

# Create logs directory
mkdir -p logs

# Launch with python3
LOG_FILE="logs/swarm_launcher.log"
echo "📝 Log file: $LOG_FILE"
echo "🚀 Starting..."

python3 -m rgym_exp.runner.swarm_launcher \
    --config-path configs \
    --config-name rg-swarm.yaml \
    > "$LOG_FILE" 2>&1 &

PID=$!
echo $PID > logs/node.pid

echo "✅ Node $NODE_ID started (PID: $PID)"
echo "📊 Monitor with: tail -f $NODE_DIR/$LOG_FILE"

cd - >/dev/null
EOF
    
    chmod +x launch_node_python3.sh
    log_info "✅ Created launch_node_python3.sh"
}

# Main function
main() {
    echo -e "${CYAN}"
    cat << "EOF"
    🐍 PYTHON3 COMPATIBLE SETUP
    RL-Swarm Multi-Node Environment
    
EOF
    echo -e "$NC"
    
    log_info "Setting up RL-Swarm environment for python3..."
    echo ""
    
    # Detect Python
    detect_python
    echo ""
    
    # Check version
    if ! check_python_version; then
        log_error "Please upgrade Python to 3.8+"
        exit 1
    fi
    echo ""
    
    # Quick test
    quick_test
    echo ""
    
    # Install dependencies
    install_dependencies
    echo ""
    
    # Test installation
    test_installation
    echo ""
    
    # Update scripts
    update_scripts_for_python3
    echo ""
    
    # Create launcher
    create_python3_launcher
    echo ""
    
    log_info "🎉 Python3 setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Test: python3 -c 'import torch; print(torch.cuda.is_available())'"
    echo "2. Setup nodes: ./separate_nodes_setup.sh setup"
    echo "3. Copy files: ./batch_copy_helper.sh copy-all ..."
    echo "4. Launch: ./launch_node_python3.sh 1"
    echo ""
    echo "Or use the updated scripts that now work with python3!"
}

# Show usage
show_usage() {
    echo "Python3 Compatible Setup for RL-Swarm"
    echo ""
    echo "This script will:"
    echo "  - Detect your python3 installation"
    echo "  - Install all required dependencies"
    echo "  - Update existing scripts to use python3"
    echo "  - Create python3 compatible launcher"
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
