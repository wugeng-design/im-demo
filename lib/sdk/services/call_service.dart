import 'dart:async';

import 'package:flutter/foundation.dart';

enum CallType {
  voice,
  video,
}

enum CallState {
  idle,
  calling,
  ringing,
  connected,
  disconnected,
  failed,
}

enum CallRole {
  caller,
  callee,
}

class CallInfo {
  final String callId;
  final String peerId;
  final String peerName;
  final CallType callType;
  final CallState state;
  final CallRole role;
  final DateTime startTime;
  final Duration? duration;
  final String? error;

  const CallInfo({
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.callType,
    required this.state,
    required this.role,
    required this.startTime,
    this.duration,
    this.error,
  });

  CallInfo copyWith({
    String? callId,
    String? peerId,
    String? peerName,
    CallType? callType,
    CallState? state,
    CallRole? role,
    DateTime? startTime,
    Duration? duration,
    String? error,
  }) {
    return CallInfo(
      callId: callId ?? this.callId,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      callType: callType ?? this.callType,
      state: state ?? this.state,
      role: role ?? this.role,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      error: error ?? this.error,
    );
  }

  bool get isActive =>
      state == CallState.calling ||
      state == CallState.ringing ||
      state == CallState.connected;
}

abstract class CallService {
  final StreamController<CallInfo?> _callStateController =
      StreamController<CallInfo?>.broadcast();
  final StreamController<CallInfo> _remoteStreamController =
      StreamController<CallInfo>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Stream<CallInfo?> get callStateStream => _callStateController.stream;
  Stream<CallInfo> get remoteStream => _remoteStreamController.stream;
  Stream<String> get errorStream => _errorController.stream;

  CallInfo? get currentCallInfo => currentCall;

  @protected
  CallInfo? currentCall;

  @protected
  bool isInitialized = false;

  Future<void> initialize({
    required String appId,
    String? appCertificate,
  });

  Future<bool> checkPermissions();

  Future<bool> requestPermissions();

  Future<String?> startCall({
    required String peerId,
    required String peerName,
    required CallType callType,
    Map<String, dynamic>? extraData,
  });

  Future<void> acceptCall(String callId);

  Future<void> rejectCall(String callId);

  Future<void> endCall(String callId);

  Future<void> switchCamera();

  Future<void> toggleMute(bool mute);

  Future<void> toggleSpeaker(bool enable);

  Future<void> switchCallType(CallType callType);

  @protected
  void updateCallState(CallInfo? callInfo) {
    currentCall = callInfo;
    _callStateController.add(callInfo);
  }

  @protected
  void notifyRemoteEvent(CallInfo callInfo) {
    _remoteStreamController.add(callInfo);
  }

  @protected
  void notifyError(String error) {
    _errorController.add(error);
    debugPrint('[CallService] Error: $error');
  }

  void dispose() {
    _callStateController.close();
    _remoteStreamController.close();
    _errorController.close();
  }
}

class CallServiceConfig {
  final String appId;
  final String? appCertificate;
  final String? token;
  final int? uid;
  final String? userId;
  final String? userName;
  final bool enableVideo;
  final String? channelName;
  final List<String>? services;

  const CallServiceConfig({
    required this.appId,
    this.appCertificate,
    this.token,
    this.uid,
    this.userId,
    this.userName,
    this.enableVideo = true,
    this.channelName,
    this.services,
  });
}
