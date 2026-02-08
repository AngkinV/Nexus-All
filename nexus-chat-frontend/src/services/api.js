import axios from 'axios'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/api'

const apiClient = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json'
    }
})

// Add token to requests
apiClient.interceptors.request.use(config => {
    const token = localStorage.getItem('token')
    if (token) {
        config.headers.Authorization = `Bearer ${token}`
    }
    return config
})

// Auth API
export const authAPI = {
    register: ({ email, username, password, nickname, phone, avatarUrl, verificationCode }) =>
        apiClient.post('/auth/register', { email, username, password, nickname, phone, avatarUrl, verificationCode }),

    login: (usernameOrEmail, password) =>
        apiClient.post('/auth/login', { usernameOrEmail, password }),

    logout: (userId) =>
        apiClient.post('/auth/logout', null, { params: { userId } }),

    sendVerificationCode: (email, type = 'REGISTER') =>
        apiClient.post('/auth/send-code', { email, type }),

    verifyCode: (email, code, type = 'REGISTER') =>
        apiClient.post('/auth/verify-code', { email, code, type })
}

// User API
export const userAPI = {
    getUserById: (id) => apiClient.get(`/users/${id}`),

    getUserByUsername: (username) => apiClient.get(`/users/username/${username}`),

    getAllUsers: () => apiClient.get('/users'),

    searchUsers: (query) => apiClient.get('/users/search', { params: { query } }),

    getRecommendedUsers: (userId, limit = 10) =>
        apiClient.get('/users/recommended', { params: { userId, limit } }),

    getUserProfile: (id) => apiClient.get(`/users/${id}/profile`),

    getUserProfileForViewer: (id, viewerId) =>
        apiClient.get(`/users/${id}/profile/view`, { params: { viewerId } }),

    updateProfile: (id, data) =>
        apiClient.put(`/users/${id}/profile`, data),

    updateOnlineStatus: (id, isOnline) =>
        apiClient.put(`/users/${id}/status`, null, { params: { isOnline } }),

    updatePrivacySettings: (id, settings) =>
        apiClient.put(`/users/${id}/privacy`, settings),

    getUserStats: (id) => apiClient.get(`/users/${id}/stats`),

    // Profile background
    updateBackground: (id, background) =>
        apiClient.put(`/users/${id}/background`, { background }),

    // Social links
    getSocialLinks: (id) => apiClient.get(`/users/${id}/social-links`),

    addSocialLink: (id, platform, url) =>
        apiClient.post(`/users/${id}/social-links`, { platform, url }),

    deleteSocialLink: (id, platform) =>
        apiClient.delete(`/users/${id}/social-links/${encodeURIComponent(platform)}`),

    updateSocialLinks: (id, links) =>
        apiClient.put(`/users/${id}/social-links`, links),

    // Activities
    getUserActivities: (id, limit = 20) =>
        apiClient.get(`/users/${id}/activities`, { params: { limit } }),

    getFriendActivities: (id, limit = 20) =>
        apiClient.get(`/users/${id}/friend-activities`, { params: { limit } })
}

// Chat API
export const chatAPI = {
    createDirectChat: (userId, contactId) =>
        apiClient.post('/chats/direct', null, { params: { userId, contactId } }),

    createGroupChat: (userId, { name, description, avatar, isPrivate, memberIds }) =>
        apiClient.post('/chats/group', { name, description, avatar, isPrivate, memberIds }, { params: { userId } }),

    getUserChats: (userId) => apiClient.get(`/chats/user/${userId}`),

    getChatById: (chatId, userId) =>
        apiClient.get(`/chats/${chatId}`, { params: { userId } }),

    deleteChat: (chatId, userId) =>
        apiClient.delete(`/chats/${chatId}`, { params: { userId } })
}

// Message API
export const messageAPI = {
    sendMessage: (chatId, senderId, content, messageType = 'text', fileUrl = null) =>
        apiClient.post('/messages', { chatId, senderId, content, messageType, fileUrl }),

    getChatMessages: (chatId, userId, page = 0, size = 50) =>
        apiClient.get(`/messages/chat/${chatId}`, { params: { userId, page, size } }),

    markMessageAsRead: (messageId, userId) =>
        apiClient.put(`/messages/${messageId}/read`, null, { params: { userId } }),

    markChatMessagesAsRead: (chatId, userId) =>
        apiClient.put(`/messages/chat/${chatId}/read`, null, { params: { userId } })
}

