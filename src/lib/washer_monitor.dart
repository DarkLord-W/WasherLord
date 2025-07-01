// lib/screens/washer_monitor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:washer/washer.dart';
import 'package:washer/washer_provider.dart';
import 'package:washer/login_screen.dart';
import 'package:washer/config_screen.dart';
import 'package:washer/order_service.dart';
import 'package:washer/order_detail_screen.dart';

class WasherMonitorScreen extends StatefulWidget {
  @override
  _WasherMonitorScreenState createState() => _WasherMonitorScreenState();
}

class _WasherMonitorScreenState extends State<WasherMonitorScreen> {
  bool _isMonitoring = false;
  late WasherProvider _provider;
  late Timer _timer;

  // 当前订单状态跟踪
  Map<String, dynamic>? _currentOrder;

  @override
  void initState() {
    super.initState();
    _provider = context.read<WasherProvider>();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadCurrentOrder();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentOrder() async {
    final order = await OrderService.getCurrentOrder();
    if (mounted) {
      setState(() => _currentOrder = order);
    }
  }


  Color _getStatusColor(int stateCode) {
    return switch (stateCode) {
      0 => Colors.blueGrey.shade200,
      1 => Colors.green.shade300,
      2 => Colors.red.shade300,
      3 => Colors.red.shade300,
      4 => Colors.red.shade300,
      5 => Colors.red.shade300,
      6 => Colors.blueGrey.shade300,
      7 => Colors.blueGrey.shade300,
      8 => Colors.red.shade300,
      _ => Colors.red.shade300,
    };
  }

  // 更新状态映射
  static const Map<int, String> _orderStateMap = {
    0: "待支付",
    5: "支付中",
    10: "待取",
    11: "待洗",
    100: "已取件",
    999: "启动中",
    1000: "洗衣中",
    1001: "洗衣中-漂洗",
    1002: "洗衣中-脱水",
    10000: "待送",
    100000: "配送中",
    100001: "待自提",
    1000000: "已完成",
    8870000: "取消中",
    8880000: "已取消",
    8880001: "精洗拒收",
    9000001: "已支付未分配洗衣机"
  };

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Consumer<WasherProvider>(
        builder: (context, provider, _) {
          if (provider.error != null) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.error!,
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isMonitoring ? null : () {
                    provider.startMonitoring(context);
                    setState(() => _isMonitoring = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('重试连接'),
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: _isMonitoring ? null : () {
                      provider.startMonitoring(context);
                      setState(() => _isMonitoring = true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text('开始监控'),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton(
                    onPressed: _isMonitoring ? () {
                      provider.stopMonitoring();
                      setState(() => _isMonitoring = false);
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text('停止监控'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('洗衣机状态监控'),
        actions: [

          // 添加手动刷新订单信息
          IconButton(
            icon: Icon(Icons.update),
            tooltip: '刷新订单状态',
            onPressed: () async {
              await _loadCurrentOrder();
              if (mounted) setState(() {});
            },
          ),


          // 优化订单按钮状态显示
          IconButton(
            icon: Stack(
              children: [

                Icon(
                  Icons.receipt_long,
                  // 动态颜色控制
                  color: _currentOrder != null
                      ? null  // 有订单时使用默认颜色
                      : Colors.grey.withOpacity(0.5), // 无订单时灰色半透明
                ),

                if (_currentOrder != null)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text('!',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  )
              ],
            ),

            onPressed: () async {  // 添加异步等待

              // 刷新逻辑
              await _loadCurrentOrder();
              if (mounted) setState(() {});

              if (_currentOrder != null) {
                bool refresh = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      orderId: _currentOrder!['id'].toString(),
                    ),
                  ),
                ) ?? false; // 这里接收返回值

                if (refresh) {
                  await _loadCurrentOrder();
                  // 触发洗衣机列表刷新
                  context.read<WasherProvider>().startMonitoring(context);
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text("我的订单")),
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('暂无进行中的订单',
                                style: TextStyle(fontSize: 16, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            },

          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isMonitoring
                ? () => _provider.startMonitoring(context)
                : null,
            color: _isMonitoring ? null : Colors.grey,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ConfigScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentOrder != null) _buildOrderBanner(),
          Expanded(
            child: Consumer<WasherProvider>(
              builder: (context, provider, _) {
                if (provider.error?.contains('登录已过期') ?? false) {
                  provider.clearError();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  });
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildContent(provider);
              },
            ),
          ),
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildContent(WasherProvider provider) {
    if (provider.isLoading) {
      return _buildLoading();
    } else if (provider.error != null) {
      return _buildError(provider.error!);
    } else {
      return _buildWasherGrid(provider.washers);
    }
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 50, color: Colors.red),
          const SizedBox(height: 16),
          Text(error),
          ElevatedButton(
            onPressed: () => _provider.startMonitoring(context),
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }

  // 优化订单横幅显示逻辑
  Widget _buildOrderBanner() {
    // final status = _currentOrder!['orderStatus'] == 0 ? '待支付' : '已支付';
    final status = _orderStateMap[_currentOrder!['state']] ?? "未知状态";

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: status == '待支付' ? Colors.amber.shade100 : Colors.green.shade100,
      child: Row(
        children: [
          Icon(
            status == '待支付' ? Icons.access_time : Icons.check_circle,
            color: status == '待支付' ? Colors.orange : Colors.green,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('进行中订单 ($status)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (status == '待支付')
                  Text('剩余操作时间: ${_currentOrder!['expireRemianMinutes']}分钟',
                      style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            child: Text('${status == '待支付' ? '立即处理' : '查看详情'} >'),
            // onPressed: () => Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (_) => OrderDetailScreen(
            //       orderId: _currentOrder!['id'].toString(),
            //     ),
            //   ),
            // ),

            onPressed: () async {
              // 增加异步等待和刷新逻辑
              final refresh = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(
                    orderId: _currentOrder!['id'].toString(),
                  ),
                ),
              ) ?? false;

              if (refresh && mounted) {
                await _loadCurrentOrder();
                // 触发洗衣机列表刷新
                context.read<WasherProvider>().startMonitoring(context);
              }
            },

          ),
        ],
      ),
    );
  }

  Widget _buildWasherGrid(List<Washer> washers) {
    if (_currentOrder != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('您有进行中的订单，暂不可操作设备',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(
                    orderId: _currentOrder!['id'].toString(),
                  ),
                ),
              ) ,
              child: Text('查看订单详情'),
            ),
          ],
        ),
      );
    }

    // 无订单时的空白状态显示
    if (washers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无可用洗衣机',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: washers.length,
      itemBuilder: (context, index) {
        final washer = washers[index];
        final remaining = washer.remainingTime;
        return GestureDetector(
          onTap: () => _showDetail(washer),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _getStatusColor(washer.stateCode),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          washer.number,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('状态：${washer.stateName}'),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(remaining),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (remaining.isNegative) ...[
                    const Align(
                      alignment: Alignment.center,
                      child: Text(
                        '已超时',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetail(Washer washer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(washer.number),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('详细状态'),
            Text('原始状态名称：${washer.stateName}'),
            Text('状态码原文：${washer.stateCode}'),
            Text('剩余时间：${_formatDuration(washer.remainingTime)}'),
            Text('故障代码：${washer.bucketState}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
