import 'dart:async';
import 'package:flutter/material.dart';
import 'package:washer/washer.dart';
import 'package:washer/washer_service.dart';
import 'package:washer/order_service.dart';
import 'package:washer/storage.dart';
import 'order_detail_screen.dart';

class WasherProvider with ChangeNotifier {
  List<Washer> _washers = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _pollingSubscription;
  Set<String> _processingBuckets = {};
  Set<String> _blacklist = {};
  BuildContext? _context;
  bool _hasActiveOrder = false;

  List<Washer> get washers => _washers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadBlacklist() async {
    _blacklist = await ConfigStorage.getBlacklist();
  }

  Future<void> startMonitoring(BuildContext context) async {
    if (_hasActiveOrder) return;

    _context = context;
    if (_isLoading) return;

    await _loadBlacklist();
    _isLoading = true;
    notifyListeners();

    try {
      await _fetchWashers();
      _error = null;
      _setupPolling();
    } catch (e) {
      _error = e.toString();
      _pollingSubscription?.cancel();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _shouldProcessOrder(Washer washer) {
    final isBlacklisted = _blacklist.contains(washer.washId);
    return !isBlacklisted &&
        washer.stateCode == 1 &&
        !_processingBuckets.contains(washer.bucketNumber) &&
        int.tryParse(washer.washId) != null &&
        !_hasActiveOrder && washer.remainingTime.inSeconds <= 30; // 提前30秒触发抢单
  }

  void stopMonitoring() {
    _pollingSubscription?.cancel();
    _pollingSubscription = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setupPolling() {
    _pollingSubscription?.cancel();
    _pollingSubscription = Stream.periodic(
      _calculateInterval(),
          (_) => _fetchWashers(),
    ).listen(
          (value) {},
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Duration _calculateInterval() {
    if (_hasActiveOrder) return Duration(seconds: 60);

    final activeWashers = _washers
        .where((w) => w.remainingTime.inSeconds > 0)
        .toList();

    if (activeWashers.isEmpty) return Duration(seconds: 10);

    final nearestExpiry = activeWashers
        .map((w) => w.calculatedExpiryTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final secondsToExpiry = nearestExpiry.difference(DateTime.now()).inSeconds;

    // return switch (secondsToExpiry) {
    //   > 300 => Duration(seconds: 30),
    //   > 180 => Duration(seconds: 15),
    //   > 60 => Duration(seconds: 5),
    //   > 30 => Duration(seconds: 1),
    //   > 0 => Duration(seconds: 1),
    //   _ => Duration(seconds: 10),
    // };

    // 强化秒级监控
    return switch (secondsToExpiry) {
      > 300 => Duration(seconds: 15),
      > 180 => Duration(seconds: 5),
      > 60 => Duration(seconds: 2),
      > 0 => Duration(milliseconds: 500),  // 半秒轮询
      _ => Duration(seconds: 10),
    };

  }

  void forceRefresh(BuildContext context) {
    _hasActiveOrder = false;
    startMonitoring(context);
  }

  Future<void> _fetchWashers() async {
    try {
      final currentOrder = await OrderService.getCurrentOrder();
      if (currentOrder != null) {
        _hasActiveOrder = true;
        _washers = [];
        notifyListeners();
        return;
      }
      _hasActiveOrder = false;

      final newWashers = await WasherService.fetchWashers();
      _washers = newWashers;
      notifyListeners();

      _checkAndCreateOrder(newWashers);

      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  void _checkAndCreateOrder(List<Washer> newWashers) {
    if (_context == null || _hasActiveOrder) return;

    for (final washer in newWashers) {
      if (_shouldProcessOrder(washer)) {
        _processingBuckets.add(washer.bucketNumber);
        _createAndPayOrder(washer, _context!);
      }
    }
  }


  void _createAndPayOrder(Washer washer, BuildContext context) async {
    String? successOrderId;
    try {
      final orderId = await OrderService.createOrder(
        washer: washer,
        washId: washer.washId,
      );

      final autoPay = await ConfigStorage.getAutoPay();

      bool paymentSuccess = false;
      if (autoPay) {
        paymentSuccess = await OrderService.payOrder(orderId);
        if (!paymentSuccess) throw Exception('支付失败');
      }


      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(autoPay ? '下单成功' : '订单已创建'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, // 对齐设置
              children: [
                Text('设备：${washer.number}'),
                Text('订单号：$orderId'),
                Text('支付状态：${paymentSuccess ? '已支付' : '待支付'}'),
                // if (!autoPay) Text('剩余操作时间：20秒'),
                if (!autoPay) Text('请尽快支付！！！'),
              ],
            ),
            actions: [ // 按钮布局部分
              Center( // 居中容器
                child: ButtonBar(
                  alignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(

                      onPressed: () async {
                        Navigator.pop(ctx);
                        // 增加返回结果处理
                        final refresh = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(
                              orderId: orderId,
                              isFromOrderCreation: true, // 标记为下单状态入口
                            ),
                          ),
                        ) ?? false;

                        if (refresh) {
                          await _fetchWashers();
                          _hasActiveOrder = false;
                          notifyListeners();
                        }
                      },

                      child: Text('查看详情'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      });


      successOrderId = orderId;
      _hasActiveOrder = true;

    } catch (e) {
      print('自动下单失败: ${e.toString()}');
      _processingBuckets.remove(washer.bucketNumber);
    } finally {
      if (successOrderId == null) {
        _processingBuckets.remove(washer.bucketNumber);
      }
    }
  }

  @override
  void dispose() {
    _pollingSubscription?.cancel();
    super.dispose();
  }
}
