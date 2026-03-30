# 飞书通知 Hook

Claude Code 的 Notification hook，将通知推送到飞书机器人。

## 文件位置

```
~/.claude/hooks/feishu-notify.sh    # 通知脚本
~/.claude/feishu-config.txt         # 飞书应用配置
~/.claude/logs/feishu-notify-YYYY-MM-DD.log  # 日志（按天滚动，保留7天）
```

## 配置

### 1. 创建飞书自建应用

1. 登录飞书开放平台 https://open.feishu.cn/
2. 创建企业自建应用
3. 开通以下权限：
   - `im:message` - 获取与发送消息
   - `im:message:send_as_bot` - 以应用身份发消息
4. 获取 App ID 和 App Secret
5. 获取接收人的 Open ID（可在飞书个人资料中查看）

### 2. 创建配置文件

`~/.claude/feishu-config.txt`（每行一个配置项）：

```
<APP_ID>
<APP_SECRET>
<RECEIVE_ID>  # 接收人的 open_id
```

### 3. 配置 settings.json

在 `~/.claude/settings.json` 中添加 hook：

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "command": "/Users/你的用户名/.claude/hooks/feishu-notify.sh",
            "timeout": 30,
            "type": "command"
          }
        ]
      }
    ]
  }
}
```

### 4. 设置脚本执行权限

```bash
chmod +x ~/.claude/hooks/feishu-notify.sh
```

## 通知类型

| 类型 | 颜色 | 标题 |
|------|------|------|
| permission_prompt | 红色 | 权限请求 |
| subagent_complete | 绿色 | 任务完成 |
| 其他 | 蓝色 | Claude Code 通知 |

## 日志

日志按天滚动，保留 7 天：

```
[13:10:02] 输入: {"notification_type": "permission_prompt", "message": "..."}
[13:10:02] 类型: permission_prompt, 内容: ...
[13:10:03] 推送成功
```

## 测试

```bash
echo '{"notification_type": "permission_prompt", "message": "测试消息"}' | ~/.claude/hooks/feishu-notify.sh
```

## 排查问题

1. 检查脚本执行权限：`ls -la ~/.claude/hooks/feishu-notify.sh`
2. 查看日志：`cat ~/.claude/logs/feishu-notify-$(date '+%Y-%m-%d').log`
3. 手动测试脚本是否正常工作

## 注意事项

- 使用绝对路径配置 hook（不要用 `~`）
- 超时建议设置 30 秒以上
- `idle_prompt` 类型通知会被忽略（避免频繁通知）