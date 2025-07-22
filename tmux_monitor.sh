#!/bin/bash

sudo -i <<'EOF'
cat > /root/tmux_monitor.sh << 'SCRIPT'
#!/bin/bash
SESSION_NAME="0"
WORK_DIR="rl-swarm"
VENV_PATH=".venv/bin/activate"
RUN_SCRIPT="./run_rl_swarm.sh"

if ! /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    cd /home/ubuntu
    /usr/bin/tmux new-session -d -s "$SESSION_NAME"
    /usr/bin/tmux send-keys -t "$SESSION_NAME" "cd $WORK_DIR" Enter
    /usr/bin/tmux send-keys -t "$SESSION_NAME" "source $VENV_PATH" Enter
    /usr/bin/tmux send-keys -t "$SESSION_NAME" "$RUN_SCRIPT" Enter
fi
SCRIPT

chmod +x /root/tmux_monitor.sh
echo '*/5 * * * * root /root/tmux_monitor.sh' >> /etc/crontab
systemctl restart cron
echo "Setup complete"
EOF
