import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/animation.dart';
import 'permissions_dialog.dart';

// Import our native bridge service
import 'macos_flash_service.dart';

void main() {
  // Capture platform errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Only print to console in debug mode
    FlutterError.dumpErrorToConsole(details);
  };

  debugPrint('Main: Starting the Mindfulness Bell application');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Main: Flutter binding initialized');

  // Debug plugin registration
  _debugPluginRegistration();

  runApp(const MindfulnessApp());
}

// Debug function to check plugin registration
Future<void> _debugPluginRegistration() async {
  debugPrint('Main: Debugging plugin registration...');

  // Check for platform channels
  try {
    // Check if our channel exists by trying to ping it
    const channelName = 'com.mindfulnessbell/overlay';
    const channel = MethodChannel(channelName);

    debugPrint('Main: Testing if channel $channelName is responsive...');

    try {
      await channel.invokeMethod<bool>('ping').timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          debugPrint(
              'Main: Channel ping timed out - plugin might not be registered');
          return false;
        },
      );
    } on MissingPluginException catch (e) {
      debugPrint('Main: Channel does not exist: ${e.message}');
      debugPrint('Main: This suggests the plugin is not properly registered');
    } on PlatformException catch (e) {
      // This is actually good - means the channel exists but doesn't have ping
      debugPrint(
          'Main: Channel exists but ping method not implemented: ${e.message}');
      debugPrint(
          'Main: This suggests the plugin is registered but ping is not implemented');
    } catch (e) {
      debugPrint('Main: Unexpected error pinging channel: $e');
    }
  } catch (e) {
    debugPrint('Main: Error while debugging plugin registration: $e');
  }
}

