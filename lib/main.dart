import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_bridge.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(DoorbellApp(prefs: prefs));
}

class DoorbellApp extends StatelessWidget {
  const DoorbellApp({super.key, required this.prefs, this.bridge});
  final SharedPreferences prefs;
  final NativeBridge? bridge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eternal Now Doorbell',
      debugShowCheckedModeBanner: false,
      theme: stillwaterTheme(),
      home: HomePage(prefs: prefs, bridge: bridge ?? NativeBridge.instance),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.prefs, required this.bridge});
  final SharedPreferences prefs;
  final NativeBridge bridge;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _kInterval = 'intervalMinutes';
  static const _kRandom = 'randomIntervals';
  static const _kRunning = 'wasRunning';
  static const randomMin = 5, randomMax = 30;

  final _player = AudioPlayer();
  final _rng = Random();
  Timer? _ticker;

  late int _intervalMinutes;
  late bool _random;
  bool _running = false;
  bool _quiet = false; // meeting mode: visual only
  bool _launchAtLogin = false;
  DateTime? _nextRingAt;
  int _thisIntervalMinutes = 0;

  NativeBridge get _bridge => widget.bridge;
  SharedPreferences get _prefs => widget.prefs;

  @override
  void initState() {
    super.initState();
    _intervalMinutes = _prefs.getInt(_kInterval) ?? 20;
    _random = _prefs.getBool(_kRandom) ?? false;
    _player.setSource(AssetSource('sounds/bell.mp3'));
    _player.setVolume(0.7);

    _bridge.onMicrophoneChanged = (inUse) => setState(() => _quiet = inUse);
    _bridge.onLaunchAtLoginChanged =
        (on) => setState(() => _launchAtLogin = on);
    _bridge.onMenuAction = (action) {
      if (action == 'toggle') _toggle();
      if (action == 'ringNow') _ring();
    };

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final inUse = await _bridge.microphoneInUse();
    final atLogin = await _bridge.launchAtLogin();
    if (!mounted) return;
    setState(() {
      _quiet = inUse;
      _launchAtLogin = atLogin;
    });
    await _bridge.startMicrophoneMonitoring();

    // AIDEV-NOTE: if the bell was running when the app last quit (e.g. a
    // restart with launch-at-login on), resume quietly in the menu bar.
    if (_prefs.getBool(_kRunning) ?? false) {
      _start();
      await _bridge.hideWindow();
    } else {
      _pushStatus();
    }
  }

  // ── Timer ────────────────────────────────────────────────────────────────

  void _toggle() => _running ? _stop() : _start();

  void _start() {
    _scheduleNext();
    setState(() => _running = true);
    _prefs.setBool(_kRunning, true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _pushStatus();
  }

  void _stop() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _nextRingAt = null;
    });
    _prefs.setBool(_kRunning, false);
    _pushStatus();
  }

  void _scheduleNext() {
    _thisIntervalMinutes = _random
        ? randomMin + _rng.nextInt(randomMax - randomMin + 1)
        : _intervalMinutes;
    _nextRingAt = DateTime.now().add(Duration(minutes: _thisIntervalMinutes));
  }

  // Wall-clock based, so a sleeping Mac rings once on wake instead of drifting.
  void _tick() {
    if (!_running || _nextRingAt == null) return;
    if (!DateTime.now().isBefore(_nextRingAt!)) {
      _ring();
      _scheduleNext();
    }
    setState(() {});
    _pushStatus();
  }

  int get _remainingSeconds {
    if (_nextRingAt == null) return _intervalMinutes * 60;
    final ms = _nextRingAt!.difference(DateTime.now()).inMilliseconds;
    return max(0, (ms / 1000).ceil());
  }

  void _pushStatus() => _bridge.updateStatus(
      running: _running, remainingSeconds: _remainingSeconds);

  Future<void> _ring() async {
    _bridge.showFlash(color: Still.flashHex);
    if (!_quiet) {
      await _player.stop();
      await _player.resume();
    }
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  void _setInterval(int minutes) {
    setState(() => _intervalMinutes = minutes);
    _prefs.setInt(_kInterval, minutes);
    if (_running && !_random) _scheduleNext();
  }

  void _setRandom(bool on) {
    setState(() => _random = on);
    _prefs.setBool(_kRandom, on);
    if (_running) _scheduleNext();
  }

  Future<void> _setLaunchAtLogin(bool on) async {
    final result = await _bridge.setLaunchAtLogin(on);
    if (mounted) setState(() => _launchAtLogin = result);
  }

  @override
  void dispose() {
    _bridge.stopMicrophoneMonitoring();
    _ticker?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  String get _cadence => _random
      ? 'Random, $randomMin–$randomMax minutes'
      : 'Every $_intervalMinutes minute${_intervalMinutes == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scrolls only if the window is shorter than the content.
      body: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(child: _content()),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Padding(
      // Top padding clears the transparent title bar's traffic lights.
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            RippleMark(size: 34),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Eternal Now',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Still.ink)),
              Text('Doorbell',
                  style: TextStyle(fontSize: 14, color: Still.muted)),
            ]),
          ]),
          const SizedBox(height: 24),
          _statusPanel(),
          const SizedBox(height: 12),
          SettingRow(
            title: 'Interval',
            enabled: !_random,
            trailing:
                MinuteStepper(value: _intervalMinutes, onChanged: _setInterval),
          ),
          const Divider(),
          SettingRow(
            title: 'Random intervals',
            subtitle: 'Between $randomMin and $randomMax minutes',
            trailing: Switch(value: _random, onChanged: _setRandom),
          ),
          const Divider(),
          SettingRow(
            title: 'Meeting mode',
            subtitle: 'Flash only, on while your mic is in use',
            trailing: Switch(
                value: _quiet, onChanged: (v) => setState(() => _quiet = v)),
          ),
          const Divider(),
          SettingRow(
            title: 'Open at login',
            subtitle: 'Lives in the menu bar',
            trailing:
                Switch(value: _launchAtLogin, onChanged: _setLaunchAtLogin),
          ),
          const Spacer(),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _toggle,
                style: FilledButton.styleFrom(
                  backgroundColor: Still.sage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_running ? 'Pause' : 'Start',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _ring,
              style: OutlinedButton.styleFrom(
                foregroundColor: Still.sage,
                side: const BorderSide(color: Still.lichen),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ring now', style: TextStyle(fontSize: 16)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statusPanel() {
    final detail = _running && _random
        ? 'Random interval, this one is $_thisIntervalMinutes min'
        : _cadence;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Still.fog,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_running ? 'Next bell' : 'Paused',
              style: const TextStyle(fontSize: 14, color: Still.muted)),
          const Spacer(),
          if (_quiet)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Still.line),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_off_outlined, size: 14, color: Still.sage),
                SizedBox(width: 4),
                Text('Meeting mode',
                    style: TextStyle(fontSize: 13, color: Still.sage)),
              ]),
            ),
        ]),
        const SizedBox(height: 2),
        Text(
          _running
              ? _clock(_remainingSeconds)
              : (_random ? '—' : _clock(_intervalMinutes * 60)),
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w300,
            height: 1.15,
            color: _running ? Still.ink : Still.lichen,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(detail, style: const TextStyle(fontSize: 14, color: Still.muted)),
      ]),
    );
  }
}
