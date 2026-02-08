import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/theme_config.dart';
import '../home/messages_page.dart';
import '../contacts/contacts_page.dart';
import '../community/community_page.dart';
import '../profile/profile_page.dart';

/// 主导航页面 - 包含底部导航栏的容器
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MessagesPage(),
    ContactsPage(),
    CommunityPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _buildBottomNav(context, isDark),
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNav(BuildContext context, bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95)
                : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(0, Icons.chat_bubble, Icons.chat_bubble_outline, '消息', isDark),
                  _buildNavItem(1, Icons.people, Icons.people_outline, '联系人', isDark),
                  _buildNavItem(2, Icons.public, Icons.public_outlined, '社区', isDark),
                  _buildNavItem(3, Icons.person, Icons.person_outline, '我', isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建导航项
  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon, String label, bool isDark) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentIndex = index;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected
                  ? AppTheme.primary
                  : (isDark ? Colors.grey[400] : Colors.grey[400]),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppTheme.primary
                    : (isDark ? Colors.grey[400] : Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
