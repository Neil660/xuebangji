import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

// 赛道列表 provider
final _tracksProvider = FutureProvider<List<TrackModel>>((ref) {
  return ref.read(authRepositoryProvider).getTracks();
});

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _nickCtrl  = TextEditingController();

  int? _selectedTrackId;
  bool _loading    = false;
  bool _codeSent   = false;
  int  _countdown  = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneCtrl.text.trim())) {
      _showError('手机号格式错误');
      return;
    }
    try {
      await ref.read(authRepositoryProvider)
          .sendSmsCode(_phoneCtrl.text.trim(), 'register');
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTrackId == null) {
      _showError('请选择你的赛道');
      return;
    }
    setState(() => _loading = true);

    try {
      await ref.read(authRepositoryProvider).register(
        phone: _phoneCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        password: _pwCtrl.text,
        nickname: _nickCtrl.text.trim(),
        trackId: _selectedTrackId!,
      );
      // 注册成功后路由自动跳转
    } on DioException catch (e) {
      _showError(e.response?.data?['message'] ?? '注册失败');
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
    final tracksAsync = ref.watch(_tracksProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: const Text('注册'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 手机号 + 验证码
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: '手机号'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请输入手机号';
                        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v)) return '格式错误';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _countdown > 0 ? null : _sendCode,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(100, 52)),
                    child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '验证码'),
                  validator: (v) {
                    if (v == null || v.length != 6) return '请输入6位验证码';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _pwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码（6-18位，含字母和数字）',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请设置密码';
                    if (v.length < 6 || v.length > 18) return '密码长度6-18位';
                    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(v)) {
                      return '密码需同时包含字母和数字';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nickCtrl,
                  decoration: const InputDecoration(
                    labelText: '昵称（2-10位）',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入昵称';
                    if (v.trim().length < 2 || v.trim().length > 10) return '昵称长度2-10位';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 赛道选择
                Text('选择你的赛道', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                tracksAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('加载赛道失败，请刷新'),
                  data: (tracks) {
                    // 按 category 分组
                    final grouped = <String, List<TrackModel>>{};
                    for (final t in tracks) {
                      grouped.putIfAbsent(t.category, () => []).add(t);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(entry.key,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value.map((track) {
                                final selected = _selectedTrackId == track.id;
                                return GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedTrackId = track.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.white,
                                      border: Border.all(
                                        color: selected
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      track.name,
                                      style: TextStyle(
                                        color: selected ? Colors.white : Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_codeSent && !_loading) ? _register : null,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('注册'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('已有账号？', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('去登录'),
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
}
