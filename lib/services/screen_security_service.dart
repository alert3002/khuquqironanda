import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

/// Матни огоҳӣ ҳангоми скриншот / сабт / суратгирӣ.
const String kScreenshotBlockedMessage =
    'Муштари мухтарам дар ин барнома скриншот ё сурат гирифтан манъ аст!';

/// Ҳимояи экран: скриншот манъ, ҳангоми кӯшиш/сабт — overlay бо матн.
class ScreenSecurityService {
  ScreenSecurityService._();
  static final ScreenSecurityService instance = ScreenSecurityService._();

  static const _channel = MethodChannel('com.khuquqironanda.week/screen_security');

  final ValueNotifier<bool> captureBlockedVisible = ValueNotifier<bool>(false);

  Timer? _hideTimer;
  Timer? _recordPoll;
  bool _started = false;
  bool _stickyRecording = false;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;

    try {
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
        await ScreenProtector.preventScreenshotOn();
        await _channel.invokeMethod<void>('enableSecureFlag');
        _channel.setMethodCallHandler(_onNativeCall);
      } else if (Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithBlur();
        ScreenProtector.addListener(
          () => showBlockedOverlay(),
          (isRecording) {
            if (isRecording) {
              showBlockedOverlay(sticky: true);
            } else {
              _stickyRecording = false;
              hideBlockedOverlay();
            }
          },
        );
        _recordPoll = Timer.periodic(const Duration(seconds: 1), (_) async {
          try {
            final recording = await ScreenProtector.isRecording();
            if (recording) {
              showBlockedOverlay(sticky: true);
            } else if (_stickyRecording) {
              _stickyRecording = false;
              hideBlockedOverlay();
            }
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('ScreenSecurityService.start error: $e');
    }
  }

  Future<void> stop() async {
    _hideTimer?.cancel();
    _recordPoll?.cancel();
    _recordPoll = null;
    _stickyRecording = false;
    try {
      ScreenProtector.removeListener();
      await ScreenProtector.preventScreenshotOff();
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOff();
        await _channel.invokeMethod<void>('disableSecureFlag');
      } else if (Platform.isIOS) {
        await ScreenProtector.protectDataLeakageWithBlurOff();
      }
    } catch (_) {}
    _started = false;
    captureBlockedVisible.value = false;
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onScreenCaptureAttempt') {
      showBlockedOverlay();
    }
  }

  void showBlockedOverlay({bool sticky = false}) {
    if (sticky) _stickyRecording = true;
    captureBlockedVisible.value = true;
    _hideTimer?.cancel();
    if (!sticky && !_stickyRecording) {
      _hideTimer = Timer(const Duration(seconds: 4), hideBlockedOverlay);
    }
  }

  void hideBlockedOverlay() {
    if (_stickyRecording) return;
    _hideTimer?.cancel();
    captureBlockedVisible.value = false;
  }
}

/// Overlay: экран хира/шаффоф + матн.
class ScreenCaptureGuard extends StatefulWidget {
  final Widget child;

  const ScreenCaptureGuard({super.key, required this.child});

  @override
  State<ScreenCaptureGuard> createState() => _ScreenCaptureGuardState();
}

class _ScreenCaptureGuardState extends State<ScreenCaptureGuard>
    with WidgetsBindingObserver {
  final _security = ScreenSecurityService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_security.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_security.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Вақти background / recent apps — мундариҷа пӯшида мешавад (leakage).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Android protectDataLeakageOn аллакай thumbnail-ро сиёҳ мекунад.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        ValueListenableBuilder<bool>(
          valueListenable: _security.captureBlockedVisible,
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            return const _CaptureBlockedOverlay();
          },
        ),
      ],
    );
  }
}

class _CaptureBlockedOverlay extends StatelessWidget {
  const _CaptureBlockedOverlay();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AbsorbPointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.no_photography_outlined,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      kScreenshotBlockedMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.98),
                        fontSize: 17,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
