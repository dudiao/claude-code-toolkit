#!/bin/bash
# 飞书自建应用富文本通知脚本

LOG_DIR=~/.claude/logs
mkdir -p "$LOG_DIR"

# 按天滚动日志，保留7天
LOG_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/feishu-notify-$LOG_DATE.log"

# 清理7天前的日志
find "$LOG_DIR" -name "feishu-notify-*.log" -mtime +7 -delete 2>/dev/null

log_debug() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

INPUT=$(cat)
log_debug "输入: $INPUT"

CONFIG_FILE=~/.claude/feishu-config.txt
APP_ID=$(sed -n '1p' "$CONFIG_FILE" | tr -d '\n')
APP_SECRET=$(sed -n '2p' "$CONFIG_FILE" | tr -d '\n')
RECEIVE_ID=$(sed -n '3p' "$CONFIG_FILE" | tr -d '\n')

if [ -z "$APP_ID" ] || [ -z "$APP_SECRET" ] || [ -z "$RECEIVE_ID" ]; then
    log_debug "未配置飞书应用信息"
    exit 0
fi

MESSAGE=$(echo "$INPUT" | jq -r '.message // .notification_message // "Claude Code 有新通知"' 2>/dev/null || echo "Claude Code 有新通知")
NOTIFY_TYPE=$(echo "$INPUT" | jq -r '.notification_type // .type // "unknown"' 2>/dev/null || echo "unknown")

# 从 message 中提取工具名称，如 "Claude needs your permission to use Bash" -> "Bash"
TOOL_NAME=$(echo "$MESSAGE" | sed -n 's/.*use \([A-Za-z]*\)$/\1/p')

if [ "$NOTIFY_TYPE" = "idle_prompt" ]; then
    log_debug "忽略 idle_prompt"
    exit 0
fi

log_debug "类型: $NOTIFY_TYPE, 内容: $MESSAGE"

CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
PROJECT_NAME=""
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
    PROJECT_NAME=$(basename "$CLAUDE_PROJECT_DIR" 2>/dev/null || echo "")
fi

case "$NOTIFY_TYPE" in
    "permission_prompt") CARD_COLOR="orange"; TITLE_SUFFIX="权限请求" ;;
    "subagent_complete") CARD_COLOR="green"; TITLE_SUFFIX="任务完成" ;;
    *) CARD_COLOR="blue"; TITLE_SUFFIX="Claude Code 通知" ;;
esac

# 标题中包含项目名称和工具名称
if [ -n "$PROJECT_NAME" ] && [ -n "$TOOL_NAME" ]; then
    TITLE="$PROJECT_NAME: use $TOOL_NAME"
elif [ -n "$PROJECT_NAME" ]; then
    TITLE="$PROJECT_NAME: $TITLE_SUFFIX"
elif [ -n "$TOOL_NAME" ]; then
    TITLE="use $TOOL_NAME"
else
    TITLE="$TITLE_SUFFIX"
fi

CARD_CONTENT="$MESSAGE"

TOKEN_RESPONSE=$(curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
    -H "Content-Type: application/json" \
    -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.tenant_access_token')
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    log_debug "获取token失败"
    exit 0
fi

CARD_JSON=$(jq -n \
    --arg title "$TITLE" \
    --arg color "$CARD_COLOR" \
    --arg content "$CARD_CONTENT" \
    --arg time "$CURRENT_TIME" \
    '{"config":{"wide_screen_mode":true},"header":{"title":{"tag":"plain_text","content":$title},"template":$color},"elements":[{"tag":"markdown","content":$content},{"tag":"hr"},{"tag":"note","elements":[{"tag":"plain_text","content":$time}]}]}')

REQUEST_BODY=$(jq -n \
    --arg receive_id "$RECEIVE_ID" \
    --argjson card "$CARD_JSON" \
    '{"receive_id":$receive_id,"msg_type":"interactive","content":($card|tostring)}')

RESPONSE=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY")

CODE=$(echo "$RESPONSE" | jq -r '.code')
if [ "$CODE" = "0" ]; then
    log_debug "推送成功"
    echo "飞书推送成功"
else
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.msg // .error.message // "未知错误"')
    log_debug "推送失败: code=$CODE, msg=$ERROR_MSG"
    echo "飞书推送失败: $ERROR_MSG"
fi

exit 0