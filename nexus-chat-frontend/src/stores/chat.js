import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { chatAPI } from '@/services/api'
import offlineStore from '@/services/offlineStore'

export const useChatStore = defineStore('chat', () => {
    const activeChat = ref(null)
    const chats = ref([])
    const isLoading = ref(false)
    const subscribedChatIds = ref(new Set()) // Track subscribed chat rooms

    const messages = ref([])

    // Muted and Pinned chats (persisted in localStorage)
    const mutedChats = ref(new Set(JSON.parse(localStorage.getItem('mutedChats') || '[]')))
    const pinnedChats = ref(new Set(JSON.parse(localStorage.getItem('pinnedChats') || '[]')))

    // Save muted chats to localStorage
    const saveMutedChats = () => {
        localStorage.setItem('mutedChats', JSON.stringify([...mutedChats.value]))
    }

    // Save pinned chats to localStorage
    const savePinnedChats = () => {
        localStorage.setItem('pinnedChats', JSON.stringify([...pinnedChats.value]))
    }

    // Toggle mute for a chat
    const toggleMuteChat = (chatId) => {
        if (mutedChats.value.has(chatId)) {
            mutedChats.value.delete(chatId)
        } else {
            mutedChats.value.add(chatId)
        }
        saveMutedChats()
        return mutedChats.value.has(chatId)
    }

    // Check if chat is muted
    const isChatMuted = (chatId) => {
        return mutedChats.value.has(chatId)
    }

    // Toggle pin for a chat
    const togglePinChat = (chatId) => {
        if (pinnedChats.value.has(chatId)) {
            pinnedChats.value.delete(chatId)
        } else {
            pinnedChats.value.add(chatId)
        }
        savePinnedChats()
        return pinnedChats.value.has(chatId)
    }

    // Check if chat is pinned
    const isChatPinned = (chatId) => {
        return pinnedChats.value.has(chatId)
    }

    // Computed: Get all group chats
    const groupChats = computed(() => {
        return chats.value.filter(chat => chat.type === 'GROUP')
    })

    // Computed: Get all direct chats
    const directChats = computed(() => {
        return chats.value.filter(chat => chat.type === 'DIRECT')
    })

    // Computed: Total unread count
    const totalUnreadCount = computed(() => {
        return chats.value.reduce((sum, chat) => sum + (chat.unreadCount || 0), 0)
    })

    // Computed: Selected chat ID (for convenience)
    const selectedChatId = computed(() => activeChat.value?.id || null)

    // Computed: Sorted chats (pinned first, then by last message time)
    const sortedChats = computed(() => {
        return [...chats.value].sort((a, b) => {
            const aPinned = pinnedChats.value.has(a.id)
            const bPinned = pinnedChats.value.has(b.id)

            // Pinned chats come first
            if (aPinned && !bPinned) return -1
            if (!aPinned && bPinned) return 1

            // Same pinned status, sort by last message time
            return new Date(b.lastMessageTime || 0) - new Date(a.lastMessageTime || 0)
        })
    })

    // Update chat properties
    const updateChat = (chatId, updates) => {
        const chatIndex = chats.value.findIndex(c => c.id === chatId)
        if (chatIndex !== -1) {
            chats.value[chatIndex] = {
                ...chats.value[chatIndex],
                ...updates
            }
            // Update activeChat if it's the same chat
            if (activeChat.value?.id === chatId) {
                activeChat.value = { ...chats.value[chatIndex] }
            }
        }
    }

    // Increment unread count for a chat
    const incrementUnreadCount = (chatId) => {
        const chatIndex = chats.value.findIndex(c => c.id === chatId)
        if (chatIndex !== -1) {
            chats.value[chatIndex].unreadCount = (chats.value[chatIndex].unreadCount || 0) + 1
        }
    }

    // Mark chat as subscribed
    const markChatSubscribed = (chatId) => {
        subscribedChatIds.value.add(chatId)
    }

    // Check if chat is subscribed
    const isChatSubscribed = (chatId) => {
        return subscribedChatIds.value.has(chatId)
    }

    // Fetch chats from backend
    const fetchChats = async (userId) => {
        isLoading.value = true
        try {
            const response = await chatAPI.getUserChats(userId)
            const chatList = response.data || []

            // Transform backend data to frontend format
            chats.value = chatList.map(chat => {
                const isOnline = chat.members?.find(m => m.id !== userId)?.isOnline || false
                return {
                    id: chat.id,
                    name: chat.name,
                    avatar: chat.members?.find(m => m.id !== userId)?.avatarUrl || '',
                    lastMessage: chat.lastMessage?.content || '',
                    lastMessageTime: chat.lastMessage?.createdAt || chat.lastMessageAt,
                    unreadCount: chat.unreadCount || 0,
                    online: isOnline,
                    status: isOnline ? 'online' : 'offline',
                    type: chat.type === 'direct' ? 'DIRECT' : 'GROUP',
                    members: chat.members,
                    memberCount: chat.members?.length || 0,
                    contactId: chat.type === 'direct' ? chat.members?.find(m => m.id !== userId)?.id : null
                }
            })

            // Persist to IndexedDB
            offlineStore.saveChats(chats.value).catch(() => {})
        } catch (error) {
            console.error('Failed to fetch chats:', error)
        } finally {
            isLoading.value = false
        }
    }

    const setActiveChat = (chat) => {
        activeChat.value = chat
        // Mark as read when opening chat
        if (chat) {
            const chatIndex = chats.value.findIndex(c => c.id === chat.id)
            if (chatIndex !== -1) {
                chats.value[chatIndex].unreadCount = 0
            }
        }
    }

    // Toggle chat: if same chat is clicked, close it; otherwise open the new chat
    const toggleActiveChat = (chat) => {
        if (activeChat.value?.id === chat.id) {
            // Same chat clicked, close it
            activeChat.value = null
        } else {
            // Different chat or no chat open, set as active and clear unread
            setActiveChat(chat)
        }
    }

    const sendMessage = (messageData) => {
        const newMessage = {
            id: Date.now(),
            chatId: messageData.chatId,
            senderName: 'Me',
            content: messageData.content,
            timestamp: new Date(),
            type: messageData.type,
            isSelf: true,
            read: false
        }
        messages.value.push(newMessage)

        // Update last message in chat list
        const chatIndex = chats.value.findIndex(c => c.id === messageData.chatId)
        if (chatIndex !== -1) {
            chats.value[chatIndex].lastMessage = messageData.type === 'TEXT' ? messageData.content : '[Image]'
            chats.value[chatIndex].lastMessageTime = new Date()
        }
    }

    const createGroup = async (groupData) => {
        try {
            // In real app, call API
            // const response = await chatAPI.createGroupChat(userId, groupData.name, groupData.memberIds)

            const newGroup = {
                id: Date.now(),
                name: groupData.name,
                description: groupData.description || '',
                avatar: groupData.avatar || '',
                lastMessage: 'Group created',
                lastMessageTime: new Date(),
                unreadCount: 0,
                online: true,
                type: 'GROUP',
                isPrivate: groupData.isPrivate || false,
                members: groupData.members || [],
                memberCount: (groupData.members?.length || 0) + 1
            }

            chats.value.unshift(newGroup)
            return newGroup
        } catch (error) {
            console.error('Failed to create group:', error)
            throw error
        }
    }

    const createDirectChat = async (userId, contact) => {
        // Check if chat already exists
        const existingChat = chats.value.find(
            c => c.type === 'DIRECT' && c.contactId === contact.id
        )

        if (existingChat) {
            setActiveChat(existingChat)
            return existingChat
        }

        try {
            // Call backend API to create direct chat
            const response = await chatAPI.createDirectChat(userId, contact.id)
            const chatData = response.data

            const newChat = {
                id: chatData.id,
                contactId: contact.id,
                name: contact.nickname,
                avatar: contact.avatar || contact.avatarUrl || '',
                lastMessage: chatData.lastMessage?.content || '',
                lastMessageTime: chatData.lastMessageAt || new Date(),
                unreadCount: 0,
                online: contact.isOnline || false,
                status: contact.isOnline ? 'online' : 'offline',
                type: 'DIRECT',
                members: chatData.members
            }

            chats.value.unshift(newChat)
            setActiveChat(newChat)
            return newChat
        } catch (error) {
            console.error('Failed to create direct chat:', error)
            throw error
        }
    }

    const updateGroupInfo = (groupId, updates) => {
        const chatIndex = chats.value.findIndex(c => c.id === groupId)
        if (chatIndex !== -1) {
            chats.value[chatIndex] = {
                ...chats.value[chatIndex],
                ...updates
            }
            // Update activeChat if it's the same
            if (activeChat.value?.id === groupId) {
                activeChat.value = chats.value[chatIndex]
            }
        }
    }

    const leaveGroup = (groupId) => {
        const chatIndex = chats.value.findIndex(c => c.id === groupId)
        if (chatIndex !== -1) {
            chats.value.splice(chatIndex, 1)
            if (activeChat.value?.id === groupId) {
                activeChat.value = null
            }
        }
    }

    const deleteChat = async (chatId, userId) => {
        // Call API to delete chat on server
        await chatAPI.deleteChat(chatId, userId)

        // Remove from local chat list
        const chatIndex = chats.value.findIndex(c => c.id === chatId)
        if (chatIndex !== -1) {
            chats.value.splice(chatIndex, 1)
        }

        // Clear activeChat if it's the deleted one
        if (activeChat.value?.id === chatId) {
            activeChat.value = null
        }

        // Clear pinned and muted status
        pinnedChats.value.delete(chatId)
        mutedChats.value.delete(chatId)
        savePinnedChats()
        saveMutedChats()

        // Remove from subscribed list
        subscribedChatIds.value.delete(chatId)
    }

    // Handle chat disabled (contact removed)
    const handleChatDisabled = (chatId) => {
        // Remove from chat list
        const chatIndex = chats.value.findIndex(c => c.id === chatId)
        if (chatIndex !== -1) {
            chats.value.splice(chatIndex, 1)
        }

        // Clear active chat if it's the disabled one
        if (activeChat.value?.id === chatId) {
            activeChat.value = null
        }

        // Remove from subscribed list
        subscribedChatIds.value.delete(chatId)
    }

    const getMessagesForChat = (chatId) => {
        return messages.value.filter(m => m.chatId === chatId)
    }

    // 更新聊天中成员的在线状态（用于WebSocket实时同步）
    const updateMemberOnlineStatus = (userId, isOnline) => {
        // 更新 chats 列表中的状态
        chats.value.forEach(chat => {
            if (chat.type === 'DIRECT' && chat.contactId === userId) {
                chat.online = isOnline
                chat.status = isOnline ? 'online' : 'offline'
            }
            // 更新群聊成员状态
            if (chat.members) {
                const member = chat.members.find(m => m.id === userId)
                if (member) {
                    member.isOnline = isOnline
                }
            }
        })

        // 如果 activeChat 是受影响的聊天，重新赋值以确保响应式更新
        if (activeChat.value && activeChat.value.type === 'DIRECT' && activeChat.value.contactId === userId) {
            const updatedChat = chats.value.find(c => c.id === activeChat.value.id)
            if (updatedChat) {
                activeChat.value = { ...updatedChat }
            }
        }
    }

    // Add member to group
    const addGroupMember = (groupId, member) => {
        const chatIndex = chats.value.findIndex(c => c.id === groupId)
        if (chatIndex !== -1) {
            if (!chats.value[chatIndex].members) {
                chats.value[chatIndex].members = []
            }
            // Check if member already exists
            const exists = chats.value[chatIndex].members.some(m => m.id === member.id)
            if (!exists) {
                chats.value[chatIndex].members.push(member)
                chats.value[chatIndex].memberCount = (chats.value[chatIndex].memberCount || 0) + 1
            }
            // Update activeChat if same
            if (activeChat.value?.id === groupId) {
                activeChat.value = { ...chats.value[chatIndex] }
            }
        }
    }

    // Remove member from group
    const removeGroupMember = (groupId, memberId) => {
        const chatIndex = chats.value.findIndex(c => c.id === groupId)
        if (chatIndex !== -1 && chats.value[chatIndex].members) {
            const memberIndex = chats.value[chatIndex].members.findIndex(m => m.id === memberId)
            if (memberIndex !== -1) {
                chats.value[chatIndex].members.splice(memberIndex, 1)
                chats.value[chatIndex].memberCount = Math.max((chats.value[chatIndex].memberCount || 1) - 1, 0)
            }
            // Update activeChat if same
            if (activeChat.value?.id === groupId) {
                activeChat.value = { ...chats.value[chatIndex] }
            }
        }
    }

    // Remove chat (alias for deleteChat, used by WebSocket)
    const removeChat = (chatId) => {
        deleteChat(chatId)
    }

    // Update group member role
    const updateGroupMemberRole = (groupId, memberId, role, isAdmin) => {
        const chatIndex = chats.value.findIndex(c => c.id === groupId)
        if (chatIndex !== -1 && chats.value[chatIndex].members) {
            const member = chats.value[chatIndex].members.find(m => m.id === memberId)
            if (member) {
                member.role = role
                member.isAdmin = isAdmin
            }
            // Update activeChat if same
            if (activeChat.value?.id === groupId) {
                activeChat.value = { ...chats.value[chatIndex] }
            }
        }
    }

    // Transfer group ownership
    const transferGroupOwnership = (groupId, oldOwnerId, newOwnerId) => {
        const chatIndex = chats.value.findIndex(c => c.id === groupId)
        if (chatIndex !== -1 && chats.value[chatIndex].members) {
            // Update old owner to admin
            const oldOwner = chats.value[chatIndex].members.find(m => m.id === oldOwnerId)
            if (oldOwner) {
                oldOwner.role = 'admin'
                oldOwner.isAdmin = true
            }
            // Update new owner
            const newOwner = chats.value[chatIndex].members.find(m => m.id === newOwnerId)
            if (newOwner) {
                newOwner.role = 'owner'
                newOwner.isAdmin = true
            }
            // Update activeChat if same
            if (activeChat.value?.id === groupId) {
                activeChat.value = { ...chats.value[chatIndex] }
            }
        }
    }

    /**
     * Merge delta-synced chats into the store.
     * Updates existing chats or inserts new ones.
     */
    const mergeChats = (deltaChatList) => {
        for (const deltaChat of deltaChatList) {
            const idx = chats.value.findIndex(c => c.id === deltaChat.id)
            if (idx !== -1) {
                chats.value[idx] = { ...chats.value[idx], ...deltaChat }
            } else {
                chats.value.push(deltaChat)
            }
        }
        // Persist merged chats to IndexedDB
        offlineStore.saveChats(deltaChatList).catch(() => {})
    }

    /**
     * Load chats from IndexedDB cache (offline-first).
     */
    const loadFromCache = async () => {
        try {
            const cached = await offlineStore.getChats()
            if (cached.length > 0) {
                chats.value = cached
            }
            return cached
        } catch (e) {
            console.error('[ChatStore] Failed to load from cache:', e)
            return []
        }
    }

    // Reset store - clear all data (used on logout)
    const resetStore = () => {
        activeChat.value = null
        chats.value = []
        messages.value = []
        subscribedChatIds.value = new Set()
    }

    // Clear subscribed chats tracking (used on reconnect)
    const clearSubscribedChats = () => {
        subscribedChatIds.value = new Set()
    }

    return {
        activeChat,
        chats,
        messages,
        isLoading,
        subscribedChatIds,
        mutedChats,
        pinnedChats,
        groupChats,
        directChats,
        totalUnreadCount,
        selectedChatId,
        sortedChats,
        fetchChats,
        setActiveChat,
        toggleActiveChat,
        sendMessage,
        createGroup,
        createDirectChat,
        updateGroupInfo,
        leaveGroup,
        deleteChat,
        removeChat,
        handleChatDisabled,
        getMessagesForChat,
        updateChat,
        incrementUnreadCount,
        markChatSubscribed,
        isChatSubscribed,
        updateMemberOnlineStatus,
        addGroupMember,
        removeGroupMember,
        updateGroupMemberRole,
        transferGroupOwnership,
        toggleMuteChat,
        isChatMuted,
        togglePinChat,
        isChatPinned,
        clearSubscribedChats,
        mergeChats,
        loadFromCache,
        resetStore
    }
})
