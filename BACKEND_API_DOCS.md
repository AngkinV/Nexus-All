# Nexus Chat 后端API文档

## 📋 概述

本文档描述了Nexus Chat后端新增和更新的API端点，用于支持群组管理、联系人管理、用户资料、文件分享和实时WebSocket通信。

---

## 📁 文件上传API (File Upload API)

### 基础URL: `/api/files`

| 方法 | 端点 | 描述 | 请求参数 | 响应 |
|------|------|------|----------|------|
| POST | `/api/files/upload` | 单文件上传(≤100MB) | `MultipartFile file, Long uploaderId` | `FileUploadResponse` |
| POST | `/api/files/upload/chunk` | 分片上传(大文件) | 见下方 | `ChunkUploadResponse` |
| GET | `/api/files/{fileId}/info` | 获取文件信息 | - | `FileUploadResponse` |
| GET | `/api/files/download/{fileId}` | 下载文件 | - | `Resource` |
| GET | `/api/files/preview/{fileId}` | 预览文件(内联显示) | - | `Resource` |

### 单文件上传

**请求示例:**
```bash
curl -X POST "http://localhost:8080/api/files/upload" \
  -F "file=@/path/to/file.jpg" \
  -F "uploaderId=1"
```

**响应示例:**
```json
{
  "fileId": "ed5dbe48-4b4c-4712-8cf4-60cfe7108b85",
  "fileUrl": "/uploads/2026/02/06/ed5dbe48-4b4c-4712-8cf4-60cfe7108b85.jpg",
  "downloadUrl": "/files/download/ed5dbe48-4b4c-4712-8cf4-60cfe7108b85",
  "previewUrl": "/files/preview/ed5dbe48-4b4c-4712-8cf4-60cfe7108b85",
  "filename": "photo.jpg",
  "originalName": "photo.jpg",
  "size": 102400,
  "mimeType": "image/jpeg",
  "expiresAt": "2026-03-08T10:00:00"
}
```

### 分片上传 (大文件 > 5MB)

**请求参数:**
| 参数 | 类型 | 必填 | 描述 |
|------|------|------|------|
| file | MultipartFile | 是 | 分片数据 |
| chunkIndex | int | 是 | 当前分片索引(从0开始) |
| totalChunks | int | 是 | 总分片数 |
| fileId | String | 是 | 文件唯一ID(客户端生成UUID) |
| filename | String | 否 | 原始文件名(最后一个分片必填) |
| totalSize | Long | 否 | 文件总大小 |
| uploaderId | Long | 否 | 上传者用户ID |

**分片上传流程:**
1. 客户端将文件分成多个5MB的分片
2. 生成唯一fileId (UUID)
3. 依次上传每个分片
4. 最后一个分片上传完成后,服务器自动合并

**响应示例 (非最后分片):**
```json
{
  "chunkIndex": 0,
  "uploaded": true,
  "complete": false
}
```

**响应示例 (最后分片):**
```json
{
  "chunkIndex": 2,
  "uploaded": true,
  "complete": true,
  "fileId": "...",
  "fileUrl": "...",
  "downloadUrl": "...",
  "previewUrl": "...",
  "filename": "largefile.zip",
  "size": 15728640,
  "mimeType": "application/zip"
}
```

### 文件功能特性

- **秒传**: 基于MD5哈希检测重复文件，相同文件秒传
- **自动清理**: 文件30天后过期，定时任务自动清理
- **MIME类型**: 自动识别常见文件类型
- **支持格式**: 图片、视频、音频、文档、压缩包等

### 支持的消息类型

