import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../sdk/services/voice_recorder_service.dart';
import '../../theme/im_design_tokens.dart';

typedef OnVoiceRecordingComplete = void Function(RecordingResult result);
typedef OnVoiceRecordingStateChanged = void Function(RecordingState state);

class VoiceInputButton extends ConsumerStatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingStateChanged,
  });

  final OnVoiceRecordingComplete onRecordingComplete;
  final OnVoiceRecordingStateChanged? onRecordingStateChanged;

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton> {
  RecordingState _recordingState = RecordingState.idle;
  Duration _currentDuration = Duration.zero;
  List<double> _waveform = [];
  Offset? _dragStartOffset;
  bool _isCancelling = false;
  String? _errorMessage;
  StreamSubscription<AmplitudeData>? _amplitudeSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<RecordingState>? _stateSubscription;

  static const int _minRecordingDurationMs = 1000;
  static const int _maxRecordingDurationMs = 60000;
  static const double _cancelThreshold = -100;

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _amplitudeSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _amplitudeSubscription = null;
    _durationSubscription = null;
    _stateSubscription = null;
  }

  void _setupSubscriptions(VoiceRecorderService recorder) {
    _cancelSubscriptions();

    _stateSubscription = recorder.stateStream.listen((state) {
      setState(() {
        _recordingState = state;
      });
      widget.onRecordingStateChanged?.call(state);
    });

    _amplitudeSubscription = recorder.amplitudeStream.listen((amplitude) {
      setState(() {
        _waveform.add(amplitude.normalized);
        if (_waveform.length > 30) {
          _waveform.removeAt(0);
        }
      });
    });

    _durationSubscription = recorder.durationStream.listen((duration) {
      setState(() {
        _currentDuration = duration;
      });

      if (duration.inMilliseconds >= _maxRecordingDurationMs) {
        _stopRecording();
      }
    });
  }

  Future<bool> _checkPermission() async {
    final recorder = ref.read(voiceRecorderServiceProvider);
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      // 权限被拒绝，请求权限
      final result = await recorder.requestPermission();
      return result;
    } else if (status.isPermanentlyDenied) {
      // 权限被永久拒绝，引导用户去设置中开启
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要麦克风权限'),
            content: const Text('请在设置中开启麦克风权限，以便录制语音消息。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('去设置'),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return false;
  }

  Future<void> _startRecording() async {
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage = '需要麦克风权限才能录制语音';
      });
      return;
    }

    final recorder = ref.read(voiceRecorderServiceProvider);
    _setupSubscriptions(recorder);

    setState(() {
      _waveform = [];
      _currentDuration = Duration.zero;
      _isCancelling = false;
      _errorMessage = null;
    });

    await recorder.startRecording(checkPermission: false);
  }

  Future<void> _stopRecording() async {
    final recorder = ref.read(voiceRecorderServiceProvider);
    final result = await recorder.stopRecording();

    if (result.isSuccess) {
      if (result.duration.inMilliseconds < _minRecordingDurationMs) {
        _showTooShortWarning();
        _cancelRecording();
      } else {
        widget.onRecordingComplete(result);
      }
    } else if (result.error != null) {
      setState(() {
        _errorMessage = result.error;
      });
    }

    _cancelSubscriptions();
    setState(() {
      _recordingState = RecordingState.idle;
      _waveform = [];
    });
  }

  Future<void> _cancelRecording() async {
    final recorder = ref.read(voiceRecorderServiceProvider);
    await recorder.cancelRecording();
    _cancelSubscriptions();
    setState(() {
      _recordingState = RecordingState.idle;
      _waveform = [];
      _isCancelling = false;
    });
  }

  void _showTooShortWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('说话时间太短'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    _dragStartOffset = details.globalPosition;
    _startRecording();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartOffset == null) return;

    final deltaY = details.globalPosition.dy - _dragStartOffset!.dy;
    final isCancelling = deltaY < _cancelThreshold;

    if (isCancelling != _isCancelling) {
      setState(() {
        _isCancelling = isCancelling;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isCancelling) {
      _cancelRecording();
    } else {
      _stopRecording();
    }
    _dragStartOffset = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_recordingState == RecordingState.recording ||
            _recordingState == RecordingState.preparing)
          _buildRecordingOverlay(colors),
        _buildButton(colors),
      ],
    );
  }

  Widget _buildButton(ImColorScheme colors) {
    final isRecording = _recordingState == RecordingState.recording ||
        _recordingState == RecordingState.preparing;

    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isRecording
              ? colors.primary.withValues(alpha: 0.1)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isRecording ? colors.primary : colors.divider,
            width: 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRecording ? Icons.mic : Icons.mic_none,
                color: isRecording ? colors.primary : colors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isRecording ? '松开结束，上滑取消' : '按住说话',
                style: TextStyle(
                  color: isRecording ? colors.primary : colors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingOverlay(ImColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeDisplay(colors),
          const SizedBox(height: 16),
          _buildWaveform(colors),
          const SizedBox(height: 16),
          _buildCancelHint(colors),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(ImColorScheme colors) {
    final seconds = _currentDuration.inSeconds;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final timeText = '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';

    final maxSeconds = _maxRecordingDurationMs ~/ 1000;
    final progress = seconds / maxSeconds;
    final isNearLimit = progress > 0.8;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mic,
          color: isNearLimit ? colors.error : colors.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          timeText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isNearLimit ? colors.error : colors.textPrimary,
          ),
        ),
        if (isNearLimit) ...[
          const SizedBox(width: 8),
          Text(
            '即将结束',
            style: TextStyle(
              fontSize: 12,
              color: colors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWaveform(ImColorScheme colors) {
    return Container(
      height: 40,
      width: 200,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _waveform.isEmpty
            ? [
                Container(
                  width: 4,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: colors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ]
            : _waveform.map((value) {
                final height = 8 + value * 28;
                return Container(
                  width: 4,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _isCancelling ? colors.error : colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
      ),
    );
  }

  Widget _buildCancelHint(ImColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.keyboard_arrow_up,
          size: 16,
          color: _isCancelling ? colors.error : colors.textSecondary,
        ),
        Text(
          _isCancelling ? '松开取消发送' : '上滑取消',
          style: TextStyle(
            fontSize: 12,
            color: _isCancelling ? colors.error : colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
