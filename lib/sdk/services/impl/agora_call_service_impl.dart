import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../call_service.dart';

class AgoraCallService extends CallService {
  RtcEngineEx? _engine;
  String? _currentChannel;
  bool _isSpeakerOn = true;

  @override
  Future<void> initialize({
    required String appId,
    String? appCertificate,
  }) async {
    if (isInitialized) {
      debugPrint('[AgoraCall] Already initialized');
      return;
    }

    try {
      _engine = createAgoraRtcEngineEx();

      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      await _engine!.enableVideo();
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
              '[AgoraCall] onJoinChannelSuccess channel: ${connection.channelId}, uid: ${connection.localUid}',
            );
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[AgoraCall] onUserJoined remoteUid: $remoteUid');
            if (currentCall != null) {
              final updatedCall = currentCall!.copyWith(
                state: CallState.connected,
              );
              updateCallState(updatedCall);
              notifyRemoteEvent(updatedCall);
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[AgoraCall] onUserOffline remoteUid: $remoteUid, reason: $reason');
            if (currentCall != null) {
              final updatedCall = currentCall!.copyWith(
                state: CallState.disconnected,
              );
              updateCallState(updatedCall);
              notifyRemoteEvent(updatedCall);
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AgoraCall] onError err: $err, msg: $msg');
            notifyError('Agora error: $msg');
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('[AgoraCall] onConnectionStateChanged state: $state, reason: $reason');
          },
        ),
      );

      isInitialized = true;
      debugPrint('[AgoraCall] Initialized successfully');
    } catch (e) {
      debugPrint('[AgoraCall] Initialize failed: $e');
      notifyError('Failed to initialize: $e');
      rethrow;
    }
  }

  @override
  Future<bool> checkPermissions() async {
    try {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        return false;
      }
      
      // 对于视频通话，还需要检查摄像头权限
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('[AgoraCall] Check permissions failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return false;
      }
      
      // 对于视频通话，还需要请求摄像头权限
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('[AgoraCall] Request permissions failed: $e');
      return false;
    }
  }

  @override
  Future<String?> startCall({
    required String peerId,
    required String peerName,
    required CallType callType,
    Map<String, dynamic>? extraData,
  }) async {
    if (!isInitialized || _engine == null) {
      notifyError('Call service not initialized');
      return null;
    }

    if (currentCall != null && currentCall!.isActive) {
      notifyError('Already in a call');
      return null;
    }

    // 检查并请求权限
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      final granted = await requestPermissions();
      if (!granted) {
        notifyError('Permission denied');
        return null;
      }
    }

    try {
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      final channelName = 'call_channel_$callId';

      _currentChannel = channelName;

      final callInfo = CallInfo(
        callId: callId,
        peerId: peerId,
        peerName: peerName,
        callType: callType,
        state: CallState.calling,
        role: CallRole.caller,
        startTime: DateTime.now(),
      );
      updateCallState(callInfo);

      await _engine!.joinChannel(
        token: '',
        channelId: channelName,
        uid: 0,
        options: ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          publishCameraTrack: callType == CallType.video,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      debugPrint('[AgoraCall] Started call to $peerName ($peerId)');
      return callId;
    } catch (e) {
      debugPrint('[AgoraCall] Start call failed: $e');
      notifyError('Failed to start call: $e');
      return null;
    }
  }

  @override
  Future<void> acceptCall(String callId) async {
    if (currentCall == null || currentCall!.callId != callId) {
      notifyError('Call not found');
      return;
    }

    // 检查并请求权限
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      final granted = await requestPermissions();
      if (!granted) {
        notifyError('Permission denied');
        return;
      }
    }

    try {
      if (_currentChannel != null) {
        await _engine!.joinChannel(
          token: '',
          channelId: _currentChannel!,
          uid: 0,
          options: ChannelMediaOptions(
            autoSubscribeVideo: true,
            autoSubscribeAudio: true,
            publishCameraTrack: currentCall!.callType == CallType.video,
            publishMicrophoneTrack: true,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );

        final updatedCall = currentCall!.copyWith(
          state: CallState.connected,
        );
        updateCallState(updatedCall);
      }
    } catch (e) {
      debugPrint('[AgoraCall] Accept call failed: $e');
      notifyError('Failed to accept call: $e');
    }
  }

  @override
  Future<void> rejectCall(String callId) async {
    if (currentCall == null || currentCall!.callId != callId) {
      return;
    }

    final updatedCall = currentCall!.copyWith(
      state: CallState.disconnected,
    );
    updateCallState(updatedCall);
    _currentChannel = null;
  }

  @override
  Future<void> endCall(String callId) async {
    try {
      if (_engine != null && _currentChannel != null) {
        await _engine!.leaveChannel();
      }

      if (currentCall != null) {
        final duration = DateTime.now().difference(currentCall!.startTime);
        final updatedCall = currentCall!.copyWith(
          state: CallState.disconnected,
          duration: duration,
        );
        updateCallState(updatedCall);
      }

      _currentChannel = null;
      debugPrint('[AgoraCall] Call ended');
    } catch (e) {
      debugPrint('[AgoraCall] End call failed: $e');
      notifyError('Failed to end call: $e');
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_engine == null) return;

    try {
      await _engine!.switchCamera();
      debugPrint('[AgoraCall] Camera switched');
    } catch (e) {
      debugPrint('[AgoraCall] Switch camera failed: $e');
    }
  }

  @override
  Future<void> toggleMute(bool mute) async {
    if (_engine == null) return;

    try {
      await _engine!.muteLocalAudioStream(mute);
      debugPrint('[AgoraCall] Audio muted: $mute');
    } catch (e) {
      debugPrint('[AgoraCall] Toggle mute failed: $e');
    }
  }

  @override
  Future<void> toggleSpeaker(bool enable) async {
    if (_engine == null) return;

    try {
      await _engine!.setEnableSpeakerphone(enable);
      _isSpeakerOn = enable;
      debugPrint('[AgoraCall] Speaker enabled: $enable');
    } catch (e) {
      debugPrint('[AgoraCall] Toggle speaker failed: $e');
    }
  }

  @override
  Future<void> switchCallType(CallType callType) async {
    if (currentCall == null || _engine == null) return;

    try {
      if (callType == CallType.video) {
        await _engine!.enableVideo();
        await _engine!.muteLocalVideoStream(false);
      } else {
        await _engine!.muteLocalVideoStream(true);
      }

      final updatedCall = currentCall!.copyWith(
        callType: callType,
      );
      updateCallState(updatedCall);
      debugPrint('[AgoraCall] Switched to ${callType == CallType.video ? "video" : "voice"} call');
    } catch (e) {
      debugPrint('[AgoraCall] Switch call type failed: $e');
    }
  }

  @override
  void dispose() {
    _engine?.release();
    _engine = null;
    isInitialized = false;
    super.dispose();
    debugPrint('[AgoraCall] Disposed');
  }
}

CallService createAgoraCallService() => AgoraCallService();
