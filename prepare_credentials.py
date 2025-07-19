import json
import shutil
import os
from pathlib import Path

def prepare_credentials():
    cluster_dir = Path("rl-swarm-cluster")
    credentials_dir = cluster_dir / "credentials"
    
    print("🔧 Preparing credentials for all nodes...")
    
    # Check if credential files exist
    required_files = ["swarm.pem", "userApiKey.json", "userData.json"]
    missing_files = []
    
    for file_name in required_files:
        file_path = credentials_dir / file_name
        if not file_path.exists():
            missing_files.append(file_name)
    
    if missing_files:
        print("❌ Missing credential files in rl-swarm-cluster/credentials/:")
        for file_name in missing_files:
            print(f"   - {file_name}")
        print("\nPlease add these files and run again.")
        return False
    
    print("✅ All credential files found!")
    
    # Load base JSON files
    try:
        with open(credentials_dir / "userApiKey.json") as f:
            base_api_key = json.load(f)
        
        with open(credentials_dir / "userData.json") as f:
            base_user_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ Error reading JSON files: {e}")
        return False
    
    # Prepare credentials for each node
    for i in range(1, 11):
        node_dir = cluster_dir / f"node_{i}"
        
        print(f"🔑 Preparing credentials for node_{i}...")
        
        # Copy swarm.pem
        shutil.copy2(credentials_dir / "swarm.pem", node_dir / "swarm.pem")
        os.chmod(node_dir / "swarm.pem", 0o600)
        
        # Create modified userApiKey.json
        api_key_data = base_api_key.copy()
        
        # Add node-specific modifications
        api_key_data["node_id"] = f"node_{i}"
        
        # You might want to modify other fields based on your needs
        # For example:
        # if "account_id" in api_key_data:
        #     api_key_data["account_id"] = f"{api_key_data['account_id']}_node_{i}"
        
        with open(node_dir / "userApiKey.json", 'w') as f:
            json.dump(api_key_data, f, indent=2)
        
        # Create modified userData.json
        user_data = base_user_data.copy()
        
        # Add node-specific modifications
        user_data["node_id"] = f"node_{i}"
        user_data["port"] = 8000 + i
        
        # You might want to modify other fields:
        # if "worker_id" in user_data:
        #     user_data["worker_id"] = f"worker_{i}"
        
        with open(node_dir / "userData.json", 'w') as f:
            json.dump(user_data, f, indent=2)
        
        print(f"  ✅ Node_{i} credentials ready")
    
    print("\n🎉 All credentials prepared successfully!")
    print("\nYou can now run: python run_cluster.py")
    return True

if __name__ == "__main__":
    prepare_credentials()
