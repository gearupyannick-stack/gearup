import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class AchievementUnlockedDialog extends StatelessWidget {
  final String title;
  final String achievementId;

  const AchievementUnlockedDialog({
    Key? key,
    required this.title,
    required this.achievementId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "ACHIEVEMENT UNLOCKED!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String?>(
            future: _resolveAchievementAsset(achievementId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(width: 80, height: 80, child: Center(child: CircularProgressIndicator()));
              }
              final path = snap.data;
              if (path != null) {
                return Image.asset(path, width: 80, height: 80, fit: BoxFit.contain);
              }
              return Icon(Icons.emoji_events, size: 80, color: Colors.amber);
            },
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () => Navigator.of(context).pop(),
            child: Text('AWESOME!', style: TextStyle(color: Colors.black)),
          ),
        )
      ],
    );
  }
}

/// Try common filename variants for the achievement asset (underscore <-> hyphen).
Future<String?> _resolveAchievementAsset(String achievementId) async {
  final candidates = <String>[
    'assets/achievements/$achievementId.png',
    'assets/achievements/${achievementId.replaceAll('_', '-')}.png',
    'assets/achievements/${achievementId.replaceAll('-', '_')}.png',
  ];

  for (final path in candidates) {
    try {
      await rootBundle.load(path);
      return path;
    } catch (_) {
      // ignore and try next
    }
  }
  return null;
}
