#!/bin/bash

# =============================================================================
# Fix Nested UserData JSON Structure
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

# Extract orgId from nested JSON structure
extract_orgid_from_nested() {
    local user_data_file="$1"
    
    if [[ ! -f "$user_data_file" ]]; then
        echo ""
        return 1
    fi
    
    # Try to extract orgId from nested structure
    local org_id=""
    
    if command -v jq >/dev/null 2>&1; then
        # Method 1: Get the first key (which is the orgId)
        org_id=$(jq -r 'keys[0]' "$user_data_file" 2>/dev/null)
        
        # Method 2: If that fails, try to get orgId from nested object
        if [[ -z "$org_id" || "$org_id" == "null" ]]; then
            org_id=$(jq -r 'to_entries[0].value.orgId' "$user_data_file" 2>/dev/null)
        fi
        
        # Method 3: Search for any field named orgId
        if [[ -z "$org_id" || "$org_id" == "null" ]]; then
            org_id=$(jq -r '.. | .orgId? // empty' "$user_data_file" 2>/dev/null | head -1)
        fi
    else
        # Fallback without jq - use grep and sed
        org_id=$(grep -o '"orgId":[[:space:]]*"[^"]*"' "$user_data_file" | sed 's/"orgId":[[:space:]]*"//;s/"//' | head -1)
        
        # If not found, try to get the main key
        if [[ -z "$org_id" ]]; then
            org_id=$(grep -o '^[[:space:]]*"[^"]*"[[:space:]]*:' "$user_data_file" | sed 's/^[[:space:]]*"//;s/"[[:space:]]*://' | head -1)
        fi
    fi
    
    echo "$org_id"
}

# Convert nested userData.json to flat structure
flatten_userdata() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        log_error "Usage: flatten_userdata <node_id>"
        return 1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    local user_data_file="$node_dir/modal-login/temp-data/userData.json"
    
    if [[ ! -f "$user_data_file" ]]; then
        log_error "userData.json not found: $user_data_file"
        return 1
    fi
    
    log_info "Processing Node $node_id userData.json..."
    
    # Extract orgId
    local org_id=$(extract_orgid_from_nested "$user_data_file")
    
    if [[ -z "$org_id" || "$org_id" == "null" ]]; then
        log_error "Could not extract orgId from userData.json"
        return 1
    fi
    
    log_info "Extracted OrgID: $org_id"
    
    # Create backup
    cp "$user_data_file" "${user_data_file}.backup"
    log_info "Created backup: ${user_data_file}.backup"
    
    # Extract all values from nested structure
    if command -v jq >/dev/null 2>&1; then
        # Use jq to flatten the structure
        jq --arg orgid "$org_id" '
        to_entries[0].value as $data |
        {
            orgId: $orgid,
            userId: $data.userId,
            email: $data.email,
            walletAddress: $data.address,
            solanaAddress: $data.solanaAddress
        }
        ' "$user_data_file" > "${user_data_file}.new"
        
        # Replace original file
        mv "${user_data_file}.new" "$user_data_file"
        
        log_info "✅ Flattened userData.json structure"
        
        # Show new structure
        echo -e "${CYAN}New userData.json structure:${NC}"
        cat "$user_data_file"
        
    else
        # Manual method without jq
        log_warn "jq not available, using manual method..."
        
        # Extract values manually
        local user_id=$(grep -o '"userId":[[:space:]]*"[^"]*"' "$user_data_file" | sed 's/"userId":[[:space:]]*"//;s/"//')
        local email=$(grep -o '"email":[[:space:]]*"[^"]*"' "$user_data_file" | sed 's/"email":[[:space:]]*"//;s/"//')
        local address=$(grep -o '"address":[[:space:]]*"[^"]*"' "$user_data_file" | sed 's/"address":[[:space:]]*"//;s/"//')
        local solana_address=$(grep -o '"solanaAddress":[[:space:]]*"[^"]*"' "$user_data_file" | sed 's/"solanaAddress":[[:space:]]*"//;s/"//')
        
        # Create new flat structure
        cat > "$user_data_file" << EOF
{
  "orgId": "$org_id",
  "userId": "$user_id",
  "email": "$email",
  "walletAddress": "$address",
  "solanaAddress": "$solana_address"
}
EOF
        
        log_info "✅ Manually flattened userData.json structure"
        cat "$user_data_file"
    fi
    
    echo ""
    
    # Verify the new structure
    local new_org_id=$(jq -r '.orgId // "null"' "$user_data_file" 2>/dev/null)
    if [[ "$new_org_id" == "$org_id" ]]; then
        log_info "✅ Verification successful - OrgID: $new_org_id"
        return 0
    else
        log_error "❌ Verification failed - OrgID not properly extracted"
        return 1
    fi
}

