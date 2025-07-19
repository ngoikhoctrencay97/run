from pathlib import Path
import json

def check_cluster():
    cluster_dir = Path("rl-swarm-cluster")
    
    if not cluster_dir.exists():
        print("❌ Cluster directory not found. Run setup_cluster_basic.sh first.")
        return
    
    print("🔍 Checking cluster setup...\n")
    
    # Check credentials directory
    credentials_dir = cluster_dir / "credentials"
    print("📁 Credentials directory:")
    
    required_creds = ["swarm.pem", "userApiKey.json", "userData.json"]
    for file_name in required_creds:
        file_path = credentials_dir / file_name
        status = "✅" if file_path.exists() else "❌"
        print(f"   {status} {file_name}")
    
    print()
    
    # Check each node
    ready_nodes = 0
    for i in range(1, 11):
        node_dir = cluster_dir / f"node_{i}"
        print(f"🏠 Node_{i}:")
        
        checks = [
            (node_dir.exists(), "Directory"),
            ((node_dir / "main.py").exists(), "main.py"),
            ((node_dir / f"venv_node_{i}").exists(), "Virtual env"),
            ((node_dir / "swarm.pem").exists(), "swarm.pem"),
            ((node_dir / "userApiKey.json").exists(), "userApiKey.json"),
            ((node_dir / "userData.json").exists(), "userData.json"),
        ]
        
        node_ready = True
        for status, name in checks:
            icon = "✅" if status else "❌"
            print(f"   {icon} {name}")
            if not status:
                node_ready = False
        
        if node_ready:
            ready_nodes += 1
            
        print()
    
    print(f"📊 Summary: {ready_nodes}/10 nodes ready")
    
    if ready_nodes == 0:
        print("\n📋 Next steps:")
        print("1. Place credential files in rl-swarm-cluster/credentials/")
        print("2. Run: python prepare_credentials.py")
    elif ready_nodes < 10:
        print("\n⚠️  Some nodes not ready. Run: python prepare_credentials.py")
    else:
        print("\n🎉 All nodes ready! Run: python run_cluster.py")

if __name__ == "__main__":
    check_cluster()
