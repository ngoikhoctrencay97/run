#!/bin/bash

# =============================================================================
# STEP 2: RUN & MANAGE - Launch and Control All Nodes
# =============================================================================

# Configuration
readonly BASE_DIR="/root/Nodes"
readonly NUM_NODES=10
readonly VENV_PATH="$HOME/rl-swarm-venv"

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
# Launch Scripts for Each Node
# =============================================================================

create_launch_scripts() {
    log_info "🚀 Creating launch scripts for all nodes..."
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/node-$node_id"
    local log_file="$node_dir/logs/swarm_launcher.log"
    
    if [[ ! -f "$log_file" ]]; then
        log_error "Log file not found: $log_file"
        return 1
    fi
    
    log_info "📝 Showing logs for Node $node_id..."
    echo "File: $log_file"
    echo "========================================"
    
    # Show last 50 lines and follow
    tail -f "$log_file"
}

attach_to_node() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        echo "Usage: $0 attach <node_id>"
        echo "Example: $0 attach 1"
        return 1
    fi
    
    if [[ $node_id -lt 1 ]] || [[ $node_id -gt $NUM_NODES ]]; then
        log_error "Invalid node ID. Must be between 1 and $NUM_NODES"
        return 1
    fi
    
    local session_name="rl-swarm-node-$node_id"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log_info "🔗 Attaching to Node $node_id session..."
        echo "Press Ctrl+B then D to detach from session"
        echo ""
        tmux attach -t "$session_name"
    else
        log_error "❌ Session not found: $session_name"
        echo ""
        echo "Available sessions:"
        tmux list-sessions 2>/dev/null | grep rl-swarm || echo "No RL-Swarm sessions found"
    fi
}

restart_node() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        echo "Usage: $0 restart <node_id>"
        echo "Example: $0 restart 1"
        return 1
    fi
    
    if [[ $node_id -lt 1 ]] || [[ $node_id -gt $NUM_NODES ]]; then
        log_error "Invalid node ID. Must be between 1 and $NUM_NODES"
        return 1
    fi
    
    local session_name="rl-swarm-node-$node_id"
    local node_dir="$BASE_DIR/node-$node_id"
    
    log_info "🔄 Restarting Node $node_id..."
    
    # Stop existing session if running
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log_info "Stopping existing session..."
        tmux kill-session -t "$session_name"
        sleep 2
    fi
    
    # Start new session
    log_info "Starting new session..."
    tmux new-session -d -s "$session_name" -c "$node_dir" "$node_dir/launch.sh"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log_info "✅ Node $node_id restarted successfully"
    else
        log_error "❌ Failed to restart Node $node_id"
    fi
}

list_sessions() {
    log_info "📋 All tmux sessions:"
    echo ""
    
    if tmux list-sessions 2>/dev/null; then
        echo ""
        echo "RL-Swarm sessions:"
        tmux list-sessions 2>/dev/null | grep rl-swarm || echo "No RL-Swarm sessions found"
    else
        echo "No tmux sessions found"
    fi
}

verify_data_placement_silent() {
    # Silent verification for internal use
    for (( i=1; i<=NUM_NODES; i++ )); do
        local node_dir="$BASE_DIR/node-$i"
        
        # Check required files
        local identity_file="$node_dir/rl-swarm/swarm.pem"
        local userdata_file="$node_dir/rl-swarm/modal-login/temp-data/userData.json"
        local apikey_file="$node_dir/rl-swarm/modal-login/temp-data/userApiKey.json"
        
        if [[ ! -f "$identity_file" ]] || [[ ! -f "$userdata_file" ]] || [[ ! -f "$apikey_file" ]]; then
            return 1
        fi
    done
    return 0
}

show_quick_commands() {
    echo ""
    echo -e "${CYAN}📋 Quick Commands Reference${NC}"
    echo "============================"
    echo ""
    echo "🚀 Launch & Control:"
    echo "   ./run_and_manage.sh start           # Start all nodes"
    echo "   ./run_and_manage.sh stop            # Stop all nodes"
    echo "   ./run_and_manage.sh restart <id>    # Restart specific node"
    echo ""
    echo "📊 Monitor & Debug:"
    echo "   ./run_and_manage.sh status          # Check all nodes status"
    echo "   ./run_and_manage.sh logs <id>       # View logs (Ctrl+C to exit)"
    echo "   ./run_and_manage.sh attach <id>     # Attach to node session"
    echo ""
    echo "📋 Information:"
    echo "   ./run_and_manage.sh sessions        # List all tmux sessions"
    echo "   ./run_and_manage.sh verify          # Verify data placement"
    echo "   ./run_and_manage.sh help            # Show this help"
    echo ""
    echo "Examples:"
    echo "   ./run_and_manage.sh logs 1          # View Node 1 logs"
    echo "   ./run_and_manage.sh attach 3        # Attach to Node 3"
    echo "   ./run_and_manage.sh restart 5       # Restart Node 5"
    echo ""
}

