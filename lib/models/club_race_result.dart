class ClubRaceResult {
  final String userId;
  final String displayName;
  final int placement;
  final int score;
  final int totalQuestions;
  final int clubPoints;
  final int eloChange;
  final Duration raceTime;
  final bool hadPerfectScore;
  final bool hadSpeedBonus;

  ClubRaceResult({
    required this.userId,
    required this.displayName,
    required this.placement,
    required this.score,
    required this.totalQuestions,
    required this.clubPoints,
    required this.eloChange,
    required this.raceTime,
    this.hadPerfectScore = false,
    this.hadSpeedBonus = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'placement': placement,
      'score': score,
      'totalQuestions': totalQuestions,
      'clubPoints': clubPoints,
      'eloChange': eloChange,
      'raceTimeSeconds': raceTime.inSeconds,
      'hadPerfectScore': hadPerfectScore,
      'hadSpeedBonus': hadSpeedBonus,
    };
  }

  factory ClubRaceResult.fromMap(Map<String, dynamic> map) {
    return ClubRaceResult(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? 'Unknown',
      placement: map['placement'] ?? 0,
      score: map['score'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      clubPoints: map['clubPoints'] ?? 0,
      eloChange: map['eloChange'] ?? 0,
      raceTime: Duration(seconds: map['raceTimeSeconds'] ?? 0),
      hadPerfectScore: map['hadPerfectScore'] ?? false,
      hadSpeedBonus: map['hadSpeedBonus'] ?? false,
    );
  }

  /// Calculate club points based on placement and bonuses
  static int calculateClubPoints({
    required int placement,
    required int score,
    required int totalQuestions,
    required Duration raceTime,
    Duration? speedThreshold,
  }) {
    int points = 0;

    // Base points by placement
    switch (placement) {
      case 1:
        points = 100;
        break;
      case 2:
        points = 75;
        break;
      case 3:
        points = 50;
        break;
      case 4:
        points = 30;
        break;
      case 5:
        points = 20;
        break;
      default:
        points = 10; // Participation points
    }

    // Perfect score bonus
    if (score == totalQuestions) {
      points += 25;
    }

    // Speed bonus (if finished under threshold)
    if (speedThreshold != null && raceTime < speedThreshold) {
      points += 10;
    }

    return points;
  }
}
