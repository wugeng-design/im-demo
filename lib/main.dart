import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sdk/im_sdk.dart';

void main() {
  runApp(const ProviderScope(child: ImSdkDemoApp()));
}

class ImSdkDemoApp extends StatelessWidget {
  const ImSdkDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IM SDK Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ImSdkDemoPage(),
    );
  }
}

/// IM SDK 演示页面
class ImSdkDemoPage extends ConsumerStatefulWidget {
  const ImSdkDemoPage({super.key});

  @override
  ConsumerState<ImSdkDemoPage> createState() => _ImSdkDemoPageState();
}

class _ImSdkDemoPageState extends ConsumerState<ImSdkDemoPage> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin');
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '5222');
  final _domainController = TextEditingController(text: 'localhost');
  final _messageController = TextEditingController();
  final _toJidController = TextEditingController(text: 'user1@localhost');

  late StandaloneConnectionService _connectionService;
  final List<String> _logs = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _connectionService = StandaloneConnectionService();

    // 监听连接状态变化
    _connectionService.connectionState.listen((event) {
      _addLog('State: ${event.state.name}${event.error != null ? " - ${event.error}" : ""}');
      if (mounted) setState(() {});
    });

    // 监听收到的消息
    _connectionService.messageStream.listen((ReceivedMessage message) {
      _addLog('📩 From ${message.from}: ${message.body}');
    });
  }

  @override
  void dispose() {
    _connectionService.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _domainController.dispose();
    _messageController.dispose();
    _toJidController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  Future<void> _connect() async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);

    final config = ImSdkConfig(
      host: _hostController.text,
      port: int.tryParse(_portController.text) ?? 5222,
      domain: _domainController.text,
    );

    final credentials = ImCredentials(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    _addLog('Connecting to ${config.host}:${config.port}...');

    try {
      final success = await _connectionService.connect(config, credentials);
      if (success) {
        _addLog('Connected as ${_connectionService.currentJid}');
      } else {
        _addLog('Connection failed');
      }
    } catch (e) {
      _addLog('Error: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    _addLog('Disconnecting...');
    await _connectionService.disconnect();
    _addLog('Disconnected');
  }

  Future<void> _sendMessage() async {
    final toJid = _toJidController.text.trim();
    final message = _messageController.text.trim();

    if (toJid.isEmpty || message.isEmpty) {
      _addLog('Please enter recipient JID and message');
      return;
    }

    try {
      await _connectionService.sendMessage(toJid, message);
      _addLog('Sent to $toJid: $message');
      _messageController.clear();
    } catch (e) {
      _addLog('Send error: $e');
    }
  }

  Future<void> _sendPresence() async {
    try {
      await _connectionService.sendPresence(status: 'Available');
      _addLog('Presence sent');
    } catch (e) {
      _addLog('Presence error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionService.isConnected;
    final currentState = _connectionService.currentState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IM SDK Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _getStateColor(currentState),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentState.name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 连接配置卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Configuration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _hostController,
                            decoration: const InputDecoration(
                              labelText: 'Host',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            enabled: !isConnected,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            enabled: !isConnected,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _domainController,
                      decoration: const InputDecoration(
                        labelText: 'Domain',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      enabled: !isConnected,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            enabled: !isConnected,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            obscureText: true,
                            enabled: !isConnected,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected || _isConnecting
                                ? null
                                : _connect,
                            icon: _isConnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected ? _disconnect : null,
                            icon: const Icon(Icons.logout),
                            label: const Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[100],
                              foregroundColor: Colors.red[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 消息发送卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Message',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _toJidController,
                      decoration: const InputDecoration(
                        labelText: 'Recipient JID (e.g., user@localhost)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      enabled: isConnected,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                      enabled: isConnected,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected ? _sendMessage : null,
                            icon: const Icon(Icons.send),
                            label: const Text('Send'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isConnected ? _sendPresence : null,
                          icon: const Icon(Icons.person),
                          label: const Text('Presence'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 日志卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Logs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          onPressed: () => setState(() => _logs.clear()),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text(
                                'No logs yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    _logs[index],
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 帮助信息
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Start',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Start ejabberd server:\n'
                      '   docker run -d --name ejabberd -p 5222:5222 ejabberd/ecs\n\n'
                      '2. Register users:\n'
                      '   docker exec ejabberd ejabberdctl register admin localhost admin\n'
                      '   docker exec ejabberd ejabberdctl register user1 localhost user1\n\n'
                      '3. Connect with admin/admin credentials\n\n'
                      '4. Send messages to user1@localhost',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStateColor(ImConnectionState state) {
    switch (state) {
      case ImConnectionState.disconnected:
        return Colors.grey;
      case ImConnectionState.connecting:
      case ImConnectionState.authenticating:
        return Colors.orange;
      case ImConnectionState.connected:
        return Colors.blue;
      case ImConnectionState.authenticated:
        return Colors.green;
      case ImConnectionState.reconnecting:
        return Colors.amber;
      case ImConnectionState.failed:
        return Colors.red;
    }
  }
}
