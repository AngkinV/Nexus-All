import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/theme_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../data/models/post/post_models.dart';
import '../../../data/repositories/post_repository.dart';

/// 帖子详情页
class PostDetailPage extends StatefulWidget {
  final PostModel post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostRepository _postRepository = PostRepository();
  final SecureStorageService _secureStorage = SecureStorageService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late PostModel _post;
  final List<PostCommentModel> _comments = [];
  int _commentPage = 0;
  bool _commentHasMore = true;
  bool _isLoadingComments = false;
  bool _isSendingComment = false;
  int? _currentUserId;
  int? _replyToCommentId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final userId = await _secureStorage.getUserId();
    setState(() => _currentUserId = userId);
    _loadComments();
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoadingComments) return;
    if (refresh) {
      _commentPage = 0;
      _commentHasMore = true;
    }
    if (!_commentHasMore && !refresh) return;

    setState(() => _isLoadingComments = true);

    try {
      final response = await _postRepository.getPostComments(
        _post.id,
        page: _commentPage,
      );
      setState(() {
        if (refresh) _comments.clear();
        _comments.addAll(response.content);
        _commentPage++;
        _commentHasMore = !response.last;
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _handleVote(int voteType) async {
    if (_currentUserId == null) return;
    try {
      PostModel updated;
      if (voteType == 1) {
        updated = await _postRepository.upvotePost(_post.id, _currentUserId!);
      } else {
        updated = await _postRepository.downvotePost(_post.id, _currentUserId!);
      }
      setState(() => _post = updated);
    } catch (_) {}
  }

  Future<void> _handleBookmark() async {
    if (_currentUserId == null) return;
    try {
      final updated = await _postRepository.toggleBookmark(_post.id, _currentUserId!);
      setState(() => _post = updated);
    } catch (_) {}
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _currentUserId == null || _isSendingComment) return;

    setState(() => _isSendingComment = true);

    try {
      final comment = await _postRepository.createComment(
        postId: _post.id,
        authorId: _currentUserId!,
        content: text,
        parentId: _replyToCommentId,
      );
      setState(() {
        _comments.insert(0, comment);
        _post = _post.copyWith(commentCount: _post.commentCount + 1);
        _commentController.clear();
        _replyToCommentId = null;
        _replyToName = null;
        _isSendingComment = false;
      });
      _commentFocusNode.unfocus();
    } catch (e) {
      setState(() => _isSendingComment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发送失败')),
        );
      }
    }
  }

  void _startReply(PostCommentModel comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToName = comment.displayName;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF7F5F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // AppBar
          _buildAppBar(isDark),
          // Content
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 200 &&
                    _commentHasMore &&
                    !_isLoadingComments) {
                  _loadComments();
                }
                return false;
              },
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  _buildArticle(isDark),
                  _buildCommentHeader(isDark),
                  ..._comments.map((c) => _buildCommentItem(c, isDark)),
                  if (_isLoadingComments)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    ),
                  if (!_isLoadingComments && !_commentHasMore && _comments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
                      child: Center(
                        child: Text(
                          '已显示全部评论',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  if (!_isLoadingComments && _comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48,
                                color: isDark ? Colors.grey[700] : Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('暂无评论，来发表第一条吧',
                                style: TextStyle(fontSize: 14,
                                    color: isDark ? Colors.grey[600] : Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // 评论输入框
          _buildCommentInput(isDark),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    final bgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.95)
        : const Color(0xFFF7F5F0).withValues(alpha: 0.95);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20,
                    color: isDark ? Colors.white : const Color(0xFF1F2937)),
                onPressed: () => Navigator.pop(context, _post),
              ),
              const Spacer(),
              Text(
                '详情',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.more_horiz, size: 22,
                    color: isDark ? Colors.white : const Color(0xFF1F2937)),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 文章主体
  Widget _buildArticle(bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final inkColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final mutedColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final fullAvatarUrl = _post.authorAvatarUrl != null
        ? ApiConfig.getFullUrl(_post.authorAvatarUrl)
        : '';

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者行
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: fullAvatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: fullAvatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildGradientAvatar(_post.displayName),
                          errorWidget: (_, __, ___) => _buildGradientAvatar(_post.displayName),
                        )
                      : _buildGradientAvatar(_post.displayName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_post.displayName,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: inkColor)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(_formatTime(_post.createdAt),
                            style: TextStyle(fontSize: 12, color: mutedColor)),
                        Container(
                          width: 3, height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: mutedColor.withValues(alpha: 0.5)),
                        ),
                        Text('社区频道', style: TextStyle(fontSize: 12, color: mutedColor)),
                      ],
                    ),
                  ],
                ),
              ),
              // 关注按钮
              if (_post.authorId != _currentUserId)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: Text('关注',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.primary)),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // 标题
          if (_post.title != null && _post.title!.isNotEmpty) ...[
            Text(
              _post.title!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 正文
          Text(
            _post.content,
            style: TextStyle(
              fontSize: 16,
              height: 1.8,
              color: inkColor.withValues(alpha: 0.9),
            ),
          ),

          // 图片
          if (_post.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._post.images.map((url) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 200,
                    color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF3F4F6),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF3F4F6),
                    child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  ),
                ),
              ),
            )),
          ],

          const SizedBox(height: 16),

          // 底部操作栏
          Row(
            children: [
              Text('${_formatViewCount(_post.viewCount)} 阅读',
                  style: TextStyle(fontSize: 13, color: mutedColor)),
              const Spacer(),
              // 点赞
              GestureDetector(
                onTap: () => _handleVote(1),
                child: Row(
                  children: [
                    Icon(
                      _post.userVote == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 20,
                      color: _post.userVote == 1 ? AppTheme.primary : mutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatCount(_post.upvoteCount),
                      style: TextStyle(
                        fontSize: 13,
                        color: _post.userVote == 1 ? AppTheme.primary : mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // 收藏
              GestureDetector(
                onTap: _handleBookmark,
                child: Row(
                  children: [
                    Icon(
                      _post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: _post.isBookmarked ? AppTheme.primary : mutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _post.isBookmarked ? '已收藏' : '收藏',
                      style: TextStyle(
                        fontSize: 13,
                        color: _post.isBookmarked ? AppTheme.primary : mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 评论区标题
  Widget _buildCommentHeader(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF7F5F0);
    final inkColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          Text(
            '评论 (${_post.commentCount})',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: inkColor),
          ),
        ],
      ),
    );
  }

  /// 评论项
  Widget _buildCommentItem(PostCommentModel comment, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final inkColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final mutedColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6);

    final fullAvatarUrl = comment.authorAvatarUrl != null
        ? ApiConfig.getFullUrl(comment.authorAvatarUrl)
        : '';

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: fullAvatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: fullAvatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildGradientAvatar(comment.displayName),
                          errorWidget: (_, __, ___) => _buildGradientAvatar(comment.displayName),
                        )
                      : _buildGradientAvatar(comment.displayName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名字 + 时间
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(comment.displayName,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
                        Text(_formatTime(comment.createdAt),
                            style: TextStyle(fontSize: 11, color: mutedColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 评论内容
                    Text(
                      comment.content,
                      style: TextStyle(fontSize: 14, height: 1.6, color: inkColor.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 10),
                    // 操作栏
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _startReply(comment),
                          child: Row(
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 16, color: mutedColor),
                              const SizedBox(width: 4),
                              Text('回复', style: TextStyle(fontSize: 12, color: mutedColor)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Icon(Icons.favorite_border, size: 16, color: mutedColor),
                        const SizedBox(width: 4),
                        Text(_formatCount(comment.likeCount),
                            style: TextStyle(fontSize: 12, color: mutedColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }

  /// 底部评论输入框
  Widget _buildCommentInput(bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final inputBg = isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF7F5F0);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 回复提示
              if (_replyToName != null)
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        '回复 $_replyToName',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(Icons.close, size: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              // 输入框
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  decoration: InputDecoration(
                    hintText: _replyToName != null ? '回复 $_replyToName...' : '写下你的想法...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 工具栏
              Row(
                children: [
                  _buildInputTool(Icons.image_outlined, isDark),
                  const SizedBox(width: 12),
                  _buildInputTool(Icons.emoji_emotions_outlined, isDark),
                  const SizedBox(width: 12),
                  _buildInputTool(Icons.alternate_email, isDark),
                  const Spacer(),
                  // 发送按钮
                  GestureDetector(
                    onTap: _sendComment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '发送',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.send, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputTool(IconData icon, bool isDark) {
    final mutedColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return GestureDetector(
      child: Icon(icon, size: 22, color: mutedColor),
    );
  }

  Widget _buildGradientAvatar(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.primary, Color(0xFF059669)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dateTime.month}月${dateTime.day}日';
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _formatViewCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
