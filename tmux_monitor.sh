#!/bin/bash

# Script kiểm tra và tự động tạo lại tmux session
# Chạy mỗi 5 phút một lần

SESSION_NAME="0"
WORK_DIR="rl-swarm"
VENV_PATH=".venv/bin/activate"
RUN_SCRIPT="./run_rl_swarm.sh"

check_and_restart_tmux() {
    # Kiểm tra xem session tmux có tồn tại không
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "$(date): Session tmux '$SESSION_NAME' không tồn tại. Đang tạo lại..."
        
        # Tạo session tmux mới
        tmux new-session -d -s "$SESSION_NAME"
        
        # Chạy các lệnh trong session
        tmux send-keys -t "$SESSION_NAME" "cd $WORK_DIR" Enter
        tmux send-keys -t "$SESSION_NAME" "source $VENV_PATH" Enter
        tmux send-keys -t "$SESSION_NAME" "$RUN_SCRIPT" Enter
        
        echo "$(date): Đã tạo lại session '$SESSION_NAME' và chạy rl-swarm"
    else
        echo "$(date): Session tmux '$SESSION_NAME' đang chạy bình thường"
    fi
}

# Nếu script được chạy với tham số "daemon", sẽ chạy liên tục
if [ "$1" = "daemon" ]; then
    echo "$(date): Bắt đầu monitor tmux session '$SESSION_NAME' (kiểm tra mỗi 5 phút)"
    
    while true; do
        check_and_restart_tmux
        sleep 300  # Chờ 5 phút (300 giây)
    done
else
    # Chạy một lần duy nhất
    check_and_restart_tmux
fi
