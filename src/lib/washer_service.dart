
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:washer/washer.dart';
import 'package:washer/storage.dart';
import 'order_service.dart';

class WasherService {
  static const String _baseUrl = 'https://WEBSITE_PEOPLE_KNOW';
  // static const String _baseUrl = 'http://10.0.2.2:5678'; //用来本地响应测试

  // 缓存桶信息
  static Map<String, dynamic>? _cachedBucketInfo;

  // 同步访问方法
  static Map<String, dynamic> fetchBucketInfoSync() {
    try {
      return _cachedBucketInfo ?? {'bucketNumber': '0', 'bucketState': 0};
    } catch (_) {
      return {'bucketNumber': '0', 'bucketState': 0};
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final user = await UserStorage.getCurrentUser();
    return {
      'Api-Version': '1.0.0',
      'From-Agent': 'SxkjPhone',
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Content-Type': 'application/json;charset=UTF-8',
      'Token': '${user?.token ?? ""}',
      'Eagleeye-Pappname': 'hy78v40gt0@7b1387d125865d8',
      'Cookie': '_bl_uid=Unmdj8eFi38qn0cU93k4up4agywj',
      'Referer': 'https://WEBSITE_PEOPLE_KNOW/',
      'Priority': 'u=1, i',
    };
  }

  static Future<List<Washer>> fetchWashers() async {
    try {
      // // 预加载桶信息
      // await fetchBucketInfo();

      final currentOrder = await OrderService.getCurrentOrder();
      if (currentOrder != null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/home/washModelAndBucketInfo?storeType=2'),
        headers: await _getHeaders(),
      );

      print('[Network] 请求状态码: ${response.statusCode}');
      print('[Network] 响应原始数据: ${response.body}');

      if (response.statusCode == 200) {
        final String decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = jsonDecode(decodedBody);

        if (!data.containsKey('data')) {
          throw FormatException('缺少顶层data字段');
        }

        final responseData = data['data'] as Map<String, dynamic>;
        if (!responseData.containsKey('washList')) {
          throw FormatException('响应中缺少washList字段');
        }

        final washerData = responseData['washList'] as List;
        print('[DEBUG] 成功解析到 ${washerData.length} 台洗衣机数据');


        final buckets = (responseData['bucketList'] as List<dynamic>)
            // .where((b) => (b as Map<String, dynamic>)['isOwn'] == 1)
            .cast<Map<String, dynamic>>() // 关键类型转换
            .toList();


        // 检查是否有有效数据
        if (buckets.isEmpty) {
          throw Exception('未找到可用的洗衣桶');
        }

        // print('[DEBUG] 洗衣桶编号： ${responseData['bucketList']['number']}');
        // print('[DEBUG] 洗衣桶状态： ${responseData['bucketList']['bucketState']}');

        // // 打印原始数据结构
        // print('[DEBUG] 原始 bucketList 数据: ${responseData['bucketList']}');
        //
        // // 打印过滤后的 buckets 列表
        // print('[DEBUG] 过滤后的用户专属桶列表: $buckets');

        // 直接使用第一个桶的信息
        final bucket = buckets.first;
        print('[SUCCESS] 可用洗衣桶编号: ${bucket['number']}, 状态: ${bucket['bucketState']}');


        // // 遍历每个桶的详细信息
        // if (buckets.isNotEmpty) {
        //   buckets.forEach((bucket) {
        //     print('[DEBUG] 桶详情 - 编号: ${bucket['number']}, 状态: ${bucket['bucketState']}');
        //   });
        // } else {
        //   print('[WARNING] 未找到用户专属桶');
        // }


        return washerData.map((json) {
          try {
            return Washer.fromJson(json, buckets);
          } catch (e) {
            print('[解析错误] 无效数据项: ${json.toString()}');
            print('[详细错误] ${e.toString()}');
            throw FormatException('洗衣机数据解析失败: ${e.toString()}');
          }
        }).toList();

      } else if (response.statusCode == 401) {
        print('[认证错误] 401未授权，清除用户数据');
        await UserStorage.clearUser();
        throw Exception('登录状态已过期，请重新登录');
      } else if (response.statusCode == 403) {
        throw Exception('权限不足，无法访问该资源');
      } else if (response.statusCode == 404) {
        throw Exception('请求的资源不存在');
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        throw Exception('服务器内部错误 (${response.statusCode})');
      } else {
        throw Exception('请求失败，状态码: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      print('[网络连接错误] ${e.message}');
      throw Exception('网络连接异常: ${e.message}');
    } on FormatException catch (e) {
      print('[数据格式异常] ${e.message}');
      throw Exception('数据解析失败: ${e.message}');
    } on TypeError catch (e) {
      print('[类型转换错误] ${e.toString()}');
      throw Exception('数据类型转换异常: ${e.toString()}');
    } catch (e) {
      print('[未知异常] ${e.toString()}');
      throw Exception('系统异常: ${e.toString()}');
    }
  }

}
