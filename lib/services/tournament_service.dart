import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tournament.dart';
import '../models/tournament_match.dart';
import '../models/club_member.dart';
import '../services/chat_service.dart';

class TournamentService {
  static final TournamentService instance = TournamentService._internal();
  TournamentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new tournament
  Future<String> createTournament({
    required String clubId,
    required String name,
    required TournamentFormat format,
    required int maxParticipants,
    required DateTime registrationDeadline,
    required DateTime startTime,
    required int questionsPerMatch,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final tournament = Tournament(
      tournamentId: '',
      clubId: clubId,
      name: name,
      creatorId: user.uid,
      format: format,
      status: TournamentStatus.registration,
      maxParticipants: maxParticipants,
      registrationDeadline: registrationDeadline,
      startTime: startTime,
      questionsPerMatch: questionsPerMatch,
      participantIds: [],
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .add(tournament.toFirestore());

    // Post system message to chat
    await ChatService.instance.sendSystemMessage(
      clubId: clubId,
      content: '🏆 Tournament "${name}" created! Registration open until ${_formatDate(registrationDeadline)}',
    );

    return docRef.id;
  }

  /// Register for a tournament
  Future<void> registerForTournament(String clubId, String tournamentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final tournamentRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    await _firestore.runTransaction((transaction) async {
      final tournamentDoc = await transaction.get(tournamentRef);
      if (!tournamentDoc.exists) throw Exception('Tournament not found');

      final tournament = Tournament.fromFirestore(tournamentDoc);

      if (!tournament.isRegistrationOpen) {
        throw Exception('Registration is closed');
      }

      if (tournament.isFull) {
        throw Exception('Tournament is full');
      }

      if (tournament.isParticipant(user.uid)) {
        throw Exception('Already registered');
      }

      transaction.update(tournamentRef, {
        'participantIds': FieldValue.arrayUnion([user.uid]),
      });
    });
  }

  /// Unregister from a tournament
  Future<void> unregisterFromTournament(String clubId, String tournamentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final tournamentRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    await _firestore.runTransaction((transaction) async {
      final tournamentDoc = await transaction.get(tournamentRef);
      if (!tournamentDoc.exists) throw Exception('Tournament not found');

      final tournament = Tournament.fromFirestore(tournamentDoc);

      if (!tournament.isRegistrationOpen) {
        throw Exception('Cannot unregister after registration closes');
      }

      transaction.update(tournamentRef, {
        'participantIds': FieldValue.arrayRemove([user.uid]),
      });
    });
  }

  /// Start a tournament (generate bracket/schedule matches)
  Future<void> startTournament(String clubId, String tournamentId) async {
    final tournamentRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final tournamentDoc = await tournamentRef.get();
    if (!tournamentDoc.exists) throw Exception('Tournament not found');

    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (tournament.participantIds.length < 2) {
      throw Exception('Need at least 2 participants');
    }

    // Get participant details
    final participants = await _getParticipantDetails(clubId, tournament.participantIds);

    if (tournament.format == TournamentFormat.singleElimination) {
      await _generateSingleEliminationBracket(clubId, tournamentId, participants, tournament.questionsPerMatch);
    } else {
      await _generateRoundRobinSchedule(clubId, tournamentId, participants, tournament.questionsPerMatch);
    }

    // Update tournament status
    await tournamentRef.update({
      'status': 'active',
    });

    // Post system message
    await ChatService.instance.sendSystemMessage(
      clubId: clubId,
      content: '🏁 Tournament "${tournament.name}" has started!',
    );
  }

  /// Generate single elimination bracket
  Future<void> _generateSingleEliminationBracket(
    String clubId,
    String tournamentId,
    List<Map<String, String>> participants,
    int questionsPerMatch,
  ) async {
    // Shuffle participants for random seeding
    final shuffled = List<Map<String, String>>.from(participants)..shuffle();

    // Calculate bracket size (next power of 2)
    final bracketSize = _nextPowerOfTwo(shuffled.length);

    final matchesCollection = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches');

    // Generate first round matches
    int matchNumber = 1;
    for (int i = 0; i < bracketSize / 2; i++) {
      String? player1Id, player1Name, player2Id, player2Name;

      if (i < shuffled.length) {
        player1Id = shuffled[i]['userId'];
        player1Name = shuffled[i]['displayName'];
      }

      final oppositeIndex = shuffled.length - 1 - i;
      if (oppositeIndex > i && oppositeIndex < shuffled.length) {
        player2Id = shuffled[oppositeIndex]['userId'];
        player2Name = shuffled[oppositeIndex]['displayName'];
      }

      final match = TournamentMatch(
        matchId: '',
        tournamentId: tournamentId,
        round: 1,
        matchNumber: matchNumber++,
        player1Id: player1Id,
        player1DisplayName: player1Name,
        player2Id: player2Id,
        player2DisplayName: player2Name,
        status: (player1Id != null && player2Id != null) ? MatchStatus.pending : MatchStatus.completed,
        winnerId: (player2Id == null) ? player1Id : null, // Auto-win for bye
        winnerDisplayName: (player2Id == null) ? player1Name : null,
      );

      await matchesCollection.add(match.toFirestore());
    }
  }

  /// Generate round robin schedule
  Future<void> _generateRoundRobinSchedule(
    String clubId,
    String tournamentId,
    List<Map<String, String>> participants,
    int questionsPerMatch,
  ) async {
    final matchesCollection = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches');

    int matchNumber = 1;
    int round = 1;

    // Generate all possible matchups
    for (int i = 0; i < participants.length; i++) {
      for (int j = i + 1; j < participants.length; j++) {
        final match = TournamentMatch(
          matchId: '',
          tournamentId: tournamentId,
          round: round,
          matchNumber: matchNumber++,
          player1Id: participants[i]['userId'],
          player1DisplayName: participants[i]['displayName'],
          player2Id: participants[j]['userId'],
          player2DisplayName: participants[j]['displayName'],
          status: MatchStatus.pending,
        );

        await matchesCollection.add(match.toFirestore());

        // Distribute matches across rounds
        if (matchNumber % 2 == 0) round++;
      }
    }
  }

  /// Record match result
  Future<void> recordMatchResult({
    required String clubId,
    required String tournamentId,
    required String matchId,
    required String winnerId,
    required String winnerDisplayName,
    required int player1Score,
    required int player2Score,
  }) async {
    final matchRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId);

    await matchRef.update({
      'winnerId': winnerId,
      'winnerDisplayName': winnerDisplayName,
      'player1Score': player1Score,
      'player2Score': player2Score,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Check if this advances bracket or completes tournament
    await _checkTournamentProgress(clubId, tournamentId);
  }

  /// Check if tournament is complete and handle advancement
  Future<void> _checkTournamentProgress(String clubId, String tournamentId) async {
    final tournamentRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final tournamentDoc = await tournamentRef.get();
    if (!tournamentDoc.exists) return;

    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (tournament.format == TournamentFormat.singleElimination) {
      await _advanceSingleEliminationBracket(clubId, tournamentId, tournament);
    } else {
      await _checkRoundRobinCompletion(clubId, tournamentId, tournament);
    }
  }

  /// Advance single elimination bracket to next round
  Future<void> _advanceSingleEliminationBracket(String clubId, String tournamentId, Tournament tournament) async {
    final matchesSnapshot = await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .get();

    final matches = matchesSnapshot.docs.map((doc) => TournamentMatch.fromFirestore(doc)).toList();

    // Group matches by round
    final matchesByRound = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      matchesByRound.putIfAbsent(match.round, () => []).add(match);
    }

    final currentRound = matchesByRound.keys.reduce((a, b) => a > b ? a : b);
    final currentRoundMatches = matchesByRound[currentRound]!;

    // Check if all current round matches are complete
    if (currentRoundMatches.every((m) => m.isCompleted)) {
      final winners = currentRoundMatches.where((m) => m.winnerId != null).map((m) => {
        'userId': m.winnerId!,
        'displayName': m.winnerDisplayName!,
      }).toList();

      if (winners.length == 1) {
        // Tournament complete!
        await _firestore
            .collection('clubs')
            .doc(clubId)
            .collection('tournaments')
            .doc(tournamentId)
            .update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'winnerId': winners[0]['userId'],
          'winnerDisplayName': winners[0]['displayName'],
        });

        // Post system message
        await ChatService.instance.sendSystemMessage(
          clubId: clubId,
          content: '🏆 Tournament "${tournament.name}" complete! Winner: ${winners[0]['displayName']}',
        );
      } else if (winners.length > 1) {
        // Generate next round
        final matchesCollection = _firestore
            .collection('clubs')
            .doc(clubId)
            .collection('tournaments')
            .doc(tournamentId)
            .collection('matches');

        int matchNumber = 1;
        for (int i = 0; i < winners.length; i += 2) {
          if (i + 1 < winners.length) {
            final match = TournamentMatch(
              matchId: '',
              tournamentId: tournamentId,
              round: currentRound + 1,
              matchNumber: matchNumber++,
              player1Id: winners[i]['userId'],
              player1DisplayName: winners[i]['displayName'],
              player2Id: winners[i + 1]['userId'],
              player2DisplayName: winners[i + 1]['displayName'],
              status: MatchStatus.pending,
            );
            await matchesCollection.add(match.toFirestore());
          }
        }
      }
    }
  }

