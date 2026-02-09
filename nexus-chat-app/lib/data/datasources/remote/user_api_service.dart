import '../../../core/network/dio_client.dart';

/// 用户统计数据模型
class UserStatsModel {
  final int followingCount;
  final int followerCount;
  final int postCount;

  UserStatsModel({
    required this.followingCount,
    required this.followerCount,
    required this.postCount,
  });

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      followingCount: json['followingCount'] ?? 0,
      followerCount: json['followerCount'] ?? 0,
      postCount: json['postCount'] ?? 0,
    );
  }
}

/// 用户 API 服务
class UserApiService {
  final DioClient _dioClient = DioClient();

  /// 获取用户统计数据（关注数、粉丝数、动态数）
  Future<UserStatsModel> getUserStats(int userId) async {
    final response = await _dioClient.get('/api/users/$userId/stats');
    return UserStatsModel.fromJson(response.data);
  }

  /// 关注用户
  Future<void> followUser(int targetUserId, int currentUserId) async {
    await _dioClient.post(
      '/api/users/$targetUserId/follow',
      queryParameters: {'followerId': currentUserId},
    );
  }

  /// 取消关注
  Future<void> unfollowUser(int targetUserId, int currentUserId) async {
    await _dioClient.delete(
      '/api/users/$targetUserId/follow',
      queryParameters: {'followerId': currentUserId},
    );
  }

  /// 查询关注状态
  Future<bool> isFollowing(int targetUserId, int currentUserId) async {
    final response = await _dioClient.get(
      '/api/users/$targetUserId/follow/status',
      queryParameters: {'followerId': currentUserId},
    );
    return response.data['isFollowing'] == true;
  }
}
