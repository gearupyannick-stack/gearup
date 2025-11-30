import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:car_learning_app/services/achievement_service.dart';

/// Service to track club-related activities and unlock milestone achievements
class ClubActivityService {
  ClubActivityService._privateConstructor();
  static final ClubActivityService instance = ClubActivityService._privateConstructor();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Shared Preferences Keys
  static const String _clubsCreatedKey = 'clubs_created_count';
  static const String _clubRacesHostedKey = 'club_races_hosted_count';
  static const String _clubRacesParticipatedKey = 'club_races_participated_count';
  static const String _clubPointsEarnedKey = 'club_points_earned';
  static const String _clubMessagesSentKey = 'club_messages_sent_count';

  /// Track when a user creates a club
  Future<void> trackClubCreated(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_clubsCreatedKey) ?? 0) + 1;
    await prefs.setInt(_clubsCreatedKey, count);

    // Unlock "Club Founder" achievement
    if (count >= 1) {
      await AchievementService.instance.unlockAchievement(context, 'club_founder');
    }
  }

  /// Track when members join the club and check for growth milestones
  Future<void> checkClubMembershipMilestones(BuildContext context, String clubId) async {
    try {
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return;

      final memberCount = clubDoc.data()?['memberCount'] ?? 0;

      // Unlock milestones based on member count
      if (memberCount >= 10) {
        await AchievementService.instance.unlockAchievement(context, 'club_growing');
      }
      if (memberCount >= 25) {
        await AchievementService.instance.unlockAchievement(context, 'club_thriving');
      }
    } catch (e) {
      debugPrint('Error checking club membership milestones: $e');
    }
  }

  /// Track when user hosts a club race
  Future<void> trackRaceHosted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_clubRacesHostedKey) ?? 0) + 1;
    await prefs.setInt(_clubRacesHostedKey, count);

    // Unlock race hosting milestones
    if (count >= 10) {
      await AchievementService.instance.unlockAchievement(context, 'race_organizer');
    }
    if (count >= 50) {
      await AchievementService.instance.unlockAchievement(context, 'race_enthusiast');
    }
    if (count >= 100) {
      await AchievementService.instance.unlockAchievement(context, 'race_legend');
    }
  }

  /// Track when user participates in a club race
  Future<void> trackRaceParticipation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_clubRacesParticipatedKey) ?? 0) + 1;
    await prefs.setInt(_clubRacesParticipatedKey, count);

    // Unlock "Team Player" achievement
    if (count >= 25) {
      await AchievementService.instance.unlockAchievement(context, 'team_player');
    }
  }

  /// Track club points earned and unlock point milestones
  Future<void> trackPointsEarned(BuildContext context, int points) async {
    final prefs = await SharedPreferences.getInstance();
    final totalPoints = (prefs.getInt(_clubPointsEarnedKey) ?? 0) + points;
    await prefs.setInt(_clubPointsEarnedKey, totalPoints);

    // Unlock point collection milestones
    if (totalPoints >= 100) {
      await AchievementService.instance.unlockAchievement(context, 'point_collector');
    }
    if (totalPoints >= 1000) {
      await AchievementService.instance.unlockAchievement(context, 'point_accumulator');
    }
    if (totalPoints >= 5000) {
      await AchievementService.instance.unlockAchievement(context, 'point_tycoon');
    }
  }

  /// Track messages sent in club chat
  Future<void> trackMessageSent(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_clubMessagesSentKey) ?? 0) + 1;
    await prefs.setInt(_clubMessagesSentKey, count);

    // Unlock "Social Butterfly" achievement
    if (count >= 100) {
      await AchievementService.instance.unlockAchievement(context, 'social_butterfly');
    }
  }

  /// Get current stats for display purposes
  Future<Map<String, int>> getClubStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'clubsCreated': prefs.getInt(_clubsCreatedKey) ?? 0,
      'racesHosted': prefs.getInt(_clubRacesHostedKey) ?? 0,
      'racesParticipated': prefs.getInt(_clubRacesParticipatedKey) ?? 0,
      'pointsEarned': prefs.getInt(_clubPointsEarnedKey) ?? 0,
      'messagesSent': prefs.getInt(_clubMessagesSentKey) ?? 0,
    };
  }

  /// Track home challenge completion (for Phase 4 activity feed)
  Future<void> trackHomeChallengeCompleted(String challengeType, int score, int total) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get all clubs the user is a member of
      final userClubsSnapshot = await _firestore
          .collection('clubs')
          .where('memberIds', arrayContains: user.uid)
          .get();

      final timestamp = FieldValue.serverTimestamp();

      // Post activity to each club's activity feed
      for (final clubDoc in userClubsSnapshot.docs) {
        await _firestore
            .collection('clubs')
            .doc(clubDoc.id)
            .collection('activityFeed')
            .add({
          'userId': user.uid,
          'userName': user.displayName ?? 'Unknown Player',
          'type': 'homeChallenge',
          'challengeType': challengeType,
          'score': score,
          'total': total,
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      debugPrint('Error tracking home challenge: $e');
    }
  }

  /// Track public race completion (for Phase 4 activity feed)
  Future<void> trackPublicRaceCompleted(int placement, int totalPlayers) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userClubsSnapshot = await _firestore
          .collection('clubs')
          .where('memberIds', arrayContains: user.uid)
          .get();

      final timestamp = FieldValue.serverTimestamp();

      for (final clubDoc in userClubsSnapshot.docs) {
        await _firestore
            .collection('clubs')
            .doc(clubDoc.id)
            .collection('activityFeed')
            .add({
          'userId': user.uid,
          'userName': user.displayName ?? 'Unknown Player',
          'type': 'publicRace',
          'placement': placement,
          'totalPlayers': totalPlayers,
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      debugPrint('Error tracking public race: $e');
    }
  }

  /// Track milestone achievements (for Phase 4 activity feed)
  Future<void> trackMilestoneAchieved(String achievementId, String achievementName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userClubsSnapshot = await _firestore
          .collection('clubs')
          .where('memberIds', arrayContains: user.uid)
          .get();

      final timestamp = FieldValue.serverTimestamp();

      for (final clubDoc in userClubsSnapshot.docs) {
        await _firestore
            .collection('clubs')
            .doc(clubDoc.id)
            .collection('activityFeed')
            .add({
          'userId': user.uid,
          'userName': user.displayName ?? 'Unknown Player',
          'type': 'milestone',
          'achievementId': achievementId,
          'achievementName': achievementName,
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      debugPrint('Error tracking milestone: $e');
    }
  }

  /// Get activity feed for a specific club (for Stats tab display)
  Stream<List<Map<String, dynamic>>> getClubActivityFeed(String clubId, {int limit = 50}) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('activityFeed')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}
