import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/services/database_service.dart';

enum TimerState { idle, running, paused, finished }

class RestTimerService extends ChangeNotifier {
  // Singleton Pattern pentru a-l accesa ușor de oriunde
  static final RestTimerService _instance = RestTimerService._internal();
  factory RestTimerService() => _instance;
  RestTimerService._internal() {
    _initAudioContext();
  }

  Timer? _timer;
  int _durationInSeconds = 90; // Valoarea implicită (1:30)
  int _remainingSeconds = 0;
  TimerState _state = TimerState.idle;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Gettere pentru UI
  int get remainingSeconds => _remainingSeconds;
  int get durationInSeconds => _durationInSeconds;
  TimerState get state => _state;
  bool get isRunning => _state == TimerState.running;

  String get formattedRemainingTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _initAudioContext() async {
    final context = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: {
          AVAudioSessionOptions.duckOthers,
        },
      ),
      android: AudioContextAndroid(
        audioMode: AndroidAudioMode.normal,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notification,
      ),
    );

    try {
      await AudioPlayer.global.setAudioContext(context); // 🆕 global
      await _audioPlayer.setAudioContext(context); // instanța ta
    } catch (e) {
      debugPrint("Eroare la configurarea AudioContext: $e");
    }
  }

  void startTimer({int? seconds}) {
    if (seconds != null) {
      _durationInSeconds = seconds;
    }
    _remainingSeconds = _durationInSeconds;
    _state = TimerState.running;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _onTimerFinished();
      }
    });
    notifyListeners();
  }

  void pauseTimer() {
    if (_state == TimerState.running) {
      _timer?.cancel();
      _state = TimerState.paused;
      notifyListeners();
    }
  }

  void resumeTimer() {
    if (_state == TimerState.paused) {
      _state = TimerState.running;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          notifyListeners();
        } else {
          _onTimerFinished();
        }
      });
      notifyListeners();
    }
  }

  void stopTimer() {
    _timer?.cancel();
    _state = TimerState.idle;
    _remainingSeconds = 0;
    notifyListeners();
  }

  void addTime(int seconds) {
    if (_state == TimerState.running || _state == TimerState.paused) {
      _remainingSeconds += seconds;
      notifyListeners();
    }
  }

  void subtractTime(int seconds) {
    if (_state == TimerState.running || _state == TimerState.paused) {
      _remainingSeconds = (_remainingSeconds - seconds).clamp(0, double.infinity).toInt();
      if (_remainingSeconds == 0) {
        _onTimerFinished();
      } else {
        notifyListeners();
      }
    }
  }

  void _onTimerFinished() async {
    _timer?.cancel();
    _state = TimerState.finished;
    _remainingSeconds = 0;
    notifyListeners();

    final settings = DatabaseService.appSettings;

    // Feedback haptic (vibrează telefonul când se termină pauza)

    final bool enableHaptics = settings?.enableHapticFeedback ?? true;
    if (enableHaptics) {
      HapticFeedback.vibrate();
      Future.delayed(const Duration(milliseconds: 300), () => HapticFeedback.vibrate());
    }

    // TODO: Testat: Aici putem adăuga un sunet discret sau o notificare locală
    final bool enableSound = settings?.enableSoundEffects ?? true;
    if (enableSound) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(0.3);
        await _audioPlayer.play(AssetSource('sounds/timer_finished.wav'));
      } catch (e) {
        debugPrint("Eroare la redarea sunetului de timer: $e");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
