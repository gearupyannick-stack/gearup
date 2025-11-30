import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentFormat {
  singleElimination,
  roundRobin,
}

enum TournamentStatus {
  registration,
  active,
  completed,
}

class Tournament {
  final String tournamentId;
  final String clubId;
  final String name;
  final String creatorId;
  final TournamentFormat format;
  final TournamentStatus status;
  final int maxParticipants;
  final DateTime registrationDeadline;
  final DateTime startTime;
  final int questionsPerMatch;
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? winnerId;
  final String? winnerDisplayName;

  Tournament({
    required this.tournamentId,
    required this.clubId,
    required this.name,
    required this.creatorId,
    required this.format,
    required this.status,
    required this.maxParticipants,
    required this.registrationDeadline,
    required this.startTime,
    required this.questionsPerMatch,
    required this.participantIds,
    required this.createdAt,
    this.completedAt,
    this.winnerId,
    this.winnerDisplayName,
  });

  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tournament(
      tournamentId: doc.id,
      clubId: data['clubId'] ?? '',
      name: data['name'] ?? '',
      creatorId: data['creatorId'] ?? '',
      format: _parseFormat(data['format']),
      status: _parseStatus(data['status']),
      maxParticipants: data['maxParticipants'] ?? 8,
      registrationDeadline: (data['registrationDeadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      questionsPerMatch: data['questionsPerMatch'] ?? 10,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      winnerId: data['winnerId'],
      winnerDisplayName: data['winnerDisplayName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'name': name,
      'creatorId': creatorId,
      'format': _formatToString(format),
      'status': _statusToString(status),
      'maxParticipants': maxParticipants,
      'registrationDeadline': Timestamp.fromDate(registrationDeadline),
      'startTime': Timestamp.fromDate(startTime),
      'questionsPerMatch': questionsPerMatch,
      'participantIds': participantIds,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (winnerId != null) 'winnerId': winnerId,
      if (winnerDisplayName != null) 'winnerDisplayName': winnerDisplayName,
    };
  }

  static TournamentFormat _parseFormat(String? format) {
    switch (format) {
      case 'singleElimination':
        return TournamentFormat.singleElimination;
      case 'roundRobin':
        return TournamentFormat.roundRobin;
      default:
        return TournamentFormat.singleElimination;
    }
  }

  static String _formatToString(TournamentFormat format) {
    switch (format) {
      case TournamentFormat.singleElimination:
        return 'singleElimination';
      case TournamentFormat.roundRobin:
        return 'roundRobin';
    }
  }

  static TournamentStatus _parseStatus(String? status) {
    switch (status) {
      case 'registration':
        return TournamentStatus.registration;
      case 'active':
        return TournamentStatus.active;
      case 'completed':
        return TournamentStatus.completed;
      default:
        return TournamentStatus.registration;
    }
  }

  static String _statusToString(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.registration:
        return 'registration';
      case TournamentStatus.active:
        return 'active';
      case TournamentStatus.completed:
        return 'completed';
    }
  }

  bool get isRegistrationOpen => status == TournamentStatus.registration;
  bool get isActive => status == TournamentStatus.active;
  bool get isCompleted => status == TournamentStatus.completed;
  bool get isFull => participantIds.length >= maxParticipants;
  bool isParticipant(String userId) => participantIds.contains(userId);

  Tournament copyWith({
    String? tournamentId,
    String? clubId,
    String? name,
    String? creatorId,
    TournamentFormat? format,
    TournamentStatus? status,
    int? maxParticipants,
    DateTime? registrationDeadline,
    DateTime? startTime,
    int? questionsPerMatch,
    List<String>? participantIds,
    DateTime? createdAt,
    DateTime? completedAt,
    String? winnerId,
    String? winnerDisplayName,
  }) {
    return Tournament(
      tournamentId: tournamentId ?? this.tournamentId,
      clubId: clubId ?? this.clubId,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      format: format ?? this.format,
      status: status ?? this.status,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      startTime: startTime ?? this.startTime,
      questionsPerMatch: questionsPerMatch ?? this.questionsPerMatch,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      winnerId: winnerId ?? this.winnerId,
      winnerDisplayName: winnerDisplayName ?? this.winnerDisplayName,
    );
  }
}