// Contact API
export const contactAPI = {
    // 添加联系人（会根据目标用户的隐私设置决定是直接添加还是发送申请）
    addContact: (userId, contactUserId, message = null) =>
        apiClient.post('/contacts', { userId, contactUserId, message }),

    removeContact: (userId, contactUserId) =>
        apiClient.delete('/contacts', { data: { userId, contactUserId } }),

    getContacts: (userId) => apiClient.get(`/contacts/user/${userId}`),

    getContactsDetailed: (userId) => apiClient.get(`/contacts/user/${userId}/detailed`),

    checkIsContact: (userId, contactUserId) =>
        apiClient.get('/contacts/check', { params: { userId, contactUserId } }),

    getMutualContacts: (userId1, userId2) =>
        apiClient.get('/contacts/mutual', { params: { userId1, userId2 } }),

    // ==================== 好友申请相关API ====================

    // 获取待处理的好友申请（收到的）
    getPendingRequests: (userId) =>
        apiClient.get(`/contacts/requests/pending/${userId}`),

    // 获取已发送的好友申请
    getSentRequests: (userId) =>
        apiClient.get(`/contacts/requests/sent/${userId}`),

    // 获取待处理申请数量
    getPendingRequestCount: (userId) =>
        apiClient.get(`/contacts/requests/count/${userId}`),

    // 接受好友申请
    acceptRequest: (requestId, userId) =>
        apiClient.post(`/contacts/requests/${requestId}/accept`, null, { params: { userId } }),

    // 拒绝好友申请
    rejectRequest: (requestId, userId) =>
        apiClient.post(`/contacts/requests/${requestId}/reject`, null, { params: { userId } })
}

// Group API
export const groupAPI = {
    // 获取群组信息
    getGroupById: (groupId) =>
        apiClient.get(`/groups/${groupId}`),

    // 获取群组成员列表（包含角色信息）
    getGroupMembers: (groupId) =>
        apiClient.get(`/groups/${groupId}/members`),

    // 退出群聊
    leaveGroup: (groupId, userId) =>
        apiClient.post(`/groups/${groupId}/leave`, null, { params: { userId } }),

    // 移除成员（管理员权限）
    removeMember: (groupId, memberId, userId) =>
        apiClient.delete(`/groups/${groupId}/members/${memberId}`, { params: { userId } }),

    // 添加成员
    addMembers: (groupId, userId, memberIds) =>
        apiClient.post(`/groups/${groupId}/members`, { userIds: memberIds }, { params: { userId } }),

    // 设置/取消管理员（群主权限）
    setAdmin: (groupId, memberId, userId, isAdmin) =>
        apiClient.put(`/groups/${groupId}/members/${memberId}/admin`, null, { params: { userId, isAdmin } }),

    // 转让群主
    transferOwnership: (groupId, userId, newOwnerId) =>
        apiClient.post(`/groups/${groupId}/transfer`, null, { params: { userId, newOwnerId } }),

    // 解散群聊（群主权限）
    deleteGroup: (groupId, userId) =>
        apiClient.delete(`/groups/${groupId}`, { params: { userId } }),

    // 更新群组信息
    updateGroup: (groupId, userId, data) =>
        apiClient.put(`/groups/${groupId}`, data, { params: { userId } })
}

// Sync API (delta synchronization)
export const syncAPI = {
    getDelta: (since, types = 'messages,chats,contacts') =>
        apiClient.get('/sync/delta', { params: { since, types } })
}

// File API
export const fileAPI = {
    uploadFile: (file, uploaderId = null, onProgress = null) => {
        const formData = new FormData()
        formData.append('file', file)
        if (uploaderId) formData.append('uploaderId', uploaderId)
        return apiClient.post('/files/upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
            onUploadProgress: onProgress ? (e) => {
                const percent = Math.round((e.loaded * 100) / e.total)
                onProgress(percent)
            } : undefined
        })
    },

    uploadChunk: (chunk, chunkIndex, totalChunks, fileId, filename, totalSize, uploaderId = null) => {
        const formData = new FormData()
        formData.append('file', chunk)
        formData.append('chunkIndex', chunkIndex)
        formData.append('totalChunks', totalChunks)
        formData.append('fileId', fileId)
        if (filename) formData.append('filename', filename)
        if (totalSize) formData.append('totalSize', totalSize)
        if (uploaderId) formData.append('uploaderId', uploaderId)
        return apiClient.post('/files/upload/chunk', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        })
    },

    getFileInfo: (fileId) => apiClient.get(`/files/${fileId}/info`),

    getDownloadUrl: (fileId) => `${API_BASE_URL}/files/download/${fileId}`,

    getPreviewUrl: (fileId) => `${API_BASE_URL}/files/preview/${fileId}`
}

export default apiClient
