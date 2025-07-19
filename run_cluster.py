import os
import subprocess
import time
import signal
import sys
from pathlib import Path

class ClusterManager:
    def __init__(self, cluster_dir="rl-swarm-cluster", total_nodes=10):
        self.cluster_dir = Path(cluster_dir)
        self.total_nodes = total_nodes
        self.processes = []
        
    def create_node_script(self, node_id):
        """Tạo script chạy cho từng node"""
        node_dir = self.cluster_dir / f"node_{node_id}"
        
        script_content = f'''#!/bin/bash

# RL-Swarm Node {node_id} Runner
NODE_ID="node_{node_id}"
NODE_DIR="$(pwd)"
PORT=$((8000 + {node_id}))

echo "🚀 Starting RL-Swarm Node {node_id}..."
echo "Node Directory: $NODE_DIR"
echo "Port: $PORT"

# Activate virtual environment
source venv_node_{node_id}/bin/activate

# Check required files
REQUIRED_FILES=("swarm.pem" "userApiKey.json" "userData.json")
for file in "${{REQUIRED_FILES[@]}}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        echo "Please run: python prepare_credentials.py"
        exit 1
    fi
done

# Set proper permissions
chmod 600 swarm.pem

# Environment variables
export CUDA_VISIBLE_DEVICES=0
export NODE_ID="$NODE_ID"
export GPU_MEMORY_FRACTION=0.1

# GPU Memory settings
export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:8192"
export TF_MEMORY_GROWTH=true

# Create log file with timestamp
LOG_FILE="logs/node_{node_id}_$(date +%Y%m%d_%H%M%S).log"
echo "📝 Logging to: $LOG_FILE"

# Run the main application
echo "🏃 Running main application..."
python main.py \\
    --node-id "$NODE_ID" \\
    --port "$PORT" \\
    --gpu-memory-fraction 0.1 \\
    2>&1 | tee "$LOG_FILE"

EXIT_CODE=${{PIPESTATUS[0]}}

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Node {node_id} completed successfully"
else
    echo "❌ Node {node_id} failed with exit code: $EXIT_CODE"
fi

deactivate
exit $EXIT_CODE
'''
        
        script_path = node_dir / f"run_node_{node_id}.sh"
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(script_path, 0o755)
        return script_path
    
    def check_node_ready(self, node_id):
        """Check if node is ready to run"""
        node_dir = self.cluster_dir / f"node_{node_id}"
        
        required_files = [
            node_dir / "swarm.pem",
            node_dir / "userApiKey.json", 
            node_dir / "userData.json",
            node_dir / "main.py"
        ]
        
        missing_files = [f.name for f in required_files if not f.exists()]
        
        if missing_files:
            print(f"❌ Node_{node_id} missing files: {missing_files}")
            return False
        
        return True
    
    def start_node(self, node_id):
        """Start a specific node"""
        if not self.check_node_ready(node_id):
            print(f"❌ Node_{node_id} not ready. Run 'python prepare_credentials.py' first.")
            return None
        
        node_dir = self.cluster_dir / f"node_{node_id}"
        script_path = self.create_node_script(node_id)
        
        # Environment variables
        env = os.environ.copy()
        env.update({
            'NODE_ID': f'node_{node_id}',
            'CUDA_VISIBLE_DEVICES': '0',
            'GPU_MEMORY_FRACTION': '0.1'
        })
        
        print(f"🚀 Starting node_{node_id}...")
        
        try:
            process = subprocess.Popen(
                [str(script_path)],
                cwd=node_dir,
                env=env,
                preexec_fn=os.setsid
            )
            
            self.processes.append({
                'node_id': node_id,
                'process': process,
                'script_path': script_path
            })
            
            return process
            
        except Exception as e:
            print(f"❌ Failed to start node_{node_id}: {e}")
            return None
    
    def start_all_nodes(self):
        """Start all nodes"""
        print(f"🚀 Starting {self.total_nodes} nodes...")
        
        success_count = 0
        for i in range(1, self.total_nodes + 1):
            process = self.start_node(i)
            if process:
                success_count += 1
                print(f"✅ Node_{i} started")
                time.sleep(3)  # Stagger startup
            else:
                print(f"❌ Failed to start node_{i}")
        
        print(f"🎉 Successfully started {success_count}/{self.total_nodes} nodes")
    
    def stop_all_nodes(self):
        """Stop all nodes"""
        print("🛑 Stopping all nodes...")
        
        for proc_info in self.processes:
            try:
                os.killpg(os.getpgid(proc_info['process'].pid), signal.SIGTERM)
                print(f"✅ Stopped node_{proc_info['node_id']}")
            except:
                try:
                    proc_info['process'].terminate()
                except:
                    pass
        
        time.sleep(3)
        
        # Force kill if needed
        for proc_info in self.processes:
            try:
                if proc_info['process'].poll() is None:
                    proc_info['process'].kill()
            except:
                pass
        
        self.processes.clear()
        print("🎉 All nodes stopped")
    
    def monitor_nodes(self):
        """Monitor running nodes"""
        print("👀 Monitoring nodes (Press Ctrl+C to stop all)...")
        
        try:
            while True:
                active_nodes = []
                
                for proc_info in self.processes[:]:
                    if proc_info['process'].poll() is None:
                        active_nodes.append(proc_info['node_id'])
                    else:
                        exit_code = proc_info['process'].returncode
                        print(f"⚠️  Node_{proc_info['node_id']} stopped (exit code: {exit_code})")
                        self.processes.remove(proc_info)
                
                print(f"📊 Active: {len(active_nodes)}/{self.total_nodes} nodes - {active_nodes}")
                
                if len(active_nodes) == 0:
                    print("⚠️  All nodes stopped")
                    break
                
                time.sleep(30)
                
        except KeyboardInterrupt:
            print("\n🛑 Interrupt received")
            self.stop_all_nodes()

def main():
    cluster = ClusterManager()
    
    # Signal handlers
    def signal_handler(signum, frame):
        print("\n🛑 Stopping all nodes...")
        cluster.stop_all_nodes()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        cluster.start_all_nodes()
        cluster.monitor_nodes()
    except Exception as e:
        print(f"❌ Error: {e}")
        cluster.stop_all_nodes()

if __name__ == "__main__":
    main()
