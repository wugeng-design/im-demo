import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:im_sdk_demo/pages/call_page.dart';
import 'package:im_sdk_demo/providers/call_provider.dart';
import 'package:im_sdk_demo/sdk/services/call_service.dart';

class CallIncomingDialog extends ConsumerWidget {
  final CallInfo callInfo;

  const CallIncomingDialog({
    Key? key,
    required this.callInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2196F3),
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTopSection(),
              _buildMiddleSection(),
              _buildBottomSection(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Text(
        callInfo.callType == CallType.video ? '视频通话' : '语音通话',
        style: const TextStyle(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMiddleSection() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Center(
            child: callInfo.callType == CallType.video
                ? const Icon(
                    Icons.videocam,
                    size: 60,
                    color: Color(0xFF2196F3),
                  )
                : const Icon(
                    Icons.phone,
                    size: 60,
                    color: Color(0xFF2196F3),
                  ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          callInfo.peerName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '正在呼叫...',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 32),
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCallActionButton(
            icon: Icons.call_end,
            label: '拒绝',
            color: Colors.red,
            onPressed: () async {
              final callNotifier = ref.read(callNotifierProvider.notifier);
              await callNotifier.rejectCall(callInfo.callId);
              Navigator.of(context).pop();
            },
          ),
          _buildCallActionButton(
            icon: callInfo.callType == CallType.video ? Icons.videocam : Icons.call,
            label: '接听',
            color: Colors.green,
            onPressed: () async {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    callId: callInfo.callId,
                    peerId: callInfo.peerId,
                    peerName: callInfo.peerName,
                    callType: callInfo.callType,
                    callRole: CallRole.callee,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 32),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