class MindfulnessApp extends StatelessWidget {
  const MindfulnessApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );

    return MaterialApp(
      title: 'Mindfulness Bell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        fontFamily: 'Quicksand',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _intervalController = TextEditingController();
  bool _isRunning = false;
  bool _useRandomIntervals = false;
  bool _inMeetingMode = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentIntervalMinutes = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  bool _isFlashing = false;
  final MacOSFlashService _flashService = MacOSFlashService();
  bool _hasRequestedPermissions = false;
  bool _permissionsDialogShown = false;

  // Add debug method to check channel availability
  Future<void> _debugCheckChannelAvailability() async {
    const channel = MethodChannel('com.mindfulnessbell/overlay');
    try {
      debugPrint('HomePage: Checking if channel is available using ping...');
      await channel.invokeMethod<bool>('ping').timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          debugPrint(
              'HomePage: Channel ping timed out, suggesting the plugin is not registered');
          return false;
        },
      );
    } on MissingPluginException catch (e) {
      debugPrint('HomePage: Channel does not have handler registered: $e');
    } on PlatformException catch (e) {
      // This is actually good - it means the channel exists but doesn't handle 'ping'
      debugPrint(
          'HomePage: Channel exists but method ping not implemented: ${e.message}');
      debugPrint(
          'HomePage: This suggests the plugin is registered but ping method not implemented');
    } catch (e) {
      debugPrint('HomePage: Unexpected error checking channel: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('HomePage: initState called');
    _loadAudio();
    _setupFlashAnimation();
    _setupMicrophoneMonitoring();

    // Debug check channel availability
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('HomePage: Post frame callback triggered');
      _debugCheckChannelAvailability();

      // Removed automatic permission request on startup
      // _requestPermissionsIfNeeded();
    });
  }

  Future<void> _requestPermissionsIfNeeded() async {
    debugPrint(
        'HomePage: _requestPermissionsIfNeeded called, hasRequested=${_hasRequestedPermissions}');
    if (!_hasRequestedPermissions) {
      try {
        debugPrint(
            'HomePage: About to call _flashService.requestPermissions()');
        await _flashService.requestPermissions();
        debugPrint('HomePage: Successfully returned from requestPermissions()');
        _hasRequestedPermissions = true;
      } catch (e) {
        debugPrint('HomePage: Error requesting permissions: $e');
        if (e is MissingPluginException) {
          debugPrint(
              'HomePage: MissingPluginException detected - this suggests the native plugin is not properly registered');
        } else if (e is PlatformException) {
          final platformException = e as PlatformException;
          debugPrint(
              'HomePage: PlatformException details - code: ${platformException.code}, message: ${platformException.message}, details: ${platformException.details}');
        }
      }
    }
  }

  void _setupFlashAnimation() {
    _flashController = AnimationController(
      duration: const Duration(
          milliseconds:
              6000), // Total animation duration: 1s fade in + 5s fade out
      vsync: this,
    );

    // Create a curved animation that rises quickly and falls slowly
    _flashAnimation = TweenSequence<double>([
      // Fade in over 1 second (1/6 of total duration)
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 0.5)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      // Fade out over 5 seconds (5/6 of total duration)
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.5, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
    ]).animate(_flashController)
      ..addListener(() {
        setState(() {
          // The animation value has changed, rebuild the widget
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isFlashing = false;
          });
        }
      });
  }

  Future<void> _loadAudio() async {
    await _audioPlayer.setSource(AssetSource('sounds/bell.mp3'));
    await _audioPlayer.setVolume(0.7);
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_useRandomIntervals ||
        (_intervalController.text.isNotEmpty &&
            int.tryParse(_intervalController.text) != null)) {
      setState(() {
        _isRunning = true;
        if (_useRandomIntervals) {
          _currentIntervalMinutes = _getRandomInterval();
        } else {
          _currentIntervalMinutes = int.parse(_intervalController.text);
        }
        _remainingSeconds = _currentIntervalMinutes * 60;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds <= 0) {
            _playBellSound();
            if (_useRandomIntervals) {
              _currentIntervalMinutes = _getRandomInterval();
              _remainingSeconds = _currentIntervalMinutes * 60;
            } else {
              _remainingSeconds = _currentIntervalMinutes * 60;
            }
          } else {
            _remainingSeconds--;
          }
        });
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  int _getRandomInterval() {
    // Generate random interval between 5 and 30 minutes
    return Random().nextInt(26) + 5;
  }

  Future<void> _playBellSound() async {
    if (!_inMeetingMode) {
      await _audioPlayer.resume();
    }
    _triggerVisualFlash();
  }

  void _triggerVisualFlash() {
    setState(() {
      _isFlashing = true;
    });
    _flashController.reset();
    _flashController.forward();

    // Also trigger the system-wide flash overlay
    debugPrint('HomePage: About to call _flashService.showFlash()');
    debugPrint(
        'HomePage: Current platform: ${defaultTargetPlatform.toString()}');

    // Check if we're using the correct channel
    const channelName = 'com.mindfulnessbell/overlay';
    debugPrint('HomePage: Channel name being used: $channelName');

    // Check if the plugin appears to be registered
    const methodChannel = MethodChannel(channelName);

    // Try a ping first
    methodChannel.invokeMethod<bool>('ping').then((result) {
      debugPrint('HomePage: Plugin ping successful: $result');
    }).catchError((e) {
      if (e is MissingPluginException) {
        debugPrint(
            'HomePage: Plugin ping failed - MissingPluginException: ${e.message}');
        debugPrint(
            'HomePage: This suggests the native plugin is not registered properly');
      } else {
        debugPrint('HomePage: Plugin ping failed with other error: $e');
      }
    });

    // Create a color that matches our app's gradient
    // Use a color between soft peach (0xFFF8D6B3) and warm amber (0xFFE8A87C)
    // with 60% opacity for a subtle effect
    final String gradientColor = '#F8D6B399'; // Soft peach with 60% opacity

    // Now try the actual flash
    _flashService
        .showFlash(
      duration: 6.0, // 6 seconds duration (1s fade in + 5s fade out)
      color: gradientColor,
    )
        .then((_) {
      debugPrint('HomePage: Successfully returned from showFlash()');
    }).catchError((e) {
      debugPrint('HomePage: Error in showFlash: $e');
      if (e is MissingPluginException) {
        debugPrint(
            'HomePage: MissingPluginException in showFlash - native plugin not registered');
      }
    });
  }

  // Setup microphone monitoring
  void _setupMicrophoneMonitoring() {
    debugPrint('HomePage: Setting up microphone monitoring');

    // Set up callback for microphone status changes
    _flashService.onMicrophoneStatusChanged = (isInUse) {
      debugPrint('HomePage: Microphone status changed to: $isInUse');

      // Automatically enable meeting mode when microphone is in use
      if (isInUse != _inMeetingMode) {
        setState(() {
          _inMeetingMode = isInUse;
          debugPrint(
              'HomePage: Automatically ${isInUse ? "enabled" : "disabled"} meeting mode');
        });
      }
    };

    // Start monitoring after a short delay to let the app initialize
    Future.delayed(const Duration(seconds: 1), () async {
      // Get initial microphone status
      try {
        final initialStatus = await _flashService.getMicrophoneStatus();
        debugPrint('HomePage: Initial microphone status: $initialStatus');

        // Set initial meeting mode based on microphone status
        if (initialStatus != _inMeetingMode) {
          setState(() {
            _inMeetingMode = initialStatus;
            if (initialStatus) {
              debugPrint(
                  'HomePage: Initially enabling meeting mode due to active microphone');
            }
          });
        }

        // Start continuous monitoring
        final started = await _flashService.startMicrophoneMonitoring();
        debugPrint('HomePage: Microphone monitoring started: $started');
      } catch (e) {
        debugPrint('HomePage: Error setting up microphone monitoring: $e');
      }
    });
  }

  @override
  void dispose() {
    // Stop microphone monitoring when app is closed
    _flashService.stopMicrophoneMonitoring();
    _timer?.cancel();
    _intervalController.dispose();
    _audioPlayer.dispose();
    _flashController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showPermissionsDialog() {
    debugPrint(
        'HomePage: _showPermissionsDialog called, dialogShown=${_permissionsDialogShown}');
    if (_permissionsDialogShown) return;

    _permissionsDialogShown = true;
    showDialog(
      context: context,
      builder: (context) => PermissionsDialog(
        onRequestPermissions: () async {
          debugPrint(
              'HomePage: Permission dialog requestPermissions callback triggered');
          try {
            await _flashService.requestPermissions();
            debugPrint(
                'HomePage: Successfully returned from dialog-triggered requestPermissions()');
            _hasRequestedPermissions = true;
          } catch (e) {
            debugPrint(
                'HomePage: Error in dialog-triggered requestPermissions: $e');
            if (e is MissingPluginException) {
              debugPrint(
                  'HomePage: MissingPluginException in dialog - native plugin not registered');
            }
          }
          _permissionsDialogShown = false;
        },
      ),
    ).then((_) {
      debugPrint('HomePage: Permission dialog closed');
      _permissionsDialogShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Warm gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8D6B3), // Soft peach
                  Color(0xFFE8A87C), // Warm amber
                ],
              ),
            ),
          ),

          // Noise overlay
          Opacity(
            opacity: 0.05,
            child: Image.asset(
              'assets/images/noise_texture.png',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Main content
          SafeArea(
            child: _isRunning ? _buildRunningScreen() : _buildSetupScreen(),
          ),

          // Visual flash overlay
          if (_isFlashing)
            Positioned.fill(
              child: Opacity(
                opacity: _flashAnimation.value,
                child: Container(
                  color: const Color(
                      0xFFF8D6B3), // Match the soft peach color from the gradient
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Mindfulness Bell',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 50),

            // Interval input field
            if (!_useRandomIntervals)
              TextField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Interval (minutes)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.9),
                ),
                style: const TextStyle(fontSize: 18),
              ),

            const SizedBox(height: 20),

            // Random intervals checkbox
            InkWell(
              onTap: () {
                setState(() {
                  _useRandomIntervals = !_useRandomIntervals;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: _useRandomIntervals,
                      onChanged: (value) {
                        setState(() {
                          _useRandomIntervals = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      'Use random intervals (5-30 minutes)',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Meeting mode checkbox
            InkWell(
              onTap: () {
                setState(() {
                  _inMeetingMode = !_inMeetingMode;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: _inMeetingMode,
                      onChanged: (value) {
                        setState(() {
                          _inMeetingMode = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      'Meeting Mode (visual only, no sound)',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            TextButton.icon(
              onPressed: _showPermissionsDialog,
              icon: const Icon(Icons.security, color: Color(0xFF5D4037)),
              label: const Text(
                'Enable Full Screen Flash',
                style: TextStyle(color: Color(0xFF5D4037)),
              ),
            ),

            const SizedBox(height: 50),

            // Start button
            ElevatedButton(
              onPressed: _toggleTimer,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: const Color(0xFF795548),
              ),
              child: const Text(
                'Start',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunningScreen() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Mindfulness Bell',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),

              const SizedBox(height: 20),

              // Current interval display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      _useRandomIntervals
                          ? 'Random Interval: $_currentIntervalMinutes minutes'
                          : 'Interval: $_currentIntervalMinutes minutes',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    if (_inMeetingMode)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic_off,
                                    size: 16, color: Color(0xFF5D4037)),
                                SizedBox(width: 4),
                                Text(
                                  'Meeting Mode',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "I've muted the mic because you're in a meeting",
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF5D4037),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Stop button
              ElevatedButton(
                onPressed: _toggleTimer,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: const Color(0xFF8D6E63),
                ),
                child: const Text(
                  'Stop',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Meeting mode toggle in bottom right corner
        Positioned(
          bottom: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _inMeetingMode = !_inMeetingMode;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _inMeetingMode
                        ? const Color(0xFF5D4037)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _inMeetingMode,
                        onChanged: (value) {
                          setState(() {
                            _inMeetingMode = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Meeting Mode',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5D4037),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.mic_off,
                      size: 16,
                      color: Color(0xFF5D4037),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
