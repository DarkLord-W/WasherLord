
import 'package:flutter/material.dart';
import 'package:washer/order_service.dart';
import 'package:washer/storage.dart';
import 'package:washer/washer_monitor.dart';
import 'dart:async'; // 新增定时器库

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final bool isFromOrderCreation; // 参数区分来源

  // const OrderDetailScreen({required this.orderId});

  const OrderDetailScreen({
    required this.orderId,
    this.isFromOrderCreation = false // 默认非订单创建入口
  });

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map<String, dynamic>> _orderDetails;
  bool _isCanceling = false;
  bool _autoPayEnabled = false;
  bool _isPaid = false; // 支付状态标记
  int _orderState = 0; // 必须显式声明
  late DateTime _expiredDate; // 过期时间存储
  late Timer _timer; // 定时器
  String _remainingTime = '加载中...'; // 倒计时状态

  final List<Map<String, dynamic>> _cancelReasons = [
    {"text": "不想洗了", "value": 1},
    {"text": "机器不干净", "value": 2},
    {"text": "付款后未启动", "value": 3},
    {"text": "机器被占用", "value": 4},
    {"text": "未启动显示完成", "value": 5},
    {"text": "选错机器", "value": 7},
    {"text": "选错洗衣模式", "value": 8},
    {"text": "拿错洗衣桶", "value": 9},
    {"text": "其他", "value": 6},
  ];

  // 严格使用HTTP响应中的state值
  static const Map<int, String> _stateMap = {
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




  @override
  void initState() {
    super.initState();

    setState(() {});

    // _loadAutoPayState();

    // 第一步：先加载自动支付状态
    _loadAutoPayState().then((_) {
      // 第二步：根据完整状态选择数据源
      if (widget.isFromOrderCreation && !_autoPayEnabled) {
        _orderDetails = OrderService.getPayOrderInfo(widget.orderId);
      } else {
        _orderDetails = OrderService.getOrderDetails(widget.orderId);
      }

      // 第三步：强制刷新组件
      if (mounted) setState(() {});
    });

    _loadOrderState();
    _startTimer(); // 新增定时器启动
  }

  // 定时器逻辑
  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) { // 每秒更新
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // 必须停止定时器
    super.dispose();
  }

  // // 状态加载方法
  Future<void> _loadOrderState() async {
    if(!widget.isFromOrderCreation) { // 仅从监控列表进入时加载状态
      final currentOrder = await OrderService.getCurrentOrder();
      if (mounted) setState(() {
        _orderState = currentOrder?['state'] ?? 0;
      });
    }
  }


  // 自动支付加载方法
  Future<void> _loadAutoPayState() async {
    final autoPay = await ConfigStorage.getAutoPay();
    if (mounted) {
      setState(() => _autoPayEnabled = autoPay);
    }
  }


  // 使用订单创建时间（gmtCreate）加8分钟来计算剩余时间
  String _calculateRemainingTime(String gmtCreate) {
    try {
      final createTime = DateTime.parse(gmtCreate).toLocal();
      final expireTime = createTime.add(Duration(minutes: 8)); // 设置为下单后8分钟订单过期
      final now = DateTime.now().toLocal();
      final difference = expireTime.difference(now);

      if (difference.isNegative) return "已过期";

      final minutes = difference.inMinutes;
      final seconds = difference.inSeconds.remainder(60);
      return '${minutes}分${seconds.toString().padLeft(2, '0')}秒';
    } catch (e) {
      return '计算错误';
    }
  }


  Future<void> _cancelOrder() async {
    int? selectedReason = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("选择取消原因"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cancelReasons.length,
            itemBuilder: (context, index) {
              final reason = _cancelReasons[index];
              return ListTile(
                title: Text(reason['text']),
                onTap: () => Navigator.pop(context, reason['value']),
              );
            },
          ),
        ),
      ),
    );
    if (selectedReason == null) return;

    setState(() => _isCanceling = true);
    try {
      final success = await OrderService.cancelOrder(
        widget.orderId,
        reasonValue: selectedReason,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('订单已取消')),
        );

        // 强制退出当前页面
        if (mounted) {
          Navigator.of(context).pop(true); // 确保弹出当前页面
        }

      }
    } finally {
      setState(() => _isCanceling = false);
    }
  }

  // 支付处理方法
  Future<void> _handlePayment() async {
    try {
      // final response = await OrderService.payOrder(widget.orderId);
      final bool paymentResult = await OrderService.payOrder(widget.orderId);
      // if (response['success'] == true && response['sign'] == "synchronize_suc") {
      // if (response== true) {
      if (paymentResult) { // 直接判断布尔值
        setState(() {
          _isPaid = true; // 更新支付状态
          _orderDetails = OrderService.getOrderDetails(widget.orderId); // 刷新订单数据
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('支付成功')),
        );


        // Navigator.of(context).pop(true); // 返回并携带刷新标志

        // // 支付成功也触发刷新
        // _exitWithRefresh(needRefresh: true);
        // 强制退出当前页面
        if (mounted) {
          Navigator.of(context).pop(true);
        }

      } else { // 处理支付返回false的情况
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('支付未完成，请检查订单状态')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支付失败: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }


  // 统一退出方法
  void _exitWithRefresh({bool needRefresh = false}) {
    Navigator.pop(context, needRefresh);
  }



  // 添加一键启动洗衣机处理方法
  Future<void> _handleStartWasher() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认启动'),
        content: Text('请确认洗衣桶已放入洗衣机内'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await OrderService.startWasher(widget.orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '洗衣机启动成功' : '启动失败')),
      );

      if (success) {
        setState(() {
          _orderDetails = OrderService.getOrderDetails(widget.orderId);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请求失败: ${e.toString()}')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('订单详情')),
      body: FutureBuilder(
        future: _orderDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final data = snapshot.data!;

          // 过期时间

          final gmtCreate = widget.isFromOrderCreation && !_autoPayEnabled
              ? data['gmtCreate']?.toString() ?? ''
              : data['hxUserOrder']?['gmtCreate']?.toString() ?? '';

          _remainingTime = _calculateRemainingTime(gmtCreate);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                if (widget.isFromOrderCreation && !_autoPayEnabled) ...[
                  // A状态且未设置自动下单
                  _buildDetailItem('订单编号', widget.orderId),
                  _buildDetailItem('洗衣模式', data['washTypeName']?.toString() ?? '未知模式'),
                  _buildDetailItem('支付金额', '¥${(data['price']?.toStringAsFixed(2)) ?? "0.00"}'),
                  _buildDetailItem('洗衣桶号', data['bucketNum']?.toString() ?? '未知桶号'),
                  _buildDetailItem('创建时间', data['gmtCreate']?.toString() ?? '未知时间'),
                  SizedBox(height: 30),
                ] else ...[

                  // B状态字段组（带完整空安全）
                  _buildDetailItem('订单编号', widget.orderId),
                  _buildDetailItem('洗衣模式',
                      data['userOrderWaterDTO']?['washingTypeName'] ?? '未知模式'),
                  _buildDetailItem('支付金额',
                      '¥${data['hxUserOrder']?['amount'] ?? "0.00"}'),
                  _buildDetailItem('创建时间',
                      data['hxUserOrder']?['gmtCreate'] ?? '未知时间'),
                  _buildDetailItem('最晚投放时间',
                      data['hxUserOrder']?['expiredDate'] ?? '未设置'),
                  _buildDetailItem('剩余有效期', _remainingTime),
                  SizedBox(height: 30),
                ],


                // 修改后的按钮区域
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          // 第一行：取消订单 + 立即支付
                          LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  height: 55,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // A状态逻辑：来自订单创建
                                      if (widget.isFromOrderCreation &&
                                          !_autoPayEnabled &&
                                          !_isPaid) ...[
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _handlePayment,
                                            child: Text('立即支付'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size.fromHeight(48),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                      ],

                                      // B状态逻辑：来自监控列表
                                      if (!widget.isFromOrderCreation &&
                                          _orderState == 0) ...[
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _handlePayment,
                                            child: Text('立即支付'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size.fromHeight(48),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                      ],


                                      // 控制取消按钮显示
                                      if (_shouldShowCancelButton) ...[
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _isCanceling ? null : _cancelOrder,
                                            child: _isCanceling
                                                ? CircularProgressIndicator()
                                                : Text('取消订单'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size.fromHeight(48),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                      ],
                                    ],
                                  ),
                                );
                              }
                          ),

                          // 统一间距
                          SizedBox(height: 80),

                          // 第二行：一键启动洗衣机
                          if (_orderState == 11)
                            LayoutBuilder(
                                builder: (context, constraints) {
                                  return SizedBox(
                                    width: constraints.maxWidth,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: _handleStartWasher,
                                      child: Text('一键启动洗衣机'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size.fromHeight(48),
                                      ),
                                    ),
                                  );
                                }
                            ),


                          // 统一间距
                          SizedBox(height: 80),

                          // 第三行：刷新订单状态
                          LayoutBuilder(
                              builder: (context, constraints) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 20),
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    height: 55,
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.refresh, size: 20),
                                      label: Text('刷新订单状态'),
                                      onPressed: () {
                                        setState(() {
                                          _orderDetails = widget.isFromOrderCreation
                                              ? OrderService.getPayOrderInfo(widget.orderId)
                                              : OrderService.getOrderDetails(widget.orderId);
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.lightBlue,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size.fromHeight(48),
                                      ),
                                    ),
                                  ),
                                );
                              }
                          ),



                        ],
                      ),

                    ],
                  ),
                )


              ],
            ),
          );
        },
      ),
    );
  }

  bool get _shouldShowCancelButton {
    // A状态：从订单创建进入
    if (widget.isFromOrderCreation) {
      return true; // 保持原有逻辑
    }
    // B状态：从监控列表进入
    return _orderState == 0 || _orderState == 11; // 严格匹配HTTP响应中的state值
  }

  Widget _buildDetailItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 100,
            child: Text(
              '$label：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              '$value',
              style: TextStyle(color: _getValueColor(label)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getValueColor(String label) {
    switch(label) {
      case '剩余有效期': return Colors.blue;
      case '洗衣模式': return Colors.green;
      case '支付金额': return Colors.orange;
      default: return Colors.black;
    }
  }
}

