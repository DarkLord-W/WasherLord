// lib/utils/storage.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washer/user.dart';


class UserStorage {
  static const _keyUserData = 'user_data'; // 改为单一键存储完整数据

  // 导出配置方法 - 修正版本
  static Future<String?> exportConfig() async {
    try {
      // 1. 获取配置数据
      final prefs = await SharedPreferences.getInstance();
      final config = {
        'user': prefs.getString(_keyUserData) ?? '',
        'blacklist': prefs.getStringList(ConfigStorage._keyBlacklist) ?? [],
        'washMode': prefs.getString(ConfigStorage._keyWashMode) ?? 'default',
      };

      // 2. 构造 JSON 数据
      final configJson = jsonEncode(config);
      final configBytes = utf8.encode(configJson); // 转换为二进制字节

      // 3. 生成默认文件名
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '_');
      final defaultFileName = 'washer_config_$timestamp.json';

      // 4. 通过 FilePicker 弹出文件对话框
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出配置文件',
        fileName: defaultFileName, // 设置默认文件名
        allowedExtensions: ['json'], // 限定后缀
        type: FileType.custom,
        bytes: configBytes, // 必须传入配置的字节数据
      );

      if (result == null) {
        print('用户取消导出操作');
        return null;
      }

      return result; // 返回保存的文件路径
    } catch (e) {
      throw '导出失败: $e';
    }
  }


  static Future<bool> importConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: true,
        lockParentWindow: true,
        dialogTitle: '选择配置文件',
      );

      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;
      if (file.bytes == null) return false;

      final config = jsonDecode(utf8.decode(file.bytes!));
      final prefs = await SharedPreferences.getInstance();

      // 分步保存数据
      await prefs.setString(_keyUserData, config['user'] ?? '');
      await prefs.setStringList(
          ConfigStorage._keyBlacklist,
          (config['blacklist'] as List<dynamic>?)?.cast<String>() ?? []
      );
      await prefs.setString(
          ConfigStorage._keyWashMode,
          config['washMode'] ?? ''
      );

      return true;
    } on PlatformException catch (e) {
      print('平台错误: ${e.message}');
      return false;
    } on FormatException {
      print('文件格式错误');
      return false;
    } catch (e) {
      print('导入失败: $e');
      return false;
    }
  }

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, jsonEncode({
      'token': user.token,
      'userId': user.userId,
      'mobileMask': user.mobileMask,
      // 'expiresAt': DateTime.now().add(Duration(hours: 24)).toIso8601String(), // 添加有效期
      'expiresAt': DateTime(2100, 1, 1).toIso8601String(), // 设置到2100年
    }));
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyUserData);
    if (data == null) return null;

    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return User(
        token: map['token'],
        userId: map['userId'],
        mobileMask: map['mobileMask'],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserData);
  }
}

class ConfigStorage {
  static const _keyBlacklist = 'washid_blacklist'; // 修改键名
  static const _keyWashMode = 'selected_wash_mode';
  static const _keyAutoPay = 'auto_pay_enabled'; // 新增配置键

  // 保存黑名单
  // 修改保存方法
  static Future<void> saveBlacklist(Set<String> washIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBlacklist, washIds.toList());
  }

  // // 获取黑名单
  // 修改获取方法
  static Future<Set<String>> getBlacklist() async {
    final prefs = await SharedPreferences.getInstance();
    return Set.from(prefs.getStringList(_keyBlacklist) ?? []);
  }

  // 保存洗衣模式
  static Future<void> saveWashMode(Map<String, dynamic> mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWashMode, jsonEncode(mode));
  }
  // 获取洗衣模式
  static Future<Map<String, dynamic>?> getWashMode() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyWashMode);
    return data != null ? jsonDecode(data) : null;
  }


  // 新增自动支付配置方法
  static Future<void> saveAutoPay(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPay, enabled);
  }

  static Future<bool> getAutoPay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoPay) ?? false;
  }

}

