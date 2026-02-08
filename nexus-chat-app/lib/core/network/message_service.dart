import 'dart:async';
import 'package:flutter/foundation.dart';

/// 消息服务 - 单例模式
/// 用于管理实时消息更新的通知
class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  // 消息更新通知控制器
  final _messageUpdateController = StreamController<int>.broadcast();
  final _chatUpdateController = StreamController<int>.broadcast();

  /// 消息更新流 - 传递 chatId
  Stream<int> get messageUpdateStream => _messageUpdateController.stream;

  /// 聊天列表更新流 - 传递 chatId（0 表示刷新全部）
  Stream<int> get chatUpdateStream => _chatUpdateController.stream;

  /// 通知有新消息
  void notifyNewMessage(int chatId) {
    debugPrint('📨 MessageService: 通知新消息 chatId=$chatId');
    _messageUpdateController.add(chatId);
    _chatUpdateController.add(chatId);
  }

  /// 通知聊天列表需要刷新
  void notifyChatsUpdate() {
    debugPrint('📨 MessageService: 通知聊天列表更新');
    _chatUpdateController.add(0);
  }

  /// 释放资源
  void dispose() {
    _messageUpdateController.close();
    _chatUpdateController.close();
  }
}
