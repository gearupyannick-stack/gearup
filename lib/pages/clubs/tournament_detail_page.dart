import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tournament.dart';
import '../../models/tournament_match.dart';
import '../../services/tournament_service.dart';

class TournamentDetailPage extends StatefulWidget {
  final String clubId;
  final String tournamentId;

  const TournamentDetailPage({
    Key? key,
    required this.clubId,
    required this.tournamentId,
  }) : super(key: key);

  @override
  State<TournamentDetailPage> createState() => _TournamentDetailPageState();
}

class _TournamentDetailPageState extends State<TournamentDetailPage> {
  final _user = FirebaseAuth.instance.currentUser;

  Future<void> _register() async {
    try {
      await TournamentService.instance.registerForTournament(widget.clubId, widget.tournamentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _unregister() async {
    try {
      await TournamentService.instance.unregisterFromTournament(widget.clubId, widget.tournamentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unregistered'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startTournament() async {
    try {
      await TournamentService.instance.startTournament(widget.clubId, widget.tournamentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament started!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament'),
        backgroundColor: const Color(0xFF3D0000),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Tournament>(
        stream: TournamentService.instance.getTournamentStream(widget.clubId, widget.tournamentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Tournament not found'));
          }

          final tournament = snapshot.data!;
          final isParticipant = _user != null && tournament.isParticipant(_user.uid);
          final isCreator = _user != null && tournament.creatorId == _user.uid;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tournament Header
                Text(tournament.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  tournament.format == TournamentFormat.singleElimination
                      ? 'clubs.tournaments.singleElimination'.tr()
                      : 'clubs.tournaments.roundRobin'.tr(),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // Status Chip
                Chip(
                  label: Text(
                    tournament.isCompleted
                        ? 'clubs.tournaments.completed'.tr()
                        : tournament.isActive
                            ? 'clubs.tournaments.inProgress'.tr()
                            : 'clubs.tournaments.registrationOpen'.tr(),
                  ),
                  backgroundColor: tournament.isCompleted
                      ? Colors.grey
                      : tournament.isActive
                          ? Colors.green
                          : const Color(0xFFE53935),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),

                // Info
                _buildInfoRow('Max Participants', '${tournament.maxParticipants}'),
                _buildInfoRow('Registered', '${tournament.participantIds.length}'),
                _buildInfoRow('Questions per Match', '${tournament.questionsPerMatch}'),
                _buildInfoRow('Registration Deadline', DateFormat('MMM d, HH:mm').format(tournament.registrationDeadline)),
                _buildInfoRow('Start Time', DateFormat('MMM d, HH:mm').format(tournament.startTime)),
                const SizedBox(height: 16),

                // Action Buttons
                if (tournament.isRegistrationOpen && !isParticipant && !tournament.isFull)
                  ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                    child: Text('clubs.tournaments.register'.tr()),
                  ),
                if (tournament.isRegistrationOpen && isParticipant)
                  ElevatedButton(
                    onPressed: _unregister,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text('clubs.tournaments.unregister'.tr()),
                  ),
                if (tournament.isRegistrationOpen && isCreator && tournament.participantIds.length >= 2)
                  ElevatedButton(
                    onPressed: _startTournament,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Start Tournament'),
                  ),
                const SizedBox(height: 24),

                // Bracket/Standings
                if (tournament.isActive || tournament.isCompleted)
                  _buildMatches(tournament),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMatches(Tournament tournament) {
    return StreamBuilder<List<TournamentMatch>>(
      stream: TournamentService.instance.getMatchesStream(widget.clubId, widget.tournamentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final matches = snapshot.data!;
        if (matches.isEmpty) {
          return const Text('No matches yet');
        }

        // Group by round
        final matchesByRound = <int, List<TournamentMatch>>{};
        for (final match in matches) {
          matchesByRound.putIfAbsent(match.round, () => []).add(match);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: matchesByRound.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'clubs.tournaments.round'.tr(namedArgs: {'number': '${entry.key}'}),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...entry.value.map((match) => _buildMatchCard(match)),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMatchCard(TournamentMatch match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                match.player1DisplayName ?? 'TBD',
                style: TextStyle(
                  fontWeight: match.winnerId == match.player1Id ? FontWeight.bold : FontWeight.normal,
                  color: match.winnerId == match.player1Id ? Colors.green : null,
                ),
              ),
            ),
            if (match.isCompleted)
              Text('${match.player1Score} - ${match.player2Score}', style: const TextStyle(fontWeight: FontWeight.bold))
            else
              const Text('vs'),
            Expanded(
              child: Text(
                match.player2DisplayName ?? 'TBD',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: match.winnerId == match.player2Id ? FontWeight.bold : FontWeight.normal,
                  color: match.winnerId == match.player2Id ? Colors.green : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