| 类型 | 描述 | MIME前缀 |
|------|------|----------|
| IMAGE | 图片消息 | image/* |
| VIDEO | 视频消息 | video/* |
| AUDIO | 音频消息 | audio/* |
| FILE | 文件消息 | 其他类型 |

---

## 🔌 群组API (Group API)

### 基础URL: `/api/groups`

| 方法 | 端点 | 描述 | 请求参数 | 响应 |
|------|------|------|----------|------|
| POST | `/api/groups?userId={userId}` | 创建群组 | `CreateGroupRequest` | `GroupDTO` |
| GET | `/api/groups/{id}` | 获取群组详情 | - | `GroupDTO` |
| PUT | `/api/groups/{id}?userId={userId}` | 更新群组信息 | `UpdateGroupRequest` | `GroupDTO` |
| DELETE | `/api/groups/{id}?userId={userId}` | 删除/解散群组 | - | - |
| POST | `/api/groups/{id}/members?userId={userId}` | 添加成员 | `AddMembersRequest` | - |
| DELETE | `/api/groups/{id}/members/{memberId}?userId={userId}` | 移除成员 | - | - |
| POST | `/api/groups/{id}/leave?userId={userId}` | 退出群组 | - | - |
| GET | `/api/groups/{id}/members` | 获取成员列表 | - | `UserDTO[]` |
| GET | `/api/groups/user/{userId}` | 获取用户加入的群组 | - | `GroupDTO[]` |

### 请求体示例

**CreateGroupRequest:**
```json
{
  "name": "技术交流群",
  "description": "讨论技术问题的群组",
  "avatar": "data:image/png;base64,...",
  "isPrivate": false,
  "memberIds": [2, 3, 4]
}
```

**UpdateGroupRequest:**
```json
{
  "name": "新群名",
  "description": "新描述",
  "avatar": "新头像URL",
  "isPrivate": true
}
```

---

## 👥 联系人API (Contact API)

### 基础URL: `/api/contacts`

| 方法 | 端点 | 描述 | 请求参数 | 响应 |
|------|------|------|----------|------|
| POST | `/api/contacts` | 添加联系人 | `AddContactRequest` | `ContactDTO` |
| DELETE | `/api/contacts` | 删除联系人 | `AddContactRequest` | - |
| GET | `/api/contacts/user/{userId}` | 获取联系人列表(基础) | - | `UserDTO[]` |
| GET | `/api/contacts/user/{userId}/detailed` | 获取联系人列表(详细) | - | `ContactDTO[]` |
| GET | `/api/contacts/check?userId={}&contactUserId={}` | 检查是否为联系人 | - | `{ isContact: boolean }` |
| GET | `/api/contacts/mutual?userId1={}&userId2={}` | 获取共同联系人 | - | `UserDTO[]` |

### 请求体示例

**AddContactRequest:**
```json
{
  "userId": 1,
  "contactUserId": 2
}
```

---

## 👤 用户API (User API)

### 基础URL: `/api/users`

| 方法 | 端点 | 描述 | 请求参数 | 响应 |
|------|------|------|----------|------|
| GET | `/api/users/{id}` | 获取用户基本信息 | - | `UserDTO` |
| GET | `/api/users/username/{username}` | 通过用户名获取用户 | - | `UserDTO` |
| GET | `/api/users` | 获取所有用户 | - | `UserDTO[]` |
| GET | `/api/users/search?query={}` | 搜索用户 | query: 搜索关键词 | `UserDTO[]` |
| GET | `/api/users/recommended?userId={}&limit={}` | 获取推荐用户 | userId, limit | `UserDTO[]` |
| GET | `/api/users/{id}/profile` | 获取用户完整资料 | - | `UserProfileDTO` |
| GET | `/api/users/{id}/profile/view?viewerId={}` | 获取用户资料(隐私过滤) | viewerId | `UserProfileDTO` |
| PUT | `/api/users/{id}/profile` | 更新用户资料 | `UpdateProfileRequest` | `UserProfileDTO` |
| POST | `/api/users/{id}/avatar` | 上传头像(文件) | `MultipartFile` | `{ avatarUrl: string }` |
| POST | `/api/users/{id}/avatar/base64` | 上传头像(Base64) | `{ avatar: string }` | `{ avatarUrl: string }` |
| DELETE | `/api/users/{id}/avatar` | 删除头像 | - | - |
| PUT | `/api/users/{id}/privacy` | 更新隐私设置 | `PrivacySettingsDTO` | `PrivacySettingsDTO` |
| GET | `/api/users/{id}/stats` | 获取用户统计 | - | `UserStatsDTO` |
| PUT | `/api/users/{id}/status?isOnline={}` | 更新在线状态 | isOnline: boolean | - |

### 请求体示例

**UpdateProfileRequest:**
```json
{
  "nickname": "新昵称",
  "bio": "个人简介",
  "email": "email@example.com",
  "phone": "13800138000"
}
```

**PrivacySettingsDTO:**
```json
{
  "showOnlineStatus": true,
  "showLastSeen": true,
  "showEmail": false,
  "showPhone": false
}
```

---

## 🔌 WebSocket事件

### 连接端点
- **STOMP over WebSocket**: `ws://localhost:8080/ws`
- **SockJS fallback**: `http://localhost:8080/ws`

### 客户端 → 服务器 (发送消息)

| 目的地 | 事件 | 描述 | 载荷 |
|--------|------|------|------|
| `/app/chat.sendMessage` | 发送消息 | 发送聊天消息 | `{ chatId, senderId, content, messageType, fileUrl }` |
| `/app/user.status` | 用户状态 | 更新在线状态 | `{ userId, isOnline }` |
| `/app/chat.typing` | 输入状态 | 输入指示器 | `{ chatId, userId, isTyping }` |
| `/app/message.read` | 消息已读 | 标记消息已读 | `{ chatId, userId, messageId }` |
| `/app/group.create` | 创建群组 | 通过WS创建群组 | `{ userId, name, description, isPrivate, memberIds }` |
| `/app/group.join` | 加入群组 | 添加用户到群组 | `{ groupId, userId, adminUserId }` |
| `/app/group.leave` | 离开群组 | 退出群组 | `{ groupId, userId }` |
| `/app/group.message` | 群组消息 | 发送群组消息 | `{ groupId, senderId, content, messageType }` |
| `/app/contact.add` | 添加联系人 | 添加联系人 | `{ userId, contactUserId }` |
| `/app/contact.remove` | 删除联系人 | 删除联系人 | `{ userId, contactUserId }` |

### 服务器 → 客户端 (订阅频道)

| 订阅目的地 | 事件类型 | 描述 |
|------------|----------|------|
| `/topic/chat/{chatId}` | CHAT_MESSAGE | 聊天室消息 |
| `/topic/chat/{chatId}` | TYPING | 输入状态 |
| `/topic/chat/{chatId}` | MESSAGE_READ | 消息已读 |
| `/topic/users` | USER_ONLINE / USER_OFFLINE | 用户状态变化 |
| `/topic/group/{groupId}` | GROUP_MESSAGE | 群组消息 |
| `/topic/group/{groupId}` | GROUP_MEMBER_JOINED | 成员加入 |
| `/topic/group/{groupId}` | GROUP_MEMBER_LEFT | 成员离开 |
| `/user/{userId}/queue/contacts` | CONTACT_ADDED | 联系人添加 |
| `/user/{userId}/queue/contacts` | CONTACT_REMOVED | 联系人删除 |
| `/user/{userId}/queue/contacts` | CONTACT_STATUS_CHANGED | 联系人状态变化 |
| `/user/{userId}/queue/groups` | GROUP_CREATED | 群组创建 |
| `/user/{userId}/queue/errors` | ERROR | 错误通知 |

### WebSocketMessage格式
```json
{
  "type": "CHAT_MESSAGE | USER_ONLINE | GROUP_CREATED | ...",
  "payload": { ... }
}
```

---

## 📊 DTO结构

### UserDTO
```json
{
  "id": 1,
  "username": "john",
  "nickname": "John Doe",
  "avatarUrl": "...",
  "isOnline": true,
  "lastSeen": "2025-12-07T10:00:00"
}
```

### UserProfileDTO
```json
{
  "id": 1,
  "username": "john",
  "nickname": "John Doe",
  "email": "john@example.com",
  "phone": "13800138000",
  "avatarUrl": "...",
  "bio": "个人简介",
  "isOnline": true,
  "lastSeen": "2025-12-07T10:00:00",
  "createdAt": "2025-01-01T00:00:00",
  "showOnlineStatus": true,
  "showLastSeen": true,
  "showEmail": false,
  "showPhone": false,
  "contactCount": 10,
  "groupCount": 5,
  "messageCount": 100
}
```

### GroupDTO
```json
{
  "id": 1,
  "name": "技术交流群",
  "description": "讨论技术问题",
  "avatar": "...",
  "type": "group",
  "isPrivate": false,
  "creatorId": 1,
  "memberCount": 5,
  "members": [UserDTO],
  "lastMessage": "最后一条消息内容",
  "lastMessageTime": "2025-12-07T10:00:00",
  "unreadCount": 3,
  "createdAt": "2025-12-01T00:00:00"
}
```

### ContactDTO
```json
{
  "id": 1,
  "userId": 2,
  "username": "jane",
  "nickname": "Jane Doe",
  "email": "jane@example.com",
  "phone": "13900139000",
  "avatarUrl": "...",
  "isOnline": true,
  "lastSeen": "2025-12-07T10:00:00",
  "addedAt": "2025-12-01T00:00:00"
}
```

### UserStatsDTO
```json
{
  "contactCount": 10,
  "groupCount": 5,
  "messageCount": 100
}
```

---

## 🗄️ 数据库表更新

### users表新增字段
```sql
ALTER TABLE users ADD COLUMN bio VARCHAR(150) DEFAULT NULL;
```

### chats表新增字段
```sql
ALTER TABLE chats ADD COLUMN description VARCHAR(200) DEFAULT NULL;
ALTER TABLE chats ADD COLUMN avatar_url MEDIUMTEXT;
ALTER TABLE chats ADD COLUMN is_private BOOLEAN DEFAULT FALSE;
ALTER TABLE chats ADD COLUMN member_count INT DEFAULT 1;
```

### chat_members表新增字段
```sql
ALTER TABLE chat_members ADD COLUMN role ENUM('owner', 'admin', 'member') DEFAULT 'member';
```

### user_privacy_settings表(新增)
```sql
CREATE TABLE IF NOT EXISTS user_privacy_settings (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL UNIQUE,
    show_online_status BOOLEAN DEFAULT TRUE,
    show_last_seen BOOLEAN DEFAULT TRUE,
    show_email BOOLEAN DEFAULT FALSE,
    show_phone BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### file_uploads表(新增)
```sql
CREATE TABLE IF NOT EXISTS file_uploads (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    file_id VARCHAR(36) NOT NULL UNIQUE,
    filename VARCHAR(255),
    original_name VARCHAR(255),
    stored_name VARCHAR(255),
    file_size BIGINT,
    mime_type VARCHAR(100),
    md5_hash VARCHAR(32),
    uploader_id BIGINT,
    message_id BIGINT,
    file_path VARCHAR(500),
    chunk_count INT DEFAULT 1,
    upload_complete BOOLEAN DEFAULT FALSE,
    expires_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_file_id (file_id),
    INDEX idx_md5_hash (md5_hash),
    INDEX idx_uploader_id (uploader_id),
    INDEX idx_expires_at (expires_at)
);
```

---

*文档更新时间: 2026-02-06*
*后端框架: Spring Boot + MySQL + WebSocket (STOMP)*
