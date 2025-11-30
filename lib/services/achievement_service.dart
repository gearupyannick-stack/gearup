import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_learning_app/widgets/achievement_unlocked_dialog.dart';
import 'package:easy_localization/easy_localization.dart';

class AchievementService {
  // Singleton pattern
  AchievementService._privateConstructor();
  static final AchievementService instance = AchievementService._privateConstructor();

  final Map<String, List<String>> _achievementMap = {
      'achievements.categories.trackProgression': [
        'achievements.list.firstFlag',
        'achievements.list.levelComplete',
        'achievements.list.midTrackMilestone',
        'achievements.list.trackConqueror',
      ],
      'achievements.categories.perfectRuns': [
        'achievements.list.cleanSlate',
        'achievements.list.zeroLifeLoss',
        'achievements.list.swiftRacer',
      ],
      'achievements.categories.gearMastery': [
        'achievements.list.gearRookie',
        'achievements.list.gearGrinder',
        'achievements.list.gearTycoon',
      ],
      'achievements.categories.gateTrackUnlocks': [
        'achievements.list.gateOpener',
        'achievements.list.trackUnlockerI',
        'achievements.list.trackUnlockerII',
      ],
      'achievements.categories.comebackCorrection': [
        'achievements.list.secondChance',
        'achievements.list.perseverance',
      ],
      'achievements.categories.trainingAchievements': [
        'achievements.list.trainingInitiate',
        'achievements.list.trainingRegular',
        'achievements.list.trainingVeteran',
        'achievements.list.quizStreak',
        'achievements.list.sharpshooter',
        'achievements.list.allRounder',
        'achievements.list.trainingAllStar',
      ],
      'achievements.categories.clubMilestones': [
        'achievements.list.clubFounder',
        'achievements.list.clubGrowing',
        'achievements.list.clubThriving',
        'achievements.list.raceOrganizer',
        'achievements.list.raceEnthusiast',
        'achievements.list.raceLegend',
        'achievements.list.pointCollector',
        'achievements.list.pointAccumulator',
        'achievements.list.pointTycoon',
        'achievements.list.socialButterfly',
        'achievements.list.teamPlayer',
      ],
    };


  String _getAchievementIdFromName(String name) {
    // Split on en-dash/em-dash (separators), NOT ascii hyphen (part of name)
    final base = name.split(RegExp(r"\s*[–—]\s*"))[0];
    return base.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }

  String getDisplayNameFromId(String id) {
    for (final category in _achievementMap.values) {
      for (final nameKey in category) {
        final fullName = nameKey.tr();
        final currentId = _getAchievementIdFromName(fullName);
        if (currentId == id) {
          // Split on en-dash/em-dash (separators), NOT ascii hyphen
          return fullName.split(RegExp(r"\s*[–—]\s*"))[0].trim();
        }
      }
    }
    return id;
  }

  Future<void> unlockAchievement(BuildContext context, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlockedAchievements') ?? [];

    if (!unlocked.contains(id)) {
      unlocked.add(id);
      await prefs.setStringList('unlockedAchievements', unlocked);

      final title = getDisplayNameFromId(id);

      // Ensure the context is still valid before showing a dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AchievementUnlockedDialog(
            title: title,
            achievementId: id,
          ),
        );
      }
    }
  }
}
