import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref.read(authRepositoryProvider).login(
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // 登录成功后 authProvider 会触发路由跳转
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? '登录失败，请重试';
      _showError(msg);
    } catch (_) {
      _showError('网络异常，请检查网络连接');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // 标题
                Text('欢迎回来', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 8),
                Text('登录继续你的学习之旅', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                )),
                const SizedBox(height: 40),

                // 手机号
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入手机号';
                    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v)) return '手机号格式错误';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 密码
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入密码';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // 忘记密码
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showForgotPasswordSheet(),
                    child: const Text('忘记密码？'),
                  ),
                ),
                const SizedBox(height: 24),

                // 登录按钮
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: 24),

                // 注册入口
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('还没有账号？', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('立即注册'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ForgotPasswordSheet(),
    );
  }
}

// ── 忘记密码底部弹窗 ─────────────────────────────────────────

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet();

  @override
  ConsumerState<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _pwCtrl    = TextEditingController();
  bool _codeSent = false;
  bool _loading  = false;
  int  _countdown = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneCtrl.text.trim())) {
      _showError('手机号格式错误');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendSmsCode(
          _phoneCtrl.text.trim(), 'reset_password');
      setState(() { _codeSent = true; _countdown = 60; });
      _startCountdown();
    } on DioException catch (e) {
      _showError(e.response?.data?['message'] ?? '发送失败');
    }
  }

  void _startCountdown() async {
    while (_countdown > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _countdown--);
    }
  }

  Future<void> _reset() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
        phone: _phoneCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: _pwCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码重置成功，请重新登录')),
        );
      }
    } on DioException catch (e) {
      _showError(e.response?.data?['message'] ?? '重置失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('重置密码', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手机号'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _countdown > 0 ? null : _sendCode,
              child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '验证码'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pwCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: '新密码（6-18位，含字母和数字）'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_codeSent && !_loading) ? _reset : null,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('确认重置'),
            ),
          ),
        ],
      ),
    );
  }
}
