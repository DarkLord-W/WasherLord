// lib/screens/config_screen.dart
import 'package:flutter/material.dart';
import 'package:washer/storage.dart';
import 'package:washer/washer.dart';
import 'package:washer/washer_service.dart';

class ConfigScreen extends StatefulWidget {
  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final Set<String> _selectedWashers = Set<String>();
  Map<String, dynamic>? _selectedMode;
  List<Washer> _allWashers = [];
  bool _isLoading = true;
  bool _autoPayEnabled = false;

  final List<Map<String, dynamic>> _washModes = [
    {
      "code": "QUICK_WASH",
      "name": "快洗",
      "description": "轻污衣物快速洗涤",
      "washTotalTime": 23,
      "price": "¥ 3.5"
    },
    {
      "code": "GENERAL",
      "name": "常规",
      "description": "一般衣物均可洗涤",
      "washTotalTime": 40,
      "price": "¥ 3.7"
    },
    {
      "code": "LONG_WASH",
      "name": "超长洗",
      "description": "加长洗涤时间，可洗床单、被罩等",
      "washTotalTime": 45,
      "price": "¥ 4.2"
    },
    {
      "code": "DEHY",
      "name": "脱水",
      "description": "脱水",
      "washTotalTime": 6,
      "price": "¥ 1"
    }
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadWashers();
    _loadAutoPayState();
  }

  Future<void> _loadAutoPayState() async {
    final autoPay = await ConfigStorage.getAutoPay();
    setState(() => _autoPayEnabled = autoPay);
  }

  Future<void> _loadSettings() async {
    final blacklist = await ConfigStorage.getBlacklist();
    final mode = await ConfigStorage.getWashMode();
    setState(() {
      _selectedWashers.addAll(blacklist);
      _selectedMode = mode ?? _washModes.first;
    });
  }

  Future<void> _loadWashers() async {
    try {
      final washers = await WasherService.fetchWashers();
      setState(() {
        _allWashers = washers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    ConfigStorage.saveBlacklist(_selectedWashers);
    // ConfigStorage.saveAutoPay(_autoPayEnabled);
    await ConfigStorage.saveAutoPay(_autoPayEnabled); // 同步存储
    if (_selectedMode != null) {
      ConfigStorage.saveWashMode(_selectedMode!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('配置已保存')),
    );
  }

  void _showWasherSelection() async {
    final Set<String> tempSelection = Set.from(_selectedWashers);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('选择要排除的洗衣机',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  itemCount: _allWashers.length,
                  itemBuilder: (context, index) {
                    final washer = _allWashers[index];
                    return CheckboxListTile(
                      title: Text(washer.number),
                      subtitle: Text('洗衣机号: ${washer.washId}'),
                      value: tempSelection.contains(washer.washId),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelection.add(washer.washId);
                          } else {
                            tempSelection.remove(washer.washId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _selectedWashers.clear());
                    _selectedWashers.addAll(tempSelection);
                    Navigator.pop(context);
                  },
                  child: Text('确认选择', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('配置中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('排除洗衣机配置',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    InkWell(
                      onTap: _showWasherSelection,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_drop_down, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(_selectedWashers.isEmpty
                                ? '点击选择要排除的洗衣机'
                                : '已选择 ${_selectedWashers.length} 台洗衣机'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (_selectedWashers.isNotEmpty) ...[
                      Text('已排除的洗衣机:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _allWashers
                            .where((w) => _selectedWashers.contains(w.washId))
                            .map((washer) => Chip(
                          label: Text(washer.number),
                          deleteIcon: Icon(Icons.close, size: 18),
                          onDeleted: () => setState(
                                  () => _selectedWashers.remove(washer.washId)),
                        ))
                            .toList(),
                      ),
                    ],
                  ],
                )),
          ),
          SizedBox(height: 24),
          Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('洗衣模式配置',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ..._washModes.map((mode) => RadioListTile<Map<String, dynamic>>(
                      title: Text('${mode["name"]} (${mode["washTotalTime"]}分钟)'),
                      subtitle: Text('${mode["description"]}\n价格: ${mode["price"]}元'),
                      value: mode,
                      groupValue: _selectedMode,
                      onChanged: (value) => setState(() => _selectedMode = value),
                    )),
                  ],
                )),
          ),
          SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('支付配置',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    title: Text('自动支付'),
                    subtitle: Text('开启后检测到可用设备将自动完成支付'),
                    value: _autoPayEnabled,
                    onChanged: (value) => setState(() => _autoPayEnabled = value),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveSettings,
            child: Text('保存配置', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              try {
                final exportPath = await UserStorage.exportConfig();
                if (exportPath != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('导出成功！'),
                          Text(
                            '路径: $exportPath',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[300]
                            ),
                          ),
                        ],
                      ),
                      duration: Duration(seconds: 5),
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导出已取消')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导出失败: ${e.toString()}')),
                  );
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_alt, size: 20),
                SizedBox(width: 8),
                Text('导出配置文件'),
              ],
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前配置概览',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('已排除洗衣机数量: ${_selectedWashers.length}'),
                  Text('当前洗衣模式: ${_selectedMode?["name"] ?? "未选择"}'),
                  if (_selectedWashers.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text('排除的洗衣机列表:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    ..._allWashers
                        .where((w) => _selectedWashers.contains(w.washId))
                        .map((washer) => Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                          '${washer.number} (洗衣机号: ${washer.washId})'),
                    ))
                        .toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
