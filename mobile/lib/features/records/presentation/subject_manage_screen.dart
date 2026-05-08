import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../data/records_repository.dart';

class SubjectManageScreen extends ConsumerWidget {
  const SubjectManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('科目管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加科目'),
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (subjects) {
          if (subjects.isEmpty) {
            return const Center(
              child: Text('暂无科目，点击右下角添加', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (ctx, i) {
              final s = subjects[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(s.name.substring(0, 1)),
                  ),
                  title: Text(s.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.isDefault)
                        const Chip(label: Text('默认'), padding: EdgeInsets.zero),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, s),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('添加科目'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '科目名称',
            hintText: '如：Java编程、英语单词...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await ref.read(recordsRepositoryProvider).addSubject(name, 'book');
                ref.invalidate(subjectListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('科目「$name」已添加')),
                  );
                }
              } on DioException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.response?.data?['message'] ?? '添加失败'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SubjectModel subject) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除科目「${subject.name}」'),
        content: const Text('删除后该科目下的学习记录不会丢失，仅科目本身删除。确认删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(recordsRepositoryProvider).deleteSubject(subject.id);
              ref.invalidate(subjectListProvider);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
