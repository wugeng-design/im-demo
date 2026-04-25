import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sdk/services/call_service.dart';
import '../sdk/services/impl/agora_call_service_impl.dart';

final callServiceProvider = Provider<CallService>((ref) {
  final service = AgoraCallService();
  ref.onDispose(() => service.dispose());
  return service;
});

final callStateStreamProvider = StreamProvider<CallInfo?>((ref) {
  final service = ref.watch(callServiceProvider);
  return service.callStateStream;
});

final isInCallProvider = Provider<bool>((ref) {
  final service = ref.watch(callServiceProvider);
  return service.currentCallInfo?.isActive ?? false;
});

class CallNotifier extends StateNotifier<CallStateData> {
  final CallService _callService;

  CallNotifier(this._callService) : super(CallStateData.initial()) {
    _listenToCallState();
  }

  void _listenToCallState() {
    _callService.callStateStream.listen((callInfo) {
      state = state.copyWith(
        currentCall: callInfo,
        isInCall: callInfo?.isActive ?? false,
      );
    });

    _callService.errorStream.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  Future<void> initialize({required String appId, String? appCertificate}) async {
    await _callService.initialize(appId: appId, appCertificate: appCertificate);
    state = state.copyWith(isInitialized: true);
  }

  Future<String?> startCall({
    required String peerId,
    required String peerName,
    required CallType callType,
  }) async {
    final callId = await _callService.startCall(
      peerId: peerId,
      peerName: peerName,
      callType: callType,
    );
    if (callId != null) {
      state = state.copyWith(currentCall: _callService.currentCallInfo);
    }
    return callId;
  }

  Future<void> acceptCall(String callId) async {
    await _callService.acceptCall(callId);
  }

  Future<void> rejectCall(String callId) async {
    await _callService.rejectCall(callId);
  }

  Future<void> endCall(String callId) async {
    await _callService.endCall(callId);
    state = state.copyWith(currentCall: null, isInCall: false);
  }

  Future<void> toggleMute(bool mute) async {
    await _callService.toggleMute(mute);
  }

  Future<void> toggleSpeaker(bool enable) async {
    await _callService.toggleSpeaker(enable);
  }

  Future<void> switchCamera() async {
    await _callService.switchCamera();
  }

  Future<void> switchCallType(CallType callType) async {
    await _callService.switchCallType(callType);
  }
}

class CallStateData {
  final CallInfo? currentCall;
  final bool isInCall;
  final bool isInitialized;
  final String? error;

  const CallStateData({
    this.currentCall,
    this.isInCall = false,
    this.isInitialized = false,
    this.error,
  });

  CallStateData.initial()
      : currentCall = null,
        isInCall = false,
        isInitialized = false,
        error = null;

  CallStateData copyWith({
    CallInfo? currentCall,
    bool? isInCall,
    bool? isInitialized,
    String? error,
  }) {
    return CallStateData(
      currentCall: currentCall ?? this.currentCall,
      isInCall: isInCall ?? this.isInCall,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }
}

final callNotifierProvider = StateNotifierProvider<CallNotifier, CallStateData>((ref) {
  final service = ref.watch(callServiceProvider);
  return CallNotifier(service);
});
