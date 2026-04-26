import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/im_provider.dart';
import '../sdk/config/im_sdk_config.dart';
import 'home_page.dart';

/// 登录页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

/// 服务器预设
/// 注意: useTls 参数表示 DirectTLS，现代服务器使用 STARTTLS (useTls=false)
enum ServerPreset {
  localhost('本地服务器', 'localhost', 5222, 'localhost', false),
  // 腾讯云使用明文连接（服务器已禁用 STARTTLS 广播）
  tencentCloud('腾讯云服务器', '43.143.160.115', 5222, 'localhost', false),
  // 公共服务器使用 STARTTLS (useTls=false)，不是 DirectTLS
  conversationsIm('conversations.im', 'conversations.im', 5222, 'conversations.im', false),
  jabberDe('jabber.de', 'jabber.de', 5222, 'jabber.de', false),
  custom('自定义', '', 5222, '', false);

  final String label;
  final String host;
  final int port;
  final String domain;
  final bool useTls;

  const ServerPreset(this.label, this.host, this.port, this.domain, this.useTls);
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  final _hostController = TextEditingController(text: '43.143.160.115');
  final _portController = TextEditingController(text: '5222');
  final _domainController = TextEditingController(text: 'localhost');

  bool _isConnecting = false;
  bool _showAdvanced = false;
  bool _useTls = false;
  bool _obscurePassword = true;
  ServerPreset _selectedPreset = ServerPreset.tencentCloud;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  void _showRegisterDialog() {
    final regUsernameController = TextEditingController();
    final regPasswordController = TextEditingController();
    final regConfirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注册新账号'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: regUsernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  prefixIcon: Icon(Icons.person),
                  hintText: '字母、数字，不含@',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock),
                  hintText: '至少6位',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regConfirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '将注册到: ${_domainController.text}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final username = regUsernameController.text.trim();
              final password = regPasswordController.text.trim();
              final confirm = regConfirmController.text.trim();

              if (username.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写用户名和密码')),
                );
                return;
              }

              if (username.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('用户名不能包含@符号')),
                );
                return;
              }

              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('密码至少6位')),
                );
                return;
              }

              if (password != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('两次密码不一致')),
                );
                return;
              }

              Navigator.pop(context);

              // 显示加载中
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('正在注册...'),
                    ],
                  ),
                ),
              );

              try {
                final service = ref.read(imConnectionServiceProvider);
                // 需要先临时初始化 API 来注册
                final config = ImSdkConfig(
                  host: _hostController.text,
                  port: int.tryParse(_portController.text) ?? 5222,
                  domain: _domainController.text,
                  useTls: _useTls,
                  apiPort: 5280,
                );
                service.initApiClient(config);
                await service.registerUser(
                  username,
                  password,
                  _domainController.text,
                );

                if (mounted) {
                  Navigator.pop(context); // 关闭加载对话框
                  // 自动填入用户名密码
                  _usernameController.text = username;
                  _passwordController.text = password;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('注册成功，请点击登录')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // 关闭加载对话框
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('注册失败: $e')),
                  );
                }
              }
            },
            child: const Text('注册'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_isConnecting) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入用户名和密码')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    final service = ref.read(imConnectionServiceProvider);

    final config = ImSdkConfig(
      host: _hostController.text,
      port: int.tryParse(_portController.text) ?? 5222,
      domain: _domainController.text,
      useTls: _useTls,
      apiPort: 5280,  // ejabberd REST API 端口
    );

    final credentials = ImCredentials(
      username: username,
      password: password,
    );

    try {
      final success = await service.connect(config, credentials);
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录失败，请检查账号密码')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接错误: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _simulateLogin() async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);

    final service = ref.read(imConnectionServiceProvider);

    final config = ImSdkConfig(
      host: 'localhost',
      port: 5222,
      domain: 'localhost',
      useTls: false,
      apiPort: 5280,
    );

    final credentials = ImCredentials(
      username: 'demo',
      password: 'demo123',
    );

    try {
      final success = await service.connect(config, credentials);
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模拟登录失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('模拟登录错误: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo
              Icon(
                Icons.chat_bubble,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '畅聊天下',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '互联互动',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),

              // 用户名
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: '用户名',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 密码
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 16),

              // 高级设置折叠
              GestureDetector(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '服务器设置',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Icon(
                      _showAdvanced
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),

              // 高级设置
              if (_showAdvanced) ...[
                const SizedBox(height: 16),
                // 服务器预设选择
                DropdownButtonFormField<ServerPreset>(
                  value: _selectedPreset,
                  decoration: InputDecoration(
                    labelText: '服务器预设',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  items: ServerPreset.values.map((preset) {
                    return DropdownMenuItem(
                      value: preset,
                      child: Text(preset.label),
                    );
                  }).toList(),
                  onChanged: (preset) {
                    if (preset != null) {
                      setState(() {
                        _selectedPreset = preset;
                        if (preset != ServerPreset.custom) {
                          _hostController.text = preset.host;
                          _portController.text = preset.port.toString();
                          _domainController.text = preset.domain;
                          _useTls = preset.useTls;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _hostController,
                        decoration: InputDecoration(
                          labelText: '主机',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        enabled: _selectedPreset == ServerPreset.custom,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _portController,
                        decoration: InputDecoration(
                          labelText: '端口',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        enabled: _selectedPreset == ServerPreset.custom,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _domainController,
                  decoration: InputDecoration(
                    labelText: '域名',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  enabled: _selectedPreset == ServerPreset.custom,
                ),
                const SizedBox(height: 8),
                // DirectTLS 开关 (通常不需要开启)
                SwitchListTile(
                  title: const Text('直连 TLS (DirectTLS)'),
                  subtitle: Text(
                    _useTls ? '端口 5223 直接 TLS' : '端口 5222 使用 STARTTLS',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _useTls,
                  onChanged: _selectedPreset == ServerPreset.custom
                      ? (value) => setState(() => _useTls = value)
                      : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],

              const SizedBox(height: 32),

              // 登录按钮
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _login,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),

              // 模拟登录按钮
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _simulateLogin,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.green[600],
                  ),
                  child: const Text('模拟登录', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),

              // 注册按钮
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _isConnecting ? null : _showRegisterDialog,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('注册新账号', style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 32),

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
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '快速开始',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '方式一：本地服务器\n'
                        '1. docker run -d --name ejabberd -p 5222:5222 ejabberd/ecs\n'
                        '2. docker exec ejabberd ejabberdctl register admin localhost admin\n'
                        '3. 使用 admin/admin 登录\n\n'
                        '方式二：公共服务器\n'
                        '1. 访问 https://account.conversations.im/register 注册\n'
                        '2. 选择服务器预设「conversations.im」\n'
                        '3. 输入注册的用户名和密码登录',
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
      ),
    );
  }
}
