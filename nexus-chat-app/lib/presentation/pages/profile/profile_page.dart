import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/theme_config.dart';
import '../../../core/state/user_state_manager.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/auth/auth_models.dart';
import 'settings_page.dart';
import 'profile_edit_page.dart';

/// 个人中心页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthRepository _authRepository = AuthRepository();
  final UserStateManager _userStateManager = UserStateManager.instance;

  UserModel? _currentUser;
  bool _isLoading = true;
  StreamSubscription<UserModel?>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _setupUserListener();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  /// 监听用户状态变化
  void _setupUserListener() {
    _userSubscription = _userStateManager.userStream.listen((user) {
      if (mounted && user != null) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authRepository.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 用户信息头部
                  _buildUserHeader(isDark),

                  const SizedBox(height: 8),

                  // 服务入口
                  _buildMenuSection(
                    isDark: isDark,
                    items: [
                      _MenuItemData(
                        icon: Icons.account_balance_wallet,
                        iconColor: const Color(0xFF10B981),
                        title: '服务',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 功能菜单组
                  _buildMenuSection(
                    isDark: isDark,
                    items: [
                      _MenuItemData(
                        icon: Icons.bookmark,
                        iconColor: const Color(0xFFF97316),
                        title: '收藏',
                        onTap: () {},
                      ),
                      _MenuItemData(
                        icon: Icons.public,
                        iconColor: const Color(0xFF3B82F6),
                        title: '社区',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 设置入口
                  _buildMenuSection(
                    isDark: isDark,
                    items: [
                      _MenuItemData(
                        icon: Icons.settings,
                        iconColor: AppTheme.primary,
                        title: '设置',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // 底部留白
                  const SizedBox(height: 100),
                ],
              ),
      ),
    );
  }

  /// 构建用户信息头部
  Widget _buildUserHeader(bool isDark) {
    final user = _currentUser;
    final displayName = user?.displayName ?? '未登录';
    final fullAvatarUrl = ApiConfig.getFullUrl(user?.avatarUrl);
    final nexusId = user?.username ?? 'Nexus_${user?.id ?? '000000'}';

    return Container(
      color: isDark ? const Color(0xFF18181B) : Colors.white,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () async {
            // 跳转到个人资料编辑页
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileEditPage(user: _currentUser!),
              ),
            );
            // 如果返回了更新的用户数据，刷新页面
            if (result == true) {
              _loadCurrentUser();
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 16, 32),
            child: Row(
              children: [
                // 头像
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: fullAvatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: fullAvatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _buildDefaultAvatar(displayName, isDark),
                            errorWidget: (context, url, error) => _buildDefaultAvatar(displayName, isDark),
                          )
                        : _buildDefaultAvatar(displayName, isDark),
                  ),
                ),

                const SizedBox(width: 20),

                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF18181B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Nexus ID
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nexus号：$nexusId',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 二维码图标
                Icon(
                  Icons.qr_code_2,
                  size: 20,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),

                const SizedBox(width: 8),

                // 箭头
                Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建默认头像
  Widget _buildDefaultAvatar(String displayName, bool isDark) {
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      color: AppTheme.primary,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 构建菜单分组
  Widget _buildMenuSection({
    required bool isDark,
    required List<_MenuItemData> items,
  }) {
    return Container(
      color: isDark ? const Color(0xFF18181B) : Colors.white,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildMenuItem(items[i], isDark),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 56,
                endIndent: 0,
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
              ),
          ],
        ],
      ),
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem(_MenuItemData item, bool isDark) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 彩色图标容器
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 14),

            // 标题
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : const Color(0xFF18181B),
                ),
              ),
            ),

            // 箭头
            Icon(
              Icons.chevron_right,
              size: 22,
              color: isDark ? Colors.grey[600] : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}

/// 菜单项数据模型
class _MenuItemData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  _MenuItemData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });
}
