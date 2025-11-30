import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus {
  pending,
  active,
  completed,
}

class TournamentMatch {
  final String matchId;
  final String tournamentId;
  final int round;
  final int matchNumber;
  final String? player1Id;
  final String? player1DisplayName;
  final String? player2Id;
  final String? player2DisplayName;
  final String? winnerId;
  final String? winnerDisplayName;
  final int? player1Score;
  final int? player2Score;
  final MatchStatus status;
  final DateTime? scheduledTime;
  final DateTime? completedAt;
  final String? roomCode;

  TournamentMatch({
    required this.matchId,
    required this.tournamentId,
    required this.round,
    required this.matchNumber,
    this.player1Id,
    this.player1DisplayName,
    this.player2Id,
    this.player2DisplayName,
    this.winnerId,
    this.winnerDisplayName,
    this.player1Score,
    this.player2Score,
    required this.status,
    this.scheduledTime,
    this.completedAt,
    this.roomCode,
  });

  factory TournamentMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TournamentMatch(
      matchId: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      round: data['round'] ?? 1,
      matchNumber: data['matchNumber'] ?? 1,
      player1Id: data['player1Id'],
      player1DisplayName: data['player1DisplayName'],
      player2Id: data['player2Id'],
      player2DisplayName: data['player2DisplayName'],
      winnerId: data['winnerId'],
      winnerDisplayName: data['winnerDisplayName'],
      player1Score: data['player1Score'],
      player2Score: data['player2Score'],
      status: _parseStatus(data['status']),
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      roomCode: data['roomCode'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'round': round,
      'matchNumber': matchNumber,
      if (player1Id != null) 'player1Id': player1Id,
      if (player1DisplayName != null) 'player1DisplayName': player1DisplayName,
      if (player2Id != null) 'player2Id': player2Id,
      if (player2DisplayName != null) 'player2DisplayName': player2DisplayName,
      if (winnerId != null) 'winnerId': winnerId,
      if (winnerDisplayName != null) 'winnerDisplayName': winnerDisplayName,
      if (player1Score != null) 'player1Score': player1Score,
      if (player2Score != null) 'player2Score': player2Score,
      'status': _statusToString(status),
      if (scheduledTime != null) 'scheduledTime': Timestamp.fromDate(scheduledTime!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (roomCode != null) 'roomCode': roomCode,
    };
  }

  static MatchStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return MatchStatus.pending;
      case 'active':
        return MatchStatus.active;
      case 'completed':
        return MatchStatus.completed;
      default:
        return MatchStatus.pending;
    }
  }

  static String _statusToString(MatchStatus status) {
    switch (status) {
      case MatchStatus.pending:
        return 'pending';
      case MatchStatus.active:
        return 'active';
      case MatchStatus.completed:
        return 'completed';
    }
  }

  bool get isPending => status == MatchStatus.pending;
  bool get isActive => status == MatchStatus.active;
  bool get isCompleted => status == MatchStatus.completed;
  bool get hasBothPlayers => player1Id != null && player2Id != null;
  bool get isBye => player1Id == null || player2Id == null;

  TournamentMatch copyWith({
    String? matchId,
    String? tournamentId,
    int? round,
    int? matchNumber,
    String? player1Id,
    String? player1DisplayName,
    String? player2Id,
    String? player2DisplayName,
    String? winnerId,
    String? winnerDisplayName,
    int? player1Score,
    int? player2Score,
    MatchStatus? status,
    DateTime? scheduledTime,
    DateTime? completedAt,
    String? roomCode,
  }) {
    return TournamentMatch(
      matchId: matchId ?? this.matchId,
      tournamentId: tournamentId ?? this.tournamentId,
      round: round ?? this.round,
      matchNumber: matchNumber ?? this.matchNumber,
      player1Id: player1Id ?? this.player1Id,
      player1DisplayName: player1DisplayName ?? this.player1DisplayName,
      player2Id: player2Id ?? this.player2Id,
      player2DisplayName: player2DisplayName ?? this.player2DisplayName,
      winnerId: winnerId ?? this.winnerId,
      winnerDisplayName: winnerDisplayName ?? this.winnerDisplayName,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      status: status ?? this.status,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      completedAt: completedAt ?? this.completedAt,
      roomCode: roomCode ?? this.roomCode,
    );
  }
}