# =============================================================================
# Main Function & Command Dispatcher
# =============================================================================

show_usage() {
    echo "RL-Swarm Multi-Node Run & Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start                    Start all nodes in tmux sessions"
    echo "  stop                     Stop all nodes (kill tmux sessions)"
    echo "  status                   Check status of all nodes"
    echo "  logs <node_id>          View logs for specific node"
    echo "  attach <node_id>        Attach to specific node tmux session"
    echo "  restart <node_id>       Restart specific node"
    echo "  sessions                List all tmux sessions"
    echo "  verify                  Verify data placement"
    echo "  help                    Show quick commands reference"
    echo ""
    echo "Examples:"
    echo "  $0 start                # Start all 10 nodes"
    echo "  $0 status               # Check status"
    echo "  $0 logs 1               # View Node 1 logs"
    echo "  $0 attach 1             # Attach to Node 1"
    echo "  $0 restart 5            # Restart Node 5"
    echo "  $0 stop                 # Stop all nodes"
}

main() {
    local command="$1"
    local node_id="$2"
    
    # Ensure we're in the right directory
    if [[ ! -d "$BASE_DIR" ]]; then
        log_error "Base directory not found: $BASE_DIR"
        log_error "Please run the setup script first"
        exit 1
    fi
    
    # Create launch scripts if they don't exist
    if [[ ! -f "$BASE_DIR/node-1/launch.sh" ]]; then
        create_launch_scripts
    fi
    
    case "$command" in
        "start")
            start_all_nodes
            ;;
        "stop")
            stop_all_nodes
            ;;
        "status")
            check_status
            ;;
        "logs")
            view_logs "$node_id"
            ;;
        "attach")
            attach_to_node "$node_id"
            ;;
        "restart")
            restart_node "$node_id"
            ;;
        "sessions")
            list_sessions
            ;;
        "verify")
            "$BASE_DIR/verify_data_placement.sh"
            ;;
        "help")
            show_quick_commands
            ;;
        "")
            echo -e "${CYAN}RL-Swarm Multi-Node Manager${NC}"
            echo ""
            show_usage
            echo ""
            show_quick_commands
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Initialize if needed and run main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fiBASE_DIR/node-$i"
        local launch_script="$node_dir/launch.sh"
        
        cat > "$launch_script" << EOF
#!/bin/bash

# Launch script for Node $i
NODE_ID=$i
NODE_DIR="$node_dir"
REPO_DIR="\$NODE_DIR/rl-swarm"

echo "🚀 Starting RL-Swarm Node \$NODE_ID"
echo "📁 Directory: \$NODE_DIR"
echo "🐍 Virtual env: $VENV_PATH"
echo ""

# Change to repository directory
cd "\$REPO_DIR" || {
    echo "❌ Failed to change to repo directory: \$REPO_DIR"
    exit 1
}

# Activate virtual environment
source "$VENV_PATH/bin/activate"

# Verify virtual environment
if [[ "\$VIRTUAL_ENV" != "$VENV_PATH" ]]; then
    echo "❌ Failed to activate virtual environment"
    exit 1
fi

echo "✅ Virtual environment activated"

# Extract ORG_ID from userData.json
ORG_ID=""
if [[ -f "modal-login/temp-data/userData.json" ]]; then
    ORG_ID=\$(python -c "
import json
try:
    with open('modal-login/temp-data/userData.json', 'r') as f:
        data = json.load(f)
    # Handle both flat and nested structures
    if 'orgId' in data:
        print(data['orgId'])
    else:
        for key, value in data.items():
            if isinstance(value, dict) and 'orgId' in value:
                print(value['orgId'])
                break
            elif isinstance(value, dict):
                print(key)
                break
except Exception as e:
    print('')
" 2>/dev/null)
fi

if [[ -z "\$ORG_ID" ]]; then
    echo "⚠️  Warning: Could not extract ORG_ID from userData.json"
else
    echo "✅ ORG_ID extracted: \$ORG_ID"
fi

# Set environment variables
export NODE_ID=\$NODE_ID
export ORG_ID="\$ORG_ID"
export IDENTITY_PATH="\$REPO_DIR/swarm.pem"
export CUDA_VISIBLE_DEVICES=""  # CPU mode
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export PYTHONPATH="\$REPO_DIR:\$PYTHONPATH"

echo "🔧 Environment variables set:"
echo "   NODE_ID: \$NODE_ID"
echo "   ORG_ID: \$ORG_ID"
echo "   IDENTITY_PATH: \$IDENTITY_PATH"
echo "   Working Directory: \$(pwd)"
echo ""

# Create logs directory
mkdir -p "\$NODE_DIR/logs"

# Launch RL-Swarm
echo "🚀 Launching RL-Swarm Node \$NODE_ID..."
echo "📝 Logs will be saved to: \$NODE_DIR/logs/swarm_launcher.log"
echo ""

python -m rgym_exp.runner.swarm_launcher \\
    --config-path=configs \\
    --config-name=node-config \\
    2>&1 | tee "\$NODE_DIR/logs/swarm_launcher.log"

echo ""
echo "🏁 Node \$NODE_ID finished"
EOF
        
        chmod +x "$launch_script"
        log_info "✅ Node $i: Launch script created"
    done
    
    log_info "✅ All launch scripts created"
}

