import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/im_provider.dart';
import '../sdk/logging/logging.dart';

/// IM Debug 工具页面
///
/// 功能:
/// - 查看实时日志
/// - 导出日志文件
/// - 清理 IM 数据
class ImDebugPage extends ConsumerStatefulWidget {
  const ImDebugPage({super.key});

  @override
  ConsumerState<ImDebugPage> createState() => _ImDebugPageState();
}

class _ImDebugPageState extends ConsumerState<ImDebugPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug 工具'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '日志'),
            Tab(text: '状态'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LogViewerTab(),
          _StatusTab(),
        ],
      ),
    );
  }
}

/// 日志查看器标签页
class _LogViewerTab extends StatefulWidget {
  const _LogViewerTab();

  @override
  State<_LogViewerTab> createState() => _LogViewerTabState();
}

class _LogViewerTabState extends State<_LogViewerTab> {
  List<File> _logFiles = [];
  File? _selectedFile;
  List<String> _logLines = [];
  bool _isLoading = false;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await ImFileLogger.getLogFiles();
      setState(() {
        _logFiles = files;
        if (files.isNotEmpty) {
          _selectedFile = files.first;
          _loadLogContent(files.first);
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLogContent(File file) async {
    setState(() => _isLoading = true);
    try {
      final content = await file.readAsString();
      setState(() {
        _logLines = content.split('\n').where((l) => l.isNotEmpty).toList();
        _selectedFile = file;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('读取日志失败: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> get _filteredLogLines {
    if (_selectedTag == null) return _logLines;
    return _logLines.where((line) => line.contains('[$_selectedTag]')).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        _buildToolbar(),
        // 日志内容
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logLines.isEmpty
                  ? _buildEmptyState()
                  : _buildLogList(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // 文件选择器
          Expanded(
            child: DropdownButton<File>(
              value: _selectedFile,
              isExpanded: true,
              hint: const Text('选择日志文件'),
              items: _logFiles.map((file) {
                final name = file.path.split('/').last;
                return DropdownMenuItem(value: file, child: Text(name));
              }).toList(),
              onChanged: (file) {
                if (file != null) _loadLogContent(file);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Tag 过滤
          PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_list,
              color: _selectedTag != null ? Colors.blue : Colors.grey[600],
            ),
            tooltip: '按 Tag 过滤',
            onSelected: (tag) => setState(() => _selectedTag = tag),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('全部')),
              const PopupMenuDivider(),
              ...ImLogTags.commonTags.map(
                (tag) => PopupMenuItem(value: tag, child: Text(tag)),
              ),
            ],
          ),
          // 刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              if (_selectedFile != null) {
                _loadLogContent(_selectedFile!);
              }
            },
          ),
          // 导出
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '导出日志',
            onPressed: _exportLogs,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无日志',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '日志会在 IM 操作时自动记录',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    final lines = _filteredLogLines;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[lines.length - 1 - index]; // 倒序显示
        return _LogLineWidget(line: line);
      },
    );
  }

  Future<void> _exportLogs() async {
    try {
      // 刷新日志缓冲
      await ImFileLogger.flush();
      final logsPath = await ImFileLogger.export();

      if (logsPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有日志可导出')),
          );
        }
        return;
      }

      // 获取所有日志文件
      final files = await ImFileLogger.getLogFiles();
      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有日志文件')),
          );
        }
        return;
      }

      // 分享日志文件
      final xFiles = files.map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(
        xFiles,
        subject: 'IM Debug 日志',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
}

/// 日志行组件
class _LogLineWidget extends StatelessWidget {
  final String line;

  const _LogLineWidget({required this.line});

  @override
  Widget build(BuildContext context) {
    // 解析日志级别颜色
    Color color = Colors.grey[700]!;
    if (line.contains('[ERROR]')) {
      color = Colors.red;
    } else if (line.contains('[WARN]')) {
      color = Colors.orange;
    } else if (line.contains('[INFO]')) {
      color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        line,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: color,
        ),
      ),
    );
  }
}

/// 状态标签页
class _StatusTab extends ConsumerWidget {
  const _StatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(imConnectionStateProvider);
    final isConnected = ref.watch(isConnectedProvider);
    final currentJid = ref.watch(currentJidProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 连接状态卡片
        _buildCard(
          title: '连接状态',
          icon: Icons.wifi,
          children: [
            _buildInfoRow(
              '状态',
              connectionState.when(
                data: (event) => event.state.name,
                loading: () => '加载中...',
                error: (e, _) => '错误: $e',
              ),
              valueColor: isConnected ? Colors.green : Colors.red,
            ),
            _buildInfoRow('当前 JID', currentJid ?? '未连接'),
            _buildInfoRow('日志目录', ImFileLogger.logsPath ?? '未初始化'),
          ],
        ),
        const SizedBox(height: 16),

        // 日志系统卡片
        _buildCard(
          title: '日志系统',
          icon: Icons.description,
          children: [
            _buildInfoRow('初始化', ImFileLogger.isInitialized ? '是' : '否'),
            _buildInfoRow('日志目录', ImFileLogger.logsPath ?? '未设置'),
          ],
        ),
        const SizedBox(height: 16),

        // 操作按钮
        _buildCard(
          title: '调试操作',
          icon: Icons.build,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add, color: Colors.blue),
              title: const Text('写入测试日志'),
              onTap: () {
                imLog('测试日志消息', tag: ImLogTags.debug);
                imLogInfo('Info 级别测试', tag: ImLogTags.debug);
                imLogWarn('Warning 级别测试', tag: ImLogTags.debug);
                imLogError('Error 级别测试', tag: ImLogTags.debug);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已写入测试日志')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.orange),
              title: const Text('刷新日志缓冲'),
              onTap: () async {
                await ImFileLogger.flush();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('日志缓冲已刷新')),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
