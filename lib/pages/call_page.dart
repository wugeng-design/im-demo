import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:im_sdk_demo/providers/call_provider.dart';
import 'package:im_sdk_demo/sdk/services/call_service.dart';

class CallPage extends ConsumerStatefulWidget {
  final String callId;
  final String peerId;
  final String peerName;
  final CallType callType;
  final CallRole callRole;

  const CallPage({
    Key? key,
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.callType,
    required this.callRole,
  }) : super(key: key);

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = true;
  bool _isCallConnected = false;
  DateTime _callStartTime = DateTime.now();
  String _callStatus = '';

  @override
  void initState() {
    super.initState();
    _updateCallStatus();
  }

  void _updateCallStatus() {
    if (widget.callRole == CallRole.caller) {
      _callStatus = '正在呼叫...';
    } else {
      _callStatus = '对方正在呼叫...';
    }
  }

  Future<void> _acceptCall() async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    await callNotifier.acceptCall(widget.callId);
    setState(() {
      _isCallConnected = true;
      _callStatus = '通话中';
    });
  }

  Future<void> _rejectCall() async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    await callNotifier.rejectCall(widget.callId);
    Navigator.of(context).pop();
  }

  Future<void> _endCall() async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    await callNotifier.endCall(widget.callId);
    Navigator.of(context).pop();
  }

  Future<void> _toggleMute() async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    setState(() {
      _isMuted = !_isMuted;
    });
    await callNotifier.toggleMute(_isMuted);
  }

  Future<void> _toggleSpeaker() async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    await callNotifier.toggleSpeaker(_isSpeakerOn);
  }

  Future<void> _toggleCamera() async {
    if (widget.callType == CallType.video) {
      setState(() {
        _isCameraOn = !_isCameraOn;
      });
      // 这里需要实现摄像头开关逻辑
    }
  }

  Future<void> _switchCamera() async {
    if (widget.callType == CallType.video) {
      final callNotifier = ref.read(callNotifierProvider.notifier);
      await callNotifier.switchCamera();
    }
  }

  String _formatCallDuration() {
    final duration = DateTime.now().difference(_callStartTime);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTopSection(),
            _buildMiddleSection(),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(
            widget.peerName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isCallConnected ? _formatCallDuration() : _callStatus,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleSection() {
    if (widget.callType == CallType.video) {
      return Expanded(
        child: Center(
          child: Stack(
            children: [
              // 对方视频画面
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: _isCallConnected
                    ? const Center(
                        child: Text(
                          '对方视频',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
              ),
              // 自己的视频画面（小窗口）
              if (_isCallConnected && _isCameraOn)
                Positioned(
                  top: 20,
                  right: 20,
                  width: 120,
                  height: 180,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        '自己视频',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      // 语音通话
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2196F3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.phone,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (!_isCallConnected)
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBottomSection() {
    if (widget.callRole == CallRole.callee && !_isCallConnected) {
      // 来电时的接听/拒绝按钮
      return Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCallActionButton(
              icon: Icons.call_end,
              label: '拒绝',
              color: Colors.red,
              onPressed: _rejectCall,
            ),
            _buildCallActionButton(
              icon: Icons.call,
              label: '接听',
              color: Colors.green,
              onPressed: _acceptCall,
            ),
          ],
        ),
      );
    } else {
      // 通话中的控制按钮
      return Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.callType == CallType.video)
              _buildCallControlButton(
                icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                onPressed: _toggleCamera,
              ),
            _buildCallControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              onPressed: _toggleMute,
            ),
            _buildCallControlButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              onPressed: _toggleSpeaker,
            ),
            if (widget.callType == CallType.video)
              _buildCallControlButton(
                icon: Icons.flip_camera_ios,
                onPressed: _switchCamera,
              ),
            _buildCallActionButton(
              icon: Icons.call_end,
              label: '结束',
              color: Colors.red,
              onPressed: _endCall,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCallControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.withOpacity(0.3),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
