

class Washer {
  final String washId;        // 新增字段：设备ID（关键下单参数）
  final String bucketNumber;  // 新增字段：桶编号（关键下单参数）
  final String number;
  final String status;          // 现在根据 stateCode 生成
  final String stateName;       // 保留显示名称
  final int stateCode;          // 核心判断字段
  final DateTime lastUpdate;
  final int remainingMinutes;   // 剩余分钟数（直接来自后端）
  final int bucketState;        // 篮筐状态码（原始字段）

  // // 新增计算属性
  // Duration get remainingTime => Duration(minutes: remainingMinutes);
  // DateTime get calculatedExpiryTime => lastUpdate.add(remainingTime);

  Washer({
    required this.number,
    required this.stateCode,
    required this.stateName,     // 不可空类型（必须赋值）
    required this.lastUpdate,
    required this.remainingMinutes,
    required this.bucketState,
    required this.washId,      // 新增构造参数
    required this.bucketNumber // 新增构造参数
  })

      : status = _generateStatus(stateCode: stateCode); // 仅使用 stateName

  // 基于 stateCode 生成状态
  static String _generateStatus({required int stateCode}) {
    return switch (stateCode) {
      0 => '维修中',   // 数据中 state=3 → "维修中"（如 9号机）
      1 => '可用',   // 数据中 state=3 → "已占用"（如 3号机）
      2 => '已占用',   // 数据中 state=3 → "已占用"（如 4号机）
      3 => '洗涤中',   // 数据中 state=3 → "洗涤中"（如 7号机、8号机）
      4 => '漂洗中',   // 数据中 state=4 → "漂洗中"（如 9号机、3号机）
      5 => '脱水中',   // 数据中 state=5 → "脱水中"（如 6号机，原错误映射为"维护"）
      6 => '离线',     // 保留原有定义 没找到对应状态
      7 => '维护',   // 保留原有定义 没找到对应状态
      8 => '断线',   // 数据中 state=8
      _ => '异常',    // 处理未出现的状态
    };
  }

  // 时间计算方法（增加秒级计算）
  Duration get remainingTime {
    final now = DateTime.now();
    final elapsed = now.difference(lastUpdate);
    final totalElapsedSeconds = elapsed.inSeconds;
    final remainingSeconds = (remainingMinutes * 60) - totalElapsedSeconds;

    return Duration(seconds: remainingSeconds > 0 ? remainingSeconds : 0);
  }
  // 精确时间戳方法
  DateTime get calculatedExpiryTime {
    return lastUpdate.add(Duration(minutes: remainingMinutes));
  }


  // JSON 解析（确保 stateName 非空）
  factory Washer.fromJson(Map<String, dynamic> json, List<Map<String, dynamic>> buckets) {
    try {
      final washId = json['washId']?.toString() ?? ''; // 确保转换为字符串


      // 桶匹配逻辑
      final availableBucket = buckets.firstWhere(
            (b) => b['bucketState'] == 0, // 直接检查桶状态
        orElse: () => {'number': '0000', 'bucketState': -1}, // 明确无效状态
      );


      final stateCode = json['state'] as int? ?? -1; // 核心状态字段
      final stateName = (json['stateName'] ?? '未知').toString(); // 确保非空（默认'未知'）
      final number = (json['washAllInfo'] ?? '未知编号').toString();
      final lastUpdate = DateTime.parse(
        json['gmtModified']?.toString() ?? DateTime.now().toIso8601String(),
      );
      final remainingMinutes = (json['remainTime'] as int?) ?? 0;
      // final bucketState = (json['faultState'] as int?) ?? 0;

      final bucketNumber = availableBucket['number']?.toString() ?? '0000';
      final bucketState = availableBucket['bucketState'] as int;

      return Washer(
        number: number,
        stateCode: stateCode,  // 使用原始状态码
        stateName: stateName,  // 保留显示名称
        lastUpdate: lastUpdate,
        remainingMinutes: remainingMinutes,
        bucketState: bucketState,
        washId: washId,         // 新增字段赋值
        bucketNumber: bucketNumber // 使用统一来源
      );
    }
    on Exception catch (e) {
      // 异常时设置为默认状态
      print('解析洗衣机数据失败: $e\n原始数据: $json');
      return Washer(
        number: '数据异常',
        stateCode: -1,
        stateName: '解析错误',
        lastUpdate: DateTime.now(),
        remainingMinutes: 0,
        bucketState: 0,
        washId: '0',
        bucketNumber: '0'
      );
    }
  }



}
