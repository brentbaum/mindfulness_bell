import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class PermissionsDialog extends StatelessWidget {
  final VoidCallback onRequestPermissions;

  const PermissionsDialog({
    Key? key,
    required this.onRequestPermissions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isMacOS = Platform.isMacOS;
    final String settingsName =
        isMacOS ? 'System Settings' : 'System Preferences';

    return AlertDialog(
      title: const Text('Enable Full Screen Flash'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'For the mindfulness bell to flash visibly while you\'re using other apps, we need accessibility permissions.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'You\'ll need to:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('1. Click "Open $settingsName" below'),
          const Text('2. Click the lock icon to make changes'),
          const Text('3. Check the box next to "Mindfulness Bell"'),
          const Text('4. Close Settings and return here'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'If the app doesn\'t appear in the list, try restarting the app after granting permissions.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () {
            onRequestPermissions();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF795548),
          ),
          child: Text(
            'Open $settingsName',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
