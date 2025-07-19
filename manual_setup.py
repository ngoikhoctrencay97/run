#!/usr/bin/env python3

import os
import sys
from pathlib import Path

def simple_setup():
    # Tao thu muc cluster
    os.makedirs("rl-swarm-cluster/credentials", exist_ok=True)
    
    print("Setting up 10 nodes...")
    
    for i in range(1, 11):
        print(f"\nNode {i}:")
        
        # Tao thu muc node
        node_path = f"rl-swarm-cluster/node_{i}"
        os.makedirs(node_path, exist_ok=True)
        
        # Di chuyen vao thu muc node
        os.chdir(node_path)
        print(f"  Working in: {os.getcwd()}")
        
        # Clone repo
        if not os.path.exists(".git"):
            print("  Cloning repository...")
            result = os.system("git clone https://github.com/gensyn-ai/rl-swarm . 2>/dev/null")
            if result == 0:
                print("  Repository cloned successfully")
            else:
                print("  Failed to clone repository")
                os.chdir("../..")
                continue
        
        # Tao virtual environment
        venv_name = f"venv_node_{i}"
        print(f"  Creating virtual environment: {venv_name}")
        
        # Xoa venv cu neu co
        if os.path.exists(venv_name):
            os.system(f"rm -rf {venv_name}")
        
        # Tao venv moi
        result = os.system(f"python3 -m venv {venv_name}")
        if result != 0:
            result = os.system(f"python -m venv {venv_name}")
        
        if result == 0:
            print("  Virtual environment created")
            
            # Kiem tra python executable
            python_exe = f"{venv_name}/bin/python"
            if os.path.exists(python_exe):
                print("  Python executable found")
                
                # Install packages
                print("  Installing packages...")
                os.system(f"{python_exe} -m pip install --upgrade pip --quiet")
                os.system(f"{python_exe} -m pip install torch numpy requests --quiet")
                print("  Packages installed")
            else:
                print("  Python executable not found")
        else:
            print("  Failed to create virtual environment")
        
        # Tao thu muc can thiet
        os.makedirs("logs", exist_ok=True)
        os.makedirs("data", exist_ok=True)
        os.makedirs("temp", exist_ok=True)
        
        # Quay lai thu muc goc
        os.chdir("../..")
        
        print(f"  Node {i} setup completed")
    
    print("\nSetup finished!")
    print("Next steps:")
    print("1. Place credential files in rl-swarm-cluster/credentials/")
    print("2. Run: python prepare_credentials.py")

if __name__ == "__main__":
    simple_setup()
