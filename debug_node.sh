#!/bin/bash

# =============================================================================
# Debug Node Issues Script
# =============================================================================

readonly BASE_DIR="/root/Nodes"
readonly NUM_NODES="${NUM_NODES:-10}"

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

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

# Check logs for a specific node
check_node_logs() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        log_error "Usage: check_node_logs <node_id>"
        return 1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    local log_file="$node_dir/logs/swarm_launcher.log"
    
    log_info "Checking logs for Node $node_id..."
    echo "================================================"
    
    if [[ ! -f "$log_file" ]]; then
        log_error "Log file not found: $log_file"
        return 1
    fi
    
    echo -e "${YELLOW}Log file: $log_file${NC}"
    echo ""
    
    # Show last 30 lines
    echo -e "${CYAN}Last 30 lines:${NC}"
    echo "----------------------------------------"
    tail -n 30 "$log_file"
    echo ""
    
    # Look for common errors
    echo -e "${CYAN}Error patterns found:${NC}"
    echo "----------------------------------------"
    
    # Check for Python errors
    local python_errors=$(grep -i "error\|exception\|traceback\|failed" "$log_file" | wc -l)
    if [[ $python_errors -gt 0 ]]; then
        echo "🚨 Python errors found: $python_errors"
        grep -i "error\|exception\|traceback\|failed" "$log_file" | tail -5
        echo ""
    fi
    
    # Check for import errors
    local import_errors=$(grep -i "importerror\|modulenotfounderror" "$log_file" | wc -l)
    if [[ $import_errors -gt 0 ]]; then
        echo "📦 Import errors found: $import_errors"
        grep -i "importerror\|modulenotfounderror" "$log_file"
        echo ""
    fi
    
    # Check for GPU/CUDA errors
    local cuda_errors=$(grep -i "cuda\|gpu\|out of memory" "$log_file" | wc -l)
    if [[ $cuda_errors -gt 0 ]]; then
        echo "🎮 GPU/CUDA errors found: $cuda_errors"
        grep -i "cuda\|gpu\|out of memory" "$log_file"
        echo ""
    fi
    
    # Check for port binding errors
    local port_errors=$(grep -i "address already in use\|bind\|port" "$log_file" | wc -l)
    if [[ $port_errors -gt 0 ]]; then
        echo "🌐 Port/Network errors found: $port_errors"
        grep -i "address already in use\|bind\|port" "$log_file"
        echo ""
    fi
    
    # Check for config errors
    local config_errors=$(grep -i "config\|yaml\|not found" "$log_file" | wc -l)
    if [[ $config_errors -gt 0 ]]; then
        echo "⚙️ Config errors found: $config_errors"
        grep -i "config\|yaml\|not found" "$log_file" | tail -3
        echo ""
    fi
}

# Check environment for a specific node
check_node_environment() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        log_error "Usage: check_node_environment <node_id>"
        return 1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    
    log_info "Checking environment for Node $node_id..."
    echo "================================================"
    
    # Check directory structure
    echo -e "${CYAN}Directory structure:${NC}"
    if [[ -d "$node_dir" ]]; then
        echo "✅ Node directory exists: $node_dir"
        ls -la "$node_dir"
        echo ""
    else
        echo "❌ Node directory missing: $node_dir"
        return 1
    fi
    
    # Check required files
    echo -e "${CYAN}Required files:${NC}"
    local files=(
        "swarm.pem"
        "modal-login/temp-data/userData.json"
        "modal-login/temp-data/userApiKey.json"
        "configs/rg-swarm.yaml"
    )
    
    for file in "${files[@]}"; do
        local file_path="$node_dir/$file"
        if [[ -f "$file_path" ]]; then
            echo "✅ $file"
            
            # Additional checks for specific files
            case "$file" in
                "swarm.pem")
                    local perms=$(stat -c %a "$file_path" 2>/dev/null || stat -f %A "$file_path" 2>/dev/null)
                    if [[ "$perms" == "600" ]]; then
                        echo "   ✅ Correct permissions (600)"
                    else
                        echo "   ⚠️ Wrong permissions ($perms), should be 600"
                    fi
                    ;;
                "modal-login/temp-data/userData.json")
                    if command -v jq >/dev/null 2>&1; then
                        local org_id=$(jq -r '.orgId // "missing"' "$file_path" 2>/dev/null)
                        echo "   📋 OrgID: $org_id"
                    fi
                    ;;
                "configs/rg-swarm.yaml")
                    local yaml_lines=$(wc -l < "$file_path")
                    echo "   📄 Config lines: $yaml_lines"
                    ;;
            esac
        else
            echo "❌ $file (missing)"
        fi
    done
    echo ""
    
    # Check Python environment
    echo -e "${CYAN}Python environment:${NC}"
    echo "Python version: $(python --version 2>&1)"
    echo "Python path: $(which python)"
    
    # Check required Python packages
    local packages=("transformers" "torch" "trl" "hivemind")
    for pkg in "${packages[@]}"; do
        if python -c "import $pkg" 2>/dev/null; then
            local version=$(python -c "import $pkg; print(getattr($pkg, '__version__', 'unknown'))" 2>/dev/null)
            echo "✅ $pkg ($version)"
        else
            echo "❌ $pkg (not installed)"
        fi
    done
    echo ""
    
    # Check GPU availability
    echo -e "${CYAN}GPU environment:${NC}"
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "✅ nvidia-smi available"
        nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader,nounits | head -1
        
        # Check PyTorch CUDA
        if python -c "import torch; print('CUDA available:', torch.cuda.is_available())" 2>/dev/null; then
            echo "✅ PyTorch CUDA available"
        else
            echo "❌ PyTorch CUDA not available"
        fi
    else
        echo "❌ nvidia-smi not found"
    fi
    echo ""
    
    # Check ports
    echo -e "${CYAN}Port status:${NC}"
    local base_ports=(30000 8000 40000 3000)
    local port_names=("P2P" "API" "COMM" "WEB")
    
    for i in "${!base_ports[@]}"; do
        local port=$((${base_ports[$i]} + node_id - 1))
        local port_name=${port_names[$i]}
        
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            echo "⚠️ $port_name port $port: IN USE"
        else
            echo "✅ $port_name port $port: FREE"
        fi
    done
}

