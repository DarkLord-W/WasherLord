// lib/screens/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:washer/storage.dart';
import 'package:washer/auth_service.dart';
import 'package:washer/user.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isCounting = false;
  int _countdown = 60;
  User? _cachedUser;

  @override
  void initState() {
    super.initState();
    _loadCachedUser();
  }

  Future<void> _loadCachedUser() async {
    final user = await UserStorage.getCurrentUser();
    if (mounted) setState(() => _cachedUser = user);
  }

  void _startCountdown() {
    if (_mobileController.text.length != 11) return;

    setState(() => _isCounting = true);
    AuthService.sendVerificationCode(_mobileController.text);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        setState(() {
          _isCounting = false;
          _countdown = 60;
        });
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final user = await AuthService.login(
      _mobileController.text,
      _codeController.text,
    );

    if (user != null) {
      await UserStorage.saveUser(user);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  void _handleQuickLogin() {
    if (_cachedUser != null) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _showConfirmDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('切换账号会清除已有用户数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _doClearUser();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _doClearUser() {
    UserStorage.clearUser().then((_) {
      if (mounted) {
        setState(() => _cachedUser = null);
      }
    });
  }

  void _handleImportConfig() async {
    try {
      final success = await UserStorage.importConfig();
      if (success) {
        await _loadCachedUser();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('配置导入成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到配置文件')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _cachedUser != null
                ? _buildCachedUserUI()
                : _buildLoginForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildCachedUserUI() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            _cachedUser!.mobileMask,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          _buildActionButton('使用当前账号', _handleQuickLogin, Colors.green),
          const SizedBox(height: 15),
          _buildActionButton('导入用户配置', _handleImportConfig, Colors.blue),
          const SizedBox(height: 15),
          _buildActionButton('切换账号', () => _showConfirmDialog(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed,
      [Color color = Colors.blue]) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const FlutterLogo(size: 100),
          const SizedBox(height: 30),
          TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '手机号',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone_iphone),
            ),
            validator: (v) =>
            v?.length == 11 ? null : '请输入有效手机号',
          ),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '验证码',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                  v?.length == 6 ? null : '请输入6位验证码',
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 64,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: _isCounting
                        ? Colors.grey[300]
                        : Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _isCounting ? null : _startCountdown,
                  child: Text(
                    _isCounting ? '$_countdown秒' : '获取验证码',
                    style: TextStyle(
                      color: _isCounting ? Colors.black87 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _submitLogin,
              child: const Text(
                '登 录',
                style: TextStyle(fontSize: 16,color: Colors.purple),
              ),
            ),
          ),
          const SizedBox(height: 20),


          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _handleImportConfig,
              child: const Text(
                '导入配置文件',
                style: TextStyle(fontSize: 13,),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
