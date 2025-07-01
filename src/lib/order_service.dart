// lib/service/order_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:washer/storage.dart';
import 'package:washer/washer.dart';

class OrderService {
  static const String _baseUrl = 'https://WEBSITE_PEOPLE_KNOW';
  // static const String _baseUrl = 'http://10.0.2.2:5678'; //用来本地响应测试

  static Future<Map<String, dynamic>> _getHeaderAndToken() async {
    final user = await UserStorage.getCurrentUser();
    final headers = <String, String>{
      'Api-Version': '1.0.0',
      'From-Agent': 'SxkjPhone',
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Content-Type': 'application/json;charset=UTF-8',
      'Token': user?.token ?? '',
      'Eagleeye-Pappname': 'hy78v40gt0@7b1387d125865d8',
      'Cookie': '_bl_uid=Unmdj8eFi38qn0cU93k4up4agywj',
      'Referer': 'https://WEBSITE_PEOPLE_KNOW/',
      'Priority': 'u=1, i',
    };
    return {
      'headers': headers,
      'userId': user?.userId ?? 0,
    };
  }

  // 统一的 Referer 构造方法
  static String _buildRefererUrl({
    required String orderId,
    required String orderType,
    required String orderPattern
  }) {
    return Uri(
        scheme: 'http',
        host: 'WEBSITE_PEOPLE_KNOW',
        path: '/pages/orderPay/orderPay',
        queryParameters: {
          'orderId': orderId,
          'orderType': orderType,
          'orderPattern': orderPattern
        }
    ).toString();
  }

  static Future<String> createOrder({
    required Washer washer, // 改为直接传递整个对象
    required String washId,
    // required String bucketNumber, // 不再需要 bucketNumber 参数，从 washer 中获取
  }) async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    if (washer.bucketState != 0) {
      throw Exception('洗衣桶当前不可用（状态码: ${washer.bucketState}）');
    }

    final selectedMode = await ConfigStorage.getWashMode() ?? {"code": "DEHY"};

    print("[DEBUG] 洗衣桶号码：${washer.bucketNumber}");

    final body = {
      "washTypeCode": selectedMode["code"],
      "washId": washId,
      // "bucketNumber": bucketInfo['bucketNumber'],
      "bucketNumber": washer.bucketNumber, // 直接使用对象属性
      "channel": 100000,
    };

