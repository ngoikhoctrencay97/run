#!/bin/bash

# =============================================================================
# Separate Node Directories Setup for RL-Swarm
# Creates 10 independent node directories with individual file management
# =============================================================================

# Configuration
readonly BASE_DIR="/root/Nodes"
readonly NUM_NODES="${NUM_NODES:-10}"
readonly BASE_PORT=30000
readonly BASE_API_PORT=8000
readonly BASE_COMM_PORT=40000
readonly BASE_WEB_PORT=3000

# Color codes
readonly GREEN="\033[32m\033[1m"
readonly RED="\033[31m\033[1m"
readonly YELLOW="\033[33m\033[1m"
readonly CYAN="\033[36m\033[1m"
readonly BLUE="\033[34m\033[1m"
readonly NC="\033[0m"

# Node tracking arrays
declare -a NODE_PIDS=()
declare -a NODE_DIRS=()

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_node() {
    local node_id=$1
    shift
    echo -e "${CYAN}[NODE-$node_id]${NC} $*"
}

# =============================================================================
# Directory Setup Functions
# =============================================================================

create_node_directories() {
    log_info "Creating $NUM_NODES separate node directories..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/rl-swarm-$i"
        NODE_DIRS[$i]="$node_dir"
        
        log_node "$i" "Creating directory structure: $node_dir"
        
        # Create main directory structure
        mkdir -p "$node_dir"/{logs,configs,modal-login/temp-data}
        
        # Create subdirectories
        mkdir -p "$node_dir"/logs
        mkdir -p "$node_dir"/configs  
        mkdir -p "$node_dir"/modal-login/temp-data
        
        # Copy base RL-Swarm code to each node (if exists)
        if [[ -d "./rgym_exp" ]]; then
            cp -r ./rgym_exp "$node_dir/"
            log_node "$i" "Copied rgym_exp code"
        fi
        
        if [[ -d "./modal-login" ]] && [[ -f "./modal-login/package.json" ]]; then
            cp -r ./modal-login/* "$node_dir/modal-login/"
            # Remove temp-data if copied, we'll create fresh
            rm -rf "$node_dir/modal-login/temp-data"
            mkdir -p "$node_dir/modal-login/temp-data"
            log_node "$i" "Copied modal-login base files"
        fi
        
        log_node "$i" "✅ Directory structure created"
    done
    
    echo ""
    log_info "✅ All node directories created!"
}

# Display file placement instructions
show_file_placement_guide() {
    echo -e "${CYAN}📁 FILE PLACEMENT GUIDE${NC}"
    echo "=========================================="
    echo ""
    echo "For each node, place your files in these locations:"
    echo ""
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/rl-swarm-$i"
        echo -e "${YELLOW}Node $i:${NC}"
        echo "  📁 Base Directory: $node_dir"
        echo "  🔐 Identity File: $node_dir/swarm.pem"
        echo "  👤 User Data: $node_dir/modal-login/temp-data/userData.json"
        echo "  🔑 API Key: $node_dir/modal-login/temp-data/userApiKey.json"
        echo ""
    done
    
    echo -e "${GREEN}Quick copy commands (replace with your actual file paths):${NC}"
    echo ""
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/rl-swarm-$i"
        echo "# Node $i"
        echo "cp /path/to/your/swarm.pem $node_dir/swarm.pem"
        echo "cp /path/to/your/userData.json $node_dir/modal-login/temp-data/"
        echo "cp /path/to/your/userApiKey.json $node_dir/modal-login/temp-data/"
        echo "chmod 600 $node_dir/swarm.pem"
        echo ""
    done
}

# Verify files for all nodes
verify_all_node_files() {
    log_info "Verifying files for all nodes..."
    
    local all_good=true
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/rl-swarm-$i"
        local missing_files=()
        
        # Check required files
        local identity_file="$node_dir/swarm.pem"
        local user_data_file="$node_dir/modal-login/temp-data/userData.json"
        local api_key_file="$node_dir/modal-login/temp-data/userApiKey.json"
        
        if [[ ! -f "$identity_file" ]]; then
            missing_files+=("swarm.pem")
        fi
        
        if [[ ! -f "$user_data_file" ]]; then
            missing_files+=("userData.json")
        fi
        
        if [[ ! -f "$api_key_file" ]]; then
            missing_files+=("userApiKey.json")
        fi
        
        if [[ ${#missing_files[@]} -eq 0 ]]; then
            log_node "$i" "✅ All files present"
            
            # Fix permissions
            chmod 600 "$identity_file" 2>/dev/null
            
            # Show file info
            if command -v jq >/dev/null 2>&1; then
                local org_id=$(jq -r '.orgId // "N/A"' "$user_data_file" 2>/dev/null)
                local wallet=$(jq -r '.walletAddress // "N/A"' "$user_data_file" 2>/dev/null | cut -c1-10)
                log_node "$i" "OrgID: $org_id, Wallet: ${wallet}..."
            fi
        else
            log_node "$i" "❌ Missing files: ${missing_files[*]}"
            all_good=false
        fi
    done
    
    if [[ "$all_good" == "true" ]]; then
        log_info "✅ All nodes have required files!"
        return 0
    else
        log_error "❌ Some nodes are missing required files"
        return 1
    fi
}

# =============================================================================
# Configuration Generation
# =============================================================================

generate_node_config() {
    local node_id=$1
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    
    local p2p_port=$((BASE_PORT + node_id - 1))
    local api_port=$((BASE_API_PORT + node_id - 1))
    local comm_port=$((BASE_COMM_PORT + node_id - 1))
    local web_port=$((BASE_WEB_PORT + node_id - 1))
    
    log_node "$node_id" "Generating config (P2P:$p2p_port API:$api_port COMM:$comm_port WEB:$web_port)"
    
    # Create config file
    local config_file="$node_dir/configs/rg-swarm.yaml"
    
    cat > "$config_file" << EOF
log_dir: $node_dir/logs

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
  contract_address: \${oc.env:SWARM_CONTRACT,"0xFaD7C5e93f28257429569B854151A1B8DCD404c2"}
  org_id: \${oc.env:ORG_ID,null}
  mainnet_chain_id: 685685
  modal_proxy_url: "http://localhost:$web_port/api/"

communications:
  p2p_port: $p2p_port
  api_port: $api_port
  comm_port: $comm_port
  initial_peers:
    - '/ip4/127.0.0.1/tcp/$((BASE_PORT))/p2p/\${oc.env:NODE_0_PEER_ID,QmDefaultPeer0}'
    - '/ip4/127.0.0.1/tcp/$((BASE_PORT+1))/p2p/\${oc.env:NODE_1_PEER_ID,QmDefaultPeer1}'
    - '/ip4/127.0.0.1/tcp/$((BASE_PORT+2))/p2p/\${oc.env:NODE_2_PEER_ID,QmDefaultPeer2}'
    - '/ip4/38.101.215.12/tcp/30011/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ'
    - '/ip4/38.101.215.13/tcp/30012/p2p/QmWhiaLrx3HRZfgXc2i7KW5nMUNK7P9tRc71yFJdGEZKkC'
    - '/ip4/38.101.215.14/tcp/30013/p2p/QmQa1SCfYTxx7RvU7qJJRo79Zm1RAwPpkeLueDVJuBBmFp'

eval:
  judge_base_url: https://swarm-judge-102957787771.us-east1.run.app

hydra:
  run:
    dir: $node_dir/logs

game_manager:
  *target*: rgym_exp.src.manager.SwarmGameManager
  max_stage: \${training.max_stage}
  max_round: \${training.max_round}
  log_dir: $node_dir/logs
  hf_token: \${oc.env:HUGGINGFACE_ACCESS_TOKEN,null}
  hf_push_frequency: \${training.hf_push_frequency}
  run_mode: "train_and_evaluate"
  bootnodes: \${communications.initial_peers}
  
  game_state: 
    *target*: genrl.state.game_state.GameState
    round: 0
    stage: 0
    
  reward_manager:
    *target*: genrl.rewards.DefaultRewardManager
    reward_fn_store:
      *target*: genrl.rewards.reward_store.RewardFnStore
      max_rounds: \${training.max_round}
      reward_fn_stores:
        - *target*: genrl.rewards.reward_store.RoundRewardFnStore
          num_stages: \${training.max_stage}
          reward_fns:
            - *target*: rgym_exp.src.rewards.RGRewards
            
  trainer:
    *target*: rgym_exp.src.trainer.GRPOTrainerModule
    models:
      - *target*: transformers.AutoModelForCausalLM.from_pretrained
        pretrained_model_name_or_path: "Gensyn/Qwen2.5-1.5B-Instruct"
        torch_dtype: float16
        device_map: "auto"
        low_cpu_mem_usage: true
        max_memory: {0: "8GB"}
    config:
      *target*: trl.trainer.GRPOConfig
      logging_dir: $node_dir/logs
      fp16: \${training.fp16}
      per_device_train_batch_size: 1
      per_device_eval_batch_size: 1
      gradient_accumulation_steps: 2
      dataloader_num_workers: 2
      logging_steps: 50
      save_steps: 1000
      eval_steps: 500
      max_length: 1024
      max_new_tokens: 256
      output_dir: "$node_dir/logs/checkpoints"
      run_name: "node_$node_id"
    log_with: wandb
    log_dir: $node_dir/logs
    epsilon: 0.2
    epsilon_high: 0.28
    num_generations: \${training.num_generations}
    judge_base_url: \${eval.judge_base_url}
    
  data_manager:
    *target*: rgym_exp.src.data.ReasoningGymDataManager
    yaml_config_path: "rgym_exp/src/datasets.yaml"
    num_train_samples: 1
    num_evaluation_samples: 0
    num_generations: \${training.num_generations}
    system_prompt_id: 'default'
    seed: \${training.seed}
    num_transplant_trees: \${training.num_transplant_trees}
    
  communication:
    *target*: genrl.communication.hivemind.hivemind_backend.HivemindBackend
    initial_peers: \${communications.initial_peers}
    identity_path: "$node_dir/swarm.pem"
    startup_timeout: 180
    beam_size: 20
    averaging_timeout: 30.0
    compression: true
    host_maddrs: ["/ip4/0.0.0.0/tcp/$p2p_port"]
    announce_maddrs: ["/ip4/127.0.0.1/tcp/$p2p_port"]
    
  coordinator:
    *target*: genrl.blockchain.coordinator.ModalSwarmCoordinator
    web3_url: \${blockchain.alchemy_url}
    contract_address: \${blockchain.contract_address}
    org_id: \${blockchain.org_id}
    modal_proxy_url: \${blockchain.modal_proxy_url}

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

    log_node "$node_id" "✅ Config generated: $config_file"
}

generate_all_configs() {
    log_info "Generating configurations for all nodes..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        generate_node_config "$i"
    done
    
    log_info "✅ All configurations generated!"
}

# =============================================================================
# Node Launch Functions
# =============================================================================

launch_single_node() {
    local node_id=$1
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    
    local p2p_port=$((BASE_PORT + node_id - 1))
    local api_port=$((BASE_API_PORT + node_id - 1))
    local comm_port=$((BASE_COMM_PORT + node_id - 1))
    local web_port=$((BASE_WEB_PORT + node_id - 1))
    
    log_node "$node_id" "Launching node from $node_dir..."
    
    # Change to node directory
    cd "$node_dir" || {
        log_error "Failed to change to node directory: $node_dir"
        return 1
    }
    
    # Extract ORG_ID from userData.json
    local org_id=""
    if [[ -f "modal-login/temp-data/userData.json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            org_id=$(jq -r '.orgId // ""' "modal-login/temp-data/userData.json" 2>/dev/null)
        else
            org_id=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' "modal-login/temp-data/userData.json")
        fi
    fi
    
    # Set environment variables
    export NODE_ID=$node_id
    export ORG_ID="$org_id"
    export IDENTITY_PATH="$node_dir/swarm.pem"
    export CUDA_VISIBLE_DEVICES=0
    export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
    
    # Launch the node
    local log_file="$node_dir/logs/swarm_launcher.log"
    mkdir -p "$node_dir/logs"
    
    python -m rgym_exp.runner.swarm_launcher \
        --config-path "$node_dir/configs" \
        --config-name "rg-swarm.yaml" \
        > "$log_file" 2>&1 &
    
    local node_pid=$!
    NODE_PIDS[$node_id]=$node_pid
    
    # Save PID
    echo "$node_pid" > "$node_dir/logs/node.pid"
    
    log_node "$node_id" "✅ Launched (PID: $node_pid)"
    log_node "$node_id" "📁 Working directory: $node_dir"
    log_node "$node_id" "📝 Log file: $log_file"
    
    # Return to original directory
    cd - >/dev/null
    
    # Brief delay between launches
    sleep 3
}

launch_all_nodes() {
    log_info "Launching all $NUM_NODES nodes..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        launch_single_node "$i"
    done
    
    log_info "✅ All nodes launched!"
}

# =============================================================================
# Management Functions
# =============================================================================

stop_all_nodes() {
    log_info "Stopping all nodes..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/rl-swarm-$i"
        local pid_file="$node_dir/logs/node.pid"
        
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                kill "$pid" 2>/dev/null || true
                log_node "$i" "Stopped (PID: $pid)"
            fi
            rm -f "$pid_file"
        fi
    done
    
    log_info "✅ All nodes stopped!"
}

check_node_status() {
    log_info "Checking status of all nodes..."
    
    local running=0
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/rl-swarm-$i"
        local pid_file="$node_dir/logs/node.pid"
        
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                local cpu=$(ps -p "$pid" -o %cpu --no-headers | tr -d ' ')
                local mem=$(ps -p "$pid" -o %mem --no-headers | tr -d ' ')
                log_node "$i" "✅ Running (PID: $pid) CPU: ${cpu}% MEM: ${mem}%"
                running=$((running + 1))
            else
                log_node "$i" "❌ Dead (PID file exists but process stopped)"
            fi
        else
            log_node "$i" "⭕ Not started"
        fi
    done
    
    log_info "📊 Summary: $running/$NUM_NODES nodes running"
}

# =============================================================================
# Main Functions
# =============================================================================

display_banner() {
    echo -e "\033[38;5;224m"
    cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    SEPARATE NODE DIRECTORIES - H100 Multi-Node Setup
    Each node has its own independent directory structure

EOF
    echo -e "$NC"
}

show_usage() {
    echo "Separate Node Directories Setup for RL-Swarm"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  setup     Create directory structure and show file placement guide"
    echo "  verify    Verify all nodes have required files"
    echo "  config    Generate configurations for all nodes"
    echo "  launch    Launch all nodes"
    echo "  stop      Stop all nodes"
    echo "  status    Check status of all nodes"
    echo "  all       Run setup -> verify -> config -> launch sequence"
    echo ""
    echo "Options:"
    echo "  NUM_NODES=N      Number of nodes (default: 10)"
    echo "  BASE_DIR=PATH    Base directory path (default: /root/Nodes)"
    echo ""
    echo "Examples:"
    echo "  $0 setup                    # Create directory structure"
    echo "  $0 verify                   # Check if files are placed"
    echo "  NUM_NODES=5 $0 all         # Setup and launch 5 nodes"
    echo ""
    echo "Directory structure created:"
    echo "  /root/Nodes/rl-swarm-1/    # Node 1"
    echo "  /root/Nodes/rl-swarm-2/    # Node 2"
    echo "  ...                        # ..."
    echo "  /root/Nodes/rl-swarm-10/   # Node 10"
}

main() {
    local command="${1:-help}"
    
    case "$command" in
        "setup")
            display_banner
            create_node_directories
            echo ""
            show_file_placement_guide
            ;;
        "verify")
            display_banner
            if verify_all_node_files; then
                log_info "🎉 All nodes are ready to launch!"
            else
                log_error "Please place missing files and run verify again"
                exit 1
            fi
            ;;
        "config")
            display_banner
            generate_all_configs
            ;;
        "launch")
            display_banner
            if verify_all_node_files; then
                generate_all_configs
                launch_all_nodes
                echo ""
                log_info "🎉 All nodes launched! Use '$0 status' to monitor"
            else
                log_error "Cannot launch - missing required files"
                exit 1
            fi
            ;;
        "stop")
            stop_all_nodes
            ;;
        "status")
            check_node_status
            ;;
        "all")
            display_banner
            create_node_directories
            echo ""
            show_file_placement_guide
            echo ""
            log_info "📋 Please place your files in the node directories shown above"
            echo ""
            read -p "Press Enter after placing all files to continue with verification..."
            echo ""
            if verify_all_node_files; then
                generate_all_configs
                launch_all_nodes
                echo ""
                log_info "🎉 Complete setup finished! All nodes are running"
            else
                log_error "Setup incomplete - missing required files"
                exit 1
            fi
            ;;
        "help"|"--help"|"-h")
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

# Handle cleanup on exit
cleanup() {
    if [[ "${1:-}" != "stop" ]]; then
        log_warn "Received interrupt signal..."
        stop_all_nodes
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# Execute main function
main "$@"
