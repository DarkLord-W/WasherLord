// lib/service/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:washer/user.dart';


class AuthService {
  static const String _baseUrl = 'https://WEBSITE_PEOPLE_KNOW';
  static const Map<String, String> _headers = {
    'Api-Version': '1.0.0',
    'From-Agent': 'SxkjPhone',
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Content-Type': 'application/json;charset=UTF-8',
    'Eagleeye-Pappname': 'hy78v40gt0@7b1387d125865d8',
    'Cookie': '_bl_uid=Unmdj8eFi38qn0cU93k4up4agywj',
    'Referer': 'https://WEBSITE_PEOPLE_KNOW/',
    'Priority': 'u=1, i',
  };

  static Future<bool> sendVerificationCode(String mobile) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/sendCode?mobile=$mobile'),
      headers: _headers,
      body: jsonEncode({}), // 保持空请求体
    );
    return response.statusCode == 200;
  }

  static Future<User?> login(String mobile, String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/login?mobile=$mobile&code=$code'),
      headers: _headers,
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        return User.fromJson(data['data']);
      }
    }
    return null;
  }
}
