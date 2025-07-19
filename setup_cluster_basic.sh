#!/bin/bash

CLUSTER_DIR="rl-swarm-cluster"
REPO_URL="https://github.com/gensyn-ai/rl-swarm"
TOTAL_NODES=10

echo "🚀 Setting up RL-Swarm cluster with $TOTAL_NODES nodes..."

# Tạo thư mục cluster
mkdir -p $CLUSTER_DIR
cd $CLUSTER_DIR

# Tạo thư mục credentials
mkdir -p credentials

echo "📁 Created cluster structure:"
echo "   $CLUSTER_DIR/"
echo "   ├── credentials/          <- Place your credential files here"
echo "   ├── node_1/"
echo "   ├── node_2/"
echo "   └── ... (up to node_$TOTAL_NODES)"

# Setup từng node
for i in $(seq 1 $TOTAL_NODES); do
    echo "🔧 Setting up node_$i..."
    
    # Tạo thư mục node
    mkdir -p "node_$i"
    cd "node_$i"
    
    # Clone repository
    if [ ! -d ".git" ]; then
        echo "  📥 Cloning repository..."
        git clone $REPO_URL .
    fi
    
    # Tạo virtual environment riêng
    echo "  🐍 Creating virtual environment..."
    python -m venv venv_node_$i
    source venv_node_$i/bin/activate
    
    # Install requirements nếu có
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        # Install basic packages
        pip install torch torchvision numpy pandas requests
    fi
    
    deactivate
    
    # Tạo thư mục cho logs và data
    mkdir -p logs data temp
    
    cd ..
    
    echo "  ✅ Node_$i setup completed"
done

echo ""
echo "🎉 Basic cluster setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Place your credential files in $CLUSTER_DIR/credentials/:"
echo "   - swarm.pem"
echo "   - userApiKey.json"
echo "   - userData.json"
echo ""
echo "2. Run: python prepare_credentials.py"
echo "3. Run: python run_cluster.py"
