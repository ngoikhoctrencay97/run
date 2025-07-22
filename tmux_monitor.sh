#!/bin/bash

cat > /home/ubuntu/tmux_monitor.sh << 'SCRIPT'
#!/bin/bash
SESSION_NAME="0"
WORK_DIR="rl-swarm"
VENV_PATH=".venv/bin/activate"
RUN_SCRIPT="./run_rl_swarm.sh"
if ! /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    cd /home/ubuntu
    sleep 1
    /usr/bin/tmux new-session -d -s "$SESSION_NAME"
    sleep 1
    /usr/bin/tmux send-keys -t "$SESSION_NAME" "cd $WORK_DIR" Enter
    sleep 1
    /usr/bin/tmux send-keys -t "$SESSION_NAME" "source $VENV_PATH" Enter
    sleep 1
    /usr/bin/tmux send-keys -t "$SESSION_NAME" "$RUN_SCRIPT" Enter
fi
SCRIPT

chmod +x /home/ubuntu/tmux_monitor.sh
echo '*/5 * * * * /home/ubuntu/tmux_monitor.sh' | crontab -
sudo systemctl restart cron
echo "Setup complete"
crontab -l | grep tmux_monitor && echo "✓ Cron job added" || echo "✗ Cron job failed"