# Try to restart a specific node with detailed logging
restart_node_debug() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        log_error "Usage: restart_node_debug <node_id>"
        return 1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    
    log_info "Restarting Node $node_id with debug logging..."
    
    # Stop existing process
    local pid_file="$node_dir/logs/node.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid"
            log_info "Stopped existing process (PID: $pid)"
            sleep 3
        fi
        rm -f "$pid_file"
    fi
    
    # Change to node directory
    cd "$node_dir" || {
        log_error "Failed to change to node directory: $node_dir"
        return 1
    }
    
    # Extract ORG_ID
    local org_id=""
    if [[ -f "modal-login/temp-data/userData.json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            org_id=$(jq -r '.orgId // ""' "modal-login/temp-data/userData.json" 2>/dev/null)
        else
            org_id=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' "modal-login/temp-data/userData.json")
        fi
    fi
    
    log_info "Using ORG_ID: $org_id"
    
    # Set environment variables
    export NODE_ID=$node_id
    export ORG_ID="$org_id"
    export IDENTITY_PATH="$node_dir/swarm.pem"
    export CUDA_VISIBLE_DEVICES=0
    export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
    export PYTHONPATH="$node_dir:$PYTHONPATH"
    
    log_info "Environment variables set"
    log_info "NODE_ID=$NODE_ID"
    log_info "ORG_ID=$ORG_ID"
    log_info "IDENTITY_PATH=$IDENTITY_PATH"
    
    # Create logs directory
    mkdir -p logs
    
    # Try to run with more verbose logging
    local log_file="logs/swarm_launcher_debug.log"
    
    log_info "Starting node with command:"
    echo "python -m rgym_exp.runner.swarm_launcher --config-path configs --config-name rg-swarm.yaml"
    
    # Run in foreground first to see immediate errors
    echo ""
    log_warn "Running in foreground mode for debugging (Ctrl+C to stop)..."
    echo "Log output will be saved to: $log_file"
    echo ""
    
    python -m rgym_exp.runner.swarm_launcher \
        --config-path configs \
        --config-name rg-swarm.yaml 2>&1 | tee "$log_file"
    
    cd - >/dev/null
}

# Check all failed nodes
check_all_failed_nodes() {
    log_info "Checking all failed nodes..."
    echo ""
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/rl-swarm-$i"
        local pid_file="$node_dir/logs/node.pid"
        
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ! ps -p "$pid" > /dev/null 2>&1; then
                echo -e "${RED}Node $i: FAILED${NC}"
                echo "----------------------------------------"
                check_node_logs "$i" | head -20
                echo ""
            fi
        fi
    done
}

# Quick fix common issues
quick_fix_node() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        log_error "Usage: quick_fix_node <node_id>"
        return 1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    
    log_info "Applying quick fixes for Node $node_id..."
    
    # Fix permissions
    if [[ -f "$node_dir/swarm.pem" ]]; then
        chmod 600 "$node_dir/swarm.pem"
        log_info "✅ Fixed swarm.pem permissions"
    fi
    
    # Create missing directories
    mkdir -p "$node_dir"/{logs,configs,modal-login/temp-data}
    log_info "✅ Ensured directory structure exists"
    
    # Check if rgym_exp module exists
    if [[ ! -d "$node_dir/rgym_exp" ]]; then
        if [[ -d "./rgym_exp" ]]; then
            cp -r ./rgym_exp "$node_dir/"
            log_info "✅ Copied rgym_exp module"
        else
            log_warn "⚠️ rgym_exp module not found in current directory"
        fi
    fi
    
    # Clean up old PID files
    rm -f "$node_dir/logs/node.pid"
    log_info "✅ Cleaned up PID files"
    
    log_info "🎉 Quick fixes applied for Node $node_id"
}

# Show usage
show_usage() {
    echo "Debug Node Issues Script"
    echo ""
    echo "Usage: $0 [COMMAND] [NODE_ID]"
    echo ""
    echo "Commands:"
    echo "  logs <node_id>           Show detailed logs for specific node"
    echo "  env <node_id>            Check environment for specific node"
    echo "  restart <node_id>        Restart node with debug logging"
    echo "  check-failed             Check all failed nodes"
    echo "  fix <node_id>            Apply quick fixes for node"
    echo ""
    echo "Examples:"
    echo "  $0 logs 1                # Check Node 1 logs"
    echo "  $0 env 1                 # Check Node 1 environment"
    echo "  $0 restart 1             # Restart Node 1 with debug"
    echo "  $0 check-failed          # Check all failed nodes"
    echo "  $0 fix 1                 # Apply quick fixes to Node 1"
}

# Main function
main() {
    local command="$1"
    local node_id="$2"
    
    case "$command" in
        "logs")
            check_node_logs "$node_id"
            ;;
        "env")
            check_node_environment "$node_id"
            ;;
        "restart")
            restart_node_debug "$node_id"
            ;;
        "check-failed")
            check_all_failed_nodes
            ;;
        "fix")
            quick_fix_node "$node_id"
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

# Execute main function
main "$@"
