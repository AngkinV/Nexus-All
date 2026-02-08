import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/theme_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../data/models/post/post_models.dart';
import '../../../data/repositories/post_repository.dart';
import 'create_post_page.dart';

/// 社区页面
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final PostRepository _postRepository = PostRepository();
  final SecureStorageService _secureStorage = SecureStorageService();

  // 三个标签的数据
  final List<PostModel> _recommendedPosts = [];
  final List<PostModel> _hotPosts = [];
  final List<PostModel> _latestPosts = [];

  // 分页状态
  int _recommendedPage = 0;
  int _hotPage = 0;
  int _latestPage = 0;
  bool _recommendedHasMore = true;
  bool _hotHasMore = true;
  bool _latestHasMore = true;

  // 加载状态
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int? _currentUserId;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final userId = await _secureStorage.getUserId();
    setState(() {
      _currentUserId = userId;
    });
    _loadPostsForCurrentTab();
  }

  Future<void> _loadPostsForCurrentTab() async {
    switch (_currentTabIndex) {
      case 0:
        if (_recommendedPosts.isEmpty) _loadRecommendedPosts();
        break;
      case 1:
        if (_hotPosts.isEmpty) _loadHotPosts();
        break;
      case 2:
        if (_latestPosts.isEmpty) _loadLatestPosts();
        break;
    }
  }

  Future<void> _loadRecommendedPosts({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _recommendedPage = 0;
      _recommendedHasMore = true;
    }
    if (!_recommendedHasMore && !refresh) return;

    setState(() => _isLoading = refresh || _recommendedPosts.isEmpty);

    try {
      final response = await _postRepository.getRecommendedPosts(
        page: _recommendedPage,
        userId: _currentUserId,
      );
      setState(() {
        if (refresh) _recommendedPosts.clear();
        _recommendedPosts.addAll(response.content);
        _recommendedPage++;
        _recommendedHasMore = !response.last;
        _isLoading = false;
      });
      // 预加载新帖子的图片
      _precachePostImages(response.content);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载失败');
    }
  }

  Future<void> _loadHotPosts({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _hotPage = 0;
      _hotHasMore = true;
    }
    if (!_hotHasMore && !refresh) return;

    setState(() => _isLoading = refresh || _hotPosts.isEmpty);

    try {
      final response = await _postRepository.getHotPosts(
        page: _hotPage,
        userId: _currentUserId,
      );
      setState(() {
        if (refresh) _hotPosts.clear();
        _hotPosts.addAll(response.content);
        _hotPage++;
        _hotHasMore = !response.last;
        _isLoading = false;
      });
      // 预加载新帖子的图片
      _precachePostImages(response.content);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载失败');
    }
  }

  Future<void> _loadLatestPosts({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _latestPage = 0;
      _latestHasMore = true;
    }
    if (!_latestHasMore && !refresh) return;

    setState(() => _isLoading = refresh || _latestPosts.isEmpty);

    try {
      final response = await _postRepository.getLatestPosts(
        page: _latestPage,
        userId: _currentUserId,
      );
      setState(() {
        if (refresh) _latestPosts.clear();
        _latestPosts.addAll(response.content);
        _latestPage++;
        _latestHasMore = !response.last;
        _isLoading = false;
      });
      // 预加载新帖子的图片
      _precachePostImages(response.content);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载失败');
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      switch (_currentTabIndex) {
        case 0:
          await _loadRecommendedPosts();
          break;
        case 1:
          await _loadHotPosts();
          break;
        case 2:
          await _loadLatestPosts();
          break;
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    switch (_currentTabIndex) {
      case 0:
        await _loadRecommendedPosts(refresh: true);
        break;
      case 1:
        await _loadHotPosts(refresh: true);
        break;
      case 2:
        await _loadLatestPosts(refresh: true);
        break;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// 预加载帖子图片
  /// 当帖子加载完成后，预加载前几个帖子的图片到缓存中
  void _precachePostImages(List<PostModel> posts, {int count = 5}) {
    final postsToPreload = posts.take(count);
    for (final post in postsToPreload) {
      for (final imageUrl in post.images) {
        if (imageUrl.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(imageUrl),
            context,
          ).catchError((_) {
            // 预加载失败时静默处理
          });
        }
      }
    }
  }

  Future<void> _handleVote(PostModel post, int voteType) async {
    if (_currentUserId == null) {
      _showError('请先登录');
      return;
    }

    try {
      PostModel updatedPost;
      if (voteType == 1) {
        updatedPost = await _postRepository.upvotePost(post.id, _currentUserId!);
      } else {
        updatedPost = await _postRepository.downvotePost(post.id, _currentUserId!);
      }
      _updatePostInLists(updatedPost);
    } catch (e) {
      _showError('操作失败');
    }
  }

  Future<void> _handleBookmark(PostModel post) async {
    if (_currentUserId == null) {
      _showError('请先登录');
      return;
    }

    try {
      final updatedPost = await _postRepository.toggleBookmark(post.id, _currentUserId!);
      _updatePostInLists(updatedPost);
    } catch (e) {
      _showError('操作失败');
    }
  }

  void _updatePostInLists(PostModel updatedPost) {
    setState(() {
      _updatePostInList(_recommendedPosts, updatedPost);
      _updatePostInList(_hotPosts, updatedPost);
      _updatePostInList(_latestPosts, updatedPost);
    });
  }

  void _updatePostInList(List<PostModel> posts, PostModel updatedPost) {
    final index = posts.indexWhere((p) => p.id == updatedPost.id);
    if (index != -1) {
      posts[index] = updatedPost;
    }
  }

  void _navigateToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
    if (result == true) {
      _refresh();
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentTabIndex = index;
    });
    _loadPostsForCurrentTab();
  }

  List<PostModel> get _currentPosts {
    switch (_currentTabIndex) {
      case 0:
        return _recommendedPosts;
      case 1:
        return _hotPosts;
      case 2:
        return _latestPosts;
      default:
        return _recommendedPosts;
    }
  }

  bool get _currentHasMore {
    switch (_currentTabIndex) {
      case 0:
        return _recommendedHasMore;
      case 1:
        return _hotHasMore;
      case 2:
        return _latestHasMore;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, isDark),
              Expanded(
                child: _buildPostList(_currentPosts, _currentHasMore, isDark),
              ),
            ],
          ),
          // 悬浮发帖按钮
          Positioned(
            right: 16,
            bottom: 100,
            child: _buildCreatePostButton(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '社区',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: 搜索
                        },
                        icon: Icon(
                          Icons.search,
                          size: 28,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                // 标签导航
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: _buildTabBar(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final tabs = ['推荐', '热门', '最新'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[100]?.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentTabIndex == index;
          return GestureDetector(
            onTap: () => _onTabChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.grey[500] : Colors.grey[500]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPostList(List<PostModel> posts, bool hasMore, bool isDark) {
    if (_isLoading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无帖子',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _refresh,
              child: const Text('点击刷新'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primary,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200 &&
              hasMore &&
              !_isLoadingMore) {
            _loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: posts.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == posts.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildPostCard(posts[index], isDark);
          },
        ),
      ),
    );
  }

  Widget _buildPostCard(PostModel post, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[50]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者信息
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 头像
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        ),
                      ),
                      child: ClipOval(
                        child: post.authorAvatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: post.authorAvatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => _buildDefaultAvatar(post.displayName),
                                errorWidget: (context, url, error) => _buildDefaultAvatar(post.displayName),
                              )
                            : _buildDefaultAvatar(post.displayName),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${_formatTime(post.createdAt)} · 社区频道',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // TODO: 更多操作
                      },
                      child: Icon(
                        Icons.more_horiz,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  ],
                ),

                // 标题
                if (post.title != null && post.title!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    post.title!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                    ),
                  ),
                ],

                // 内容
                const SizedBox(height: 12),
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    children: [
                      TextSpan(text: post.content),
                      TextSpan(
                        text: ' 阅读更多',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 图片
          if (post.images.isNotEmpty) _buildImages(post.images, isDark),

          // 操作栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[50]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // 投票按钮组
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        // 点赞
                        GestureDetector(
                          onTap: () => _handleVote(post, 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  size: 20,
                                  color: post.userVote == 1
                                      ? AppTheme.primary
                                      : Colors.grey[400],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatCount(post.upvoteCount),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: post.userVote == 1
                                        ? AppTheme.primary
                                        : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 分隔线
                        Container(
                          width: 1,
                          height: 16,
                          color: isDark ? Colors.grey[700] : Colors.grey[200],
                        ),
                        // 踩
                        GestureDetector(
                          onTap: () => _handleVote(post, -1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Icon(
                              Icons.arrow_downward,
                              size: 20,
                              color: post.userVote == -1
                                  ? Colors.red
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 评论
                  GestureDetector(
                    onTap: () {
                      // TODO: 打开评论
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatCount(post.commentCount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 分享
                  GestureDetector(
                    onTap: () {
                      // TODO: 分享
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.share_outlined,
                        size: 22,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),

                  // 收藏
                  GestureDetector(
                    onTap: () => _handleBookmark(post),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 22,
                        color: post.isBookmarked ? Colors.orange : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      color: AppTheme.primary,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildImages(List<String> images, bool isDark) {
    if (images.isEmpty) return const SizedBox.shrink();

    // 单图
    if (images.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: images[0],
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '图片加载失败',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 多图 - 横向滚动
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Container(
            width: 240,
            margin: EdgeInsets.only(right: index < images.length - 1 ? 12 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  child: Icon(
                    Icons.image_not_supported,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreatePostButton(bool isDark) {
    return GestureDetector(
      onTap: _navigateToCreatePost,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.edit,
              size: 24,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            const Text(
              '发帖',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${dateTime.month}月${dateTime.day}日';
    }
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