# =============================================================================
# Tmux Management Functions
# =============================================================================

start_all_nodes() {
    log_info "🚀 Starting all $NUM_NODES nodes in tmux sessions..."
    
    # Verify data placement first
    if ! verify_data_placement_silent; then
        log_error "❌ Data verification failed. Please place required files first."
        echo "Run: ./verify_data_placement.sh"
        return 1
    fi
    
    local started=0
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local session_name="rl-swarm-node-$i"
        local node_dir="$BASE_DIR/node-$i"
        
        # Check if session already exists
        if tmux has-session -t "$session_name" 2>/dev/null; then
            log_warn "Session $session_name already exists. Skipping..."
            continue
        fi
        
        log_info "🚀 Starting Node $i in tmux session: $session_name"
        
        # Create tmux session and run launch script
        tmux new-session -d -s "$session_name" -c "$node_dir" "$node_dir/launch.sh"
        
        if tmux has-session -t "$session_name" 2>/dev/null; then
            log_info "✅ Node $i started successfully"
            started=$((started + 1))
        else
            log_error "❌ Failed to start Node $i"
        fi
        
        # Small delay between launches
        sleep 2
    done
    
    echo ""
    log_info "🎉 Started $started/$NUM_NODES nodes in tmux sessions!"
    echo ""
    echo "📋 Next steps:"
    echo "   - Check status: ./run_and_manage.sh status"
    echo "   - View logs: ./run_and_manage.sh logs <node_id>"
    echo "   - Attach to node: ./run_and_manage.sh attach <node_id>"
}

stop_all_nodes() {
    log_info "🛑 Stopping all tmux sessions..."
    
    local stopped=0
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local session_name="rl-swarm-node-$i"
        
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux kill-session -t "$session_name"
            log_info "✅ Stopped session: $session_name"
            stopped=$((stopped + 1))
        else
            log_warn "⭕ Session not found: $session_name"
        fi
    done
    
    echo ""
    log_info "🎉 Stopped $stopped tmux sessions!"
}

check_status() {
    log_info "📊 Checking status of all nodes..."
    echo ""
    
    local running_sessions=0
    local running_processes=0
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        local session_name="rl-swarm-node-$i"
        local node_dir="$BASE_DIR/node-$i"
        local log_file="$node_dir/logs/swarm_launcher.log"
        
        echo "Node $i:"
        
        # Check tmux session
        if tmux has-session -t "$session_name" 2>/dev/null; then
            echo "  ✅ Tmux session: Running"
            running_sessions=$((running_sessions + 1))
        else
            echo "  ❌ Tmux session: Stopped"
        fi
        
        # Check for RL-Swarm process
        if pgrep -f "rgym_exp.runner.swarm_launcher.*node-$i" >/dev/null; then
            echo "  ✅ RL-Swarm process: Running"
            running_processes=$((running_processes + 1))
        else
            echo "  ❌ RL-Swarm process: Not running"
        fi
        
        # Check log file
        if [[ -f "$log_file" ]]; then
            local log_size=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            echo "  📝 Log file: $log_size lines"
            
            # Check for recent activity (last 5 minutes)
            if [[ -f "$log_file" ]] && find "$log_file" -mmin -5 | grep -q .; then
                echo "  ⏰ Recent activity: Yes"
            else
                echo "  ⏰ Recent activity: No"
            fi
            
            # Check for errors
            local error_count=$(grep -c -i "error\|exception\|failed" "$log_file" 2>/dev/null || echo "0")
            if [[ $error_count -gt 0 ]]; then
                echo "  ⚠️  Errors found: $error_count"
            else
                echo "  ✅ No errors detected"
            fi
        else
            echo "  ❌ Log file: Not found"
        fi
        
        echo ""
    done
    
    echo "📊 Summary:"
    echo "   Tmux sessions running: $running_sessions/$NUM_NODES"
    echo "   RL-Swarm processes running: $running_processes/$NUM_NODES"
    echo ""
    
    # Show tmux sessions
    echo "📋 Active Tmux Sessions:"
    if tmux list-sessions 2>/dev/null | grep -q rl-swarm; then
        tmux list-sessions | grep rl-swarm
    else
        echo "   No RL-Swarm sessions found"
    fi
}

view_logs() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        echo "Usage: $0 logs <node_id>"
        echo "Example: $0 logs 1"
        return 1
    fi
    
    if [[ $node_id -lt 1 ]] || [[ $node_id -gt $NUM_NODES ]]; then
        log_error "Invalid node ID. Must be between 1 and $NUM_NODES"
        return 1
    fi
    
    local node_dir="$