  /// Check if round robin tournament is complete
  Future<void> _checkRoundRobinCompletion(String clubId, String tournamentId, Tournament tournament) async {
    final matchesSnapshot = await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .get();

    final matches = matchesSnapshot.docs.map((doc) => TournamentMatch.fromFirestore(doc)).toList();

    // If all matches are complete, determine winner by points
    if (matches.every((m) => m.isCompleted)) {
      final standings = _calculateRoundRobinStandings(matches, tournament.participantIds);

      if (standings.isNotEmpty) {
        final winner = standings.first;

        await _firestore
            .collection('clubs')
            .doc(clubId)
            .collection('tournaments')
            .doc(tournamentId)
            .update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'winnerId': winner['userId'],
          'winnerDisplayName': winner['displayName'],
        });

        // Post system message
        await ChatService.instance.sendSystemMessage(
          clubId: clubId,
          content: '🏆 Tournament "${tournament.name}" complete! Winner: ${winner['displayName']} with ${winner['points']} points',
        );
      }
    }
  }

  /// Calculate round robin standings
  List<Map<String, dynamic>> _calculateRoundRobinStandings(List<TournamentMatch> matches, List<String> participantIds) {
    final standings = <String, Map<String, dynamic>>{};

    // Initialize standings
    for (final id in participantIds) {
      standings[id] = {
        'userId': id,
        'displayName': '',
        'wins': 0,
        'losses': 0,
        'points': 0,
      };
    }

    // Calculate points (3 for win, 1 for draw if applicable, 0 for loss)
    for (final match in matches) {
      if (match.winnerId != null && match.player1Id != null && match.player2Id != null) {
        final winnerId = match.winnerId!;
        final loserId = winnerId == match.player1Id ? match.player2Id! : match.player1Id!;

        standings[winnerId]!['wins'] = (standings[winnerId]!['wins'] as int) + 1;
        standings[winnerId]!['points'] = (standings[winnerId]!['points'] as int) + 3;
        standings[winnerId]!['displayName'] = match.winnerDisplayName ?? '';

        standings[loserId]!['losses'] = (standings[loserId]!['losses'] as int) + 1;
        if (standings[loserId]!['displayName'] == '') {
          standings[loserId]!['displayName'] = loserId == match.player1Id
              ? match.player1DisplayName ?? ''
              : match.player2DisplayName ?? '';
        }
      }
    }

    final result = standings.values.toList();
    result.sort((a, b) {
      final pointsCompare = (b['points'] as int).compareTo(a['points'] as int);
      if (pointsCompare != 0) return pointsCompare;
      return (b['wins'] as int).compareTo(a['wins'] as int);
    });

    return result;
  }

  /// Get participant details from club members
  Future<List<Map<String, String>>> _getParticipantDetails(String clubId, List<String> userIds) async {
    final participants = <Map<String, String>>[];

    for (final userId in userIds) {
      final memberDoc = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .doc(userId)
          .get();

      if (memberDoc.exists) {
        final member = ClubMember.fromFirestore(memberDoc);
        participants.add({
          'userId': userId,
          'displayName': member.displayName,
        });
      }
    }

    return participants;
  }

  /// Get tournament stream
  Stream<Tournament> getTournamentStream(String clubId, String tournamentId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .snapshots()
        .map((doc) => Tournament.fromFirestore(doc));
  }

  /// Get tournaments by status
  Stream<List<Tournament>> getTournamentsStream(String clubId, {TournamentStatus? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .orderBy('createdAt', descending: true);

    if (status != null) {
      final statusString = _tournamentStatusToString(status);
      query = query.where('status', isEqualTo: statusString);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList());
  }

  String _tournamentStatusToString(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.registration:
        return 'registration';
      case TournamentStatus.active:
        return 'active';
      case TournamentStatus.completed:
        return 'completed';
    }
  }

  /// Get tournament matches
  Stream<List<TournamentMatch>> getMatchesStream(String clubId, String tournamentId, {int? round}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .orderBy('round')
        .orderBy('matchNumber');

    if (round != null) {
      query = query.where('round', isEqualTo: round);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TournamentMatch.fromFirestore(doc)).toList());
  }

  /// Helper methods
  int _nextPowerOfTwo(int n) {
    int power = 1;
    while (power < n) power *= 2;
    return power;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