    if (washer.bucketNumber.isNotEmpty) {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/order/saveDorOrder'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("订单创建成功： ${response.body}");
        print("orderId： ${data['data']['orderId'].toString()}");
        // return data['data']['orderId'];
        // 添加 toString() 转换
        return data['data']['orderId'].toString();
      } else {
        throw Exception("订单创建失败: ${response.body}");
      }
    }
    else{
      throw Exception("订单创建失败: [ERROR] 洗衣桶不存在");
    }

  }


  // 支付信息获取方法
  static Future<Map<String, dynamic>> getPayOrderInfo(String orderId) async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    final response = await http.get(
      Uri.parse('$_baseUrl/api/order/loadPayOrderInfo?orderId=$orderId&type=1&pattern=1&time=${DateTime.now().millisecondsSinceEpoch}'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']; // 严格使用接口返回字段
    } else {
      throw Exception("获取支付信息失败: ${response.body}");
    }
  }


  // 获取支付所需参数
  static Future<Map<String, dynamic>> _getPayParams(String orderId) async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    // 使用统一方法构造 Referer
    headers['Referer'] = _buildRefererUrl(
        orderId: orderId,
        orderType: '1',
        orderPattern: '1'
    );

    final response = await http.get(
      Uri.parse('$_baseUrl/api/order/loadPayOrderInfo?orderId=$orderId&type=1&pattern=1&time=${DateTime.now().millisecondsSinceEpoch}'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'type': data['data']['type'],
        'pattern': data['data']['pattern'],
        'washOrderType': data['data']['washOrderType']
      };
    }
    throw Exception("获取支付参数失败: ${response.body}");
  }

  static Future<void> loadUserCoupons(int payChannel,orderId) async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    // 使用统一方法构造 Referer
    headers['Referer'] = _buildRefererUrl(
        orderId: orderId,
        orderType: '1',
        orderPattern: '1'
    );

    final response = await http.post(
      Uri.parse('$_baseUrl/api/user/loadUserCouponList'),
      headers: headers,
      body: jsonEncode({"payChannel": payChannel}),
    );

    if (response.statusCode != 200) {
      throw Exception("加载优惠券失败: ${response.body}");
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception("优惠券接口返回异常: ${data['msg']}");
    }
  }



  static Future<bool> payOrder(String orderId) async {
    try {

      // 获取支付参数
      final params1 = await _getPayParams(orderId);


      // 加载优惠券
      final params2 = await loadUserCoupons(100000, orderId); // payChannel固定为100000

      print('[DEBUG] 开始支付流程 | 订单号: $orderId | 时间: ${DateTime.now()}');

      final dynamicConfig = await _getHeaderAndToken();
      final headers = Map<String, String>.from(dynamicConfig['headers'] as Map);


      // 使用统一方法构造 Referer
      headers['Referer'] = _buildRefererUrl(
          orderId: orderId,
          orderType: '1',
          orderPattern: '1'
      );


      final body = {
        "orderId": orderId,
        "channel": 100000,
        "miniCode": null,
        "couponId": "",
      };


      print('[DEBUG] 支付请求体: $body');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/order/pay'),
        headers: headers,
        // body: body,
        // json: body,
        body: jsonEncode(body),  // 使用body参数 + jsonEncode
      ).timeout(const Duration(seconds: 15));

      print('[NETWORK] 支付响应状态: ${response.statusCode}');
      print('[NETWORK] 原始响应数据: ${response.body}');

      print('请求头内容: ${headers}'); // 应不包含Content-Type
      print('实际发送的Content-Type: ${response.request?.headers['Content-Type']}'); // 应为application/json


      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception("支付请求异常: HTTP ${response.statusCode}");
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      print('[DEBUG] 支付响应数据: ${responseData}');

      final isSuccess = responseData['success'] == true;
      final sign = responseData['data']?['sign'] as String?;


      return isSuccess && sign == 'synchronize_suc';

    } on http.ClientException catch (e) {
      throw Exception("网络连接失败: ${e.message}");
    } on TimeoutException {
      throw Exception("请求超时，请检查网络连接");
    } on FormatException {
      throw Exception("响应数据格式异常");
    } catch (e) {
      throw Exception("支付流程异常: ${e.toString()}");
    }
  }

  static Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    final response = await http.get(
      Uri.parse('$_baseUrl/api/order/loadUserOrderDetails?id=$orderId&model=0'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']; // 直接返回原始数据
    } else {
      throw Exception("获取订单详情失败: ${response.body}");
    }
  }

  static Future<bool> cancelOrder(String orderId, {required int reasonValue}) async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/order/refund?orderId=$orderId&reasonValue=$reasonValue'),
      headers: headers,
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    }
    return false;
  }


// 重构获取当前订单方法
  static Future<Map<String, dynamic>?> getCurrentOrder() async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/order/loadOngoingOrderList?homePage=2'),
      headers: headers,
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final orders = (data['data'] as List)
          .where((o) => [0, 11].contains(o['state'])) // 根据实际状态过滤
          .toList();

      if (orders.isNotEmpty) {
        final order = orders.first;
        final detail = await getOrderDetails(order['id'].toString());
        return {
          'id': order['id'],
          'state': order['state'],
          'expireRemianMinutes': detail['expireRemianMinutes'],
          'payAmount': detail['payAmount'],
          'washTypeName': detail['washingTypeName']
        };
      }
    }
    return null;
  }


  static Future<bool> startWasher(String orderId) async {
    final dynamicConfig = await _getHeaderAndToken();
    final headers = dynamicConfig['headers'] as Map<String, String>;

    try {
      // 使用 GET 方法，移除请求体
      final response = await http.get(
        Uri.parse('$_baseUrl/hxwash/start?orderId=$orderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 直接判断 status 字段
        if (data['status'] == 'OK'){
          print("洗衣机启动成功: $data['status']");
        }
        return data['status'] == 'OK';
      }
    } catch (e) {
      // 异常处理
      print("洗衣机启动失败: $e");
    }
    return false;
  }



}