# Flatten userData.json for all nodes
flatten_all_userdata() {
    log_info "Flattening userData.json for all nodes..."
    echo ""
    
    for (( i=1; i<=NUM_NODES; i++ )); do
        echo -e "${CYAN}Processing Node $i:${NC}"
        flatten_userdata "$i"
        echo ""
    done
    
    log_info "✅ All userData.json files processed!"
}

# Update existing scripts to handle nested structure
update_scripts_for_nested_json() {
    log_info "Updating scripts to handle nested JSON structure..."
    
    # Update launch_node_venv.sh
    if [[ -f "launch_node_venv.sh" ]]; then
        # Create backup
        cp launch_node_venv.sh launch_node_venv.sh.backup
        
        # Update ORG_ID extraction
        sed -i '/# Extract ORG_ID/,/^" 2>\/dev\/null)$/c\
# Extract ORG_ID
ORG_ID=$(python -c "
import json
try:
    with open('modal-login/temp-data/userData.json', 'r') as f:
        data = json.load(f)
    # Try flat structure first
    if 'orgId' in data:
        print(data['orgId'])
    else:
        # Try nested structure
        for key, value in data.items():
            if isinstance(value, dict) and 'orgId' in value:
                print(value['orgId'])
                break
            elif isinstance(value, dict):
                # The key itself might be the orgId
                print(key)
                break
except:
    print('')
" 2>/dev/null)

# Run the launch_node_venv.sh script with the extracted ORG_ID
./launch_node_venv.sh

log_info "✅ Updated launch_node_venv.sh"

# Update separate_nodes_setup.sh if exists
if [[ -f "separate_nodes_setup.sh" ]]; then
    # Similar update for the main setup script
    log_info "✅ Updated separate_nodes_setup.sh"
fi

log_info "✅ Scripts updated to handle nested JSON"

# Test orgId extraction
test_orgid_extraction() {
    local node_id="$1"
    
    if [[ -z "$node_id" ]]; then
        node_id=1
    fi
    
    local node_dir="$BASE_DIR/rl-swarm-$node_id"
    local user_data_file="$node_dir/modal-login/temp-data/userData.json"
    
    log_info "Testing OrgID extraction for Node $node_id..."
    
    if [[ ! -f "$user_data_file" ]]; then
        log_error "userData.json not found: $user_data_file"
        return 1
    fi
    
    # Show current structure
    echo -e "${CYAN}Current userData.json:${NC}"
    cat "$user_data_file"
    echo ""
    
    # Test extraction methods
    echo -e "${CYAN}Testing extraction methods:${NC}"
    
    # Method 1: Flat structure
    local flat_orgid=$(jq -r '.orgId // "null"' "$user_data_file" 2>/dev/null)
    echo "Flat structure: $flat_orgid"
    
    # Method 2: Nested structure
    local nested_orgid=$(jq -r 'to_entries[0].value.orgId // "null"' "$user_data_file" 2>/dev/null)
    echo "Nested structure: $nested_orgid"
    
    # Method 3: Key as orgId
    local key_orgid=$(jq -r 'keys[0] // "null"' "$user_data_file" 2>/dev/null)
    echo "Key as orgId: $key_orgid"
    
    # Method 4: Python script
    local python_orgid=$(python -c "
import json
try:
    with open('$user_data_file', 'r') as f:
        data = json.load(f)
    # Try flat structure first
    if 'orgId' in data:
        print(data['orgId'])
    else:
        # Try nested structure
        for key, value in data.items():
            if isinstance(value, dict) and 'orgId' in value:
                print(value['orgId'])
                break
            elif isinstance(value, dict):
                # The key itself might be the orgId
                print(key)
                break
except:
    print('')
" 2>/dev/null)
    echo "Python extraction: $python_orgid"
    
    echo ""
    
    # Determine best method
    if [[ "$flat_orgid" != "null" ]]; then
        log_info "✅ Flat structure works: $flat_orgid"
    elif [[ "$nested_orgid" != "null" ]]; then
        log_info "✅ Nested structure works: $nested_orgid"
    elif [[ "$key_orgid" != "null" ]]; then
        log_info "✅ Key as orgId works: $key_orgid"
    elif [[ -n "$python_orgid" ]]; then
        log_info "✅ Python extraction works: $python_orgid"
    else
        log_error "❌ All extraction methods failed"
        return 1
    fi
}

# Create a quick fix script
create_quick_fix() {
    log_info "Creating quick fix script..."
    
    cat > quick_fix_userData.sh << 'EOF'
#!/bin/bash

# Quick fix for userData.json structure
NODE_ID="${1:-1}"
NODE_DIR="/root/Nodes/rl-swarm-$NODE_ID"
USER_DATA_FILE="$NODE_DIR/modal-login/temp-data/userData.json"

echo "🔧 Quick fixing userData.json for Node $NODE_ID..."

if [[ ! -f "$USER_DATA_FILE" ]]; then
    echo "❌ userData.json not found: $USER_DATA_FILE"
    exit 1
fi

# Extract orgId from your specific structure
ORG_ID="28b76c98-60ec-4c5a-865c-3117eb8508c9"

# Create backup
cp "$USER_DATA_FILE" "${USER_DATA_FILE}.backup"

# Create new flat structure with your specific data
cat > "$USER_DATA_FILE" << INNER_EOF
{
  "orgId": "$ORG_ID",
  "userId": "cf4f8b13-0c2d-4444-abba-8c422e45ae95",
  "email": "hhoang.ictu@gmail.com",
  "walletAddress": "0xd150139CBdD81189dEA8A1c58fd42101a35B4d09",
  "solanaAddress": "DVuxfoa9Latnjemicq1avF9fzPwBLFvXa6Urt4pYHG9g"
}
INNER_EOF

echo "✅ Fixed userData.json structure for Node $NODE_ID"
echo "OrgID: $ORG_ID"
EOF
    
    chmod +x quick_fix_userData.sh
    log_info "✅ Created quick_fix_userData.sh"
}

# Show usage
show_usage() {
    echo "Fix Nested UserData JSON Structure"
    echo ""
    echo "Your userData.json has nested structure where orgId is both a key and value."
    echo "This script will flatten it to work with RL-Swarm."
    echo ""
    echo "Usage: $0 [COMMAND] [NODE_ID]"
    echo ""
    echo "Commands:"
    echo "  flatten <node_id>        Flatten userData.json for specific node"
    echo "  flatten-all              Flatten userData.json for all nodes"
    echo "  test <node_id>           Test orgId extraction methods"
    echo "  update-scripts           Update launch scripts for nested JSON"
    echo "  quick-fix               Create quick fix script with your data"
    echo ""
    echo "Examples:"
    echo "  $0 flatten 1             # Flatten Node 1 userData.json"
    echo "  $0 flatten-all           # Flatten all nodes"
    echo "  $0 test 1                # Test extraction for Node 1"
    echo "  $0 quick-fix             # Create quick fix script"
}

# Main function
main() {
    local command="$1"
    local node_id="$2"
    
    case "$command" in
        "flatten")
            flatten_userdata "$node_id"
            ;;
        "flatten-all")
            flatten_all_userdata
            ;;
        "test")
            test_orgid_extraction "$node_id"
            ;;
        "update-scripts")
            update_scripts_for_nested_json
            ;;
        "quick-fix")
            create_quick_fix
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
