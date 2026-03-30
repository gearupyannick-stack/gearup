import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/club.dart';
import '../../models/club_member.dart';
import '../../models/tournament.dart';
import '../../services/club_service.dart';
import '../../services/club_activity_service.dart';
import '../../services/club_race_service.dart';
import '../../services/tournament_service.dart';
import 'club_chat_view.dart';
import 'tournament_create_dialog.dart';
import 'tournament_detail_page.dart';

class ClubDetailPage extends StatefulWidget {
  final String clubId;

  const ClubDetailPage({
    Key? key,
    required this.clubId,
  }) : super(key: key);

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Club? _club;
  bool _isLoading = true;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadClubData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClubData() async {
    try {
      final club = await ClubService.instance.getClub(widget.clubId);

      if (mounted) {
        setState(() {
          _club = club;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _copyInviteCode() async {
    if (_club == null) return;

    await Clipboard.setData(ClipboardData(text: _club!.inviteCode));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('clubs.messages.inviteCodeCopied'.tr(namedArgs: {'code': _club!.inviteCode})),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _leaveClub() async {
    if (_club == null || _user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('clubs.leave'.tr()),
        content: Text('clubs.confirmations.leaveClub'.tr(namedArgs: {'clubName': _club!.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('clubs.leave'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ClubService.instance.leaveClub(widget.clubId, _user.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('clubs.messages.leftClubSuccess'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('clubs.messages.errorLeavingClub'.tr(namedArgs: {'error': e.toString()})),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: const Color(0xFF3D0000),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_club == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Club Not Found'),
          backgroundColor: const Color(0xFF3D0000),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Club not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_club!.name),
        backgroundColor: const Color(0xFF3D0000),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'copy_code':
                  _copyInviteCode();
                  break;
                case 'leave':
                  _leaveClub();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy_code',
                child: Row(
                  children: [
                    const Icon(Icons.copy, size: 20),
                    const SizedBox(width: 12),
                    Text('clubs.messages.copyInviteCode'.tr(namedArgs: {'code': _club!.inviteCode})),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Leave Club', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            Tab(text: 'clubs.tabs.chat'.tr()),
            Tab(text: 'clubs.tabs.members'.tr()),
            Tab(text: 'clubs.tabs.tournaments'.tr()),
            Tab(text: 'clubs.tabs.stats'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildMembersTab(),
          _buildTournamentsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return ClubChatView(clubId: widget.clubId);
  }

  Widget _buildMembersTab() {
    return StreamBuilder<List<ClubMember>>(
      stream: ClubService.instance.getMembersStream(widget.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading members: ${snapshot.error}'),
          );
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return const Center(child: Text('No members found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          cacheExtent: 100,
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return _buildMemberCard(member);
          },
        );
      },
    );
  }

  Widget _buildMemberCard(ClubMember member) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isOwner
              ? Colors.amber
              : member.isModerator
                  ? Colors.blue
                  : Colors.grey,
          child: Text(
            member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : 'M',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                member.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _buildRoleBadge(member.role),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.country.isNotEmpty) Text('Country: ${member.country}'),
            Text(
              'Joined ${DateFormat.yMMMd().format(member.joinedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '🏆 ${member.clubRacesWon}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${member.clubRacesCompleted} races',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(ClubRole role) {
    Color badgeColor;
    Color textColor;
    String label;

    switch (role) {
      case ClubRole.owner:
        badgeColor = Colors.amber;
        textColor = Colors.amber.shade800;
        label = 'clubs.members.owner'.tr();
        break;
      case ClubRole.moderator:
        badgeColor = Colors.blue;
        textColor = Colors.blue.shade800;
        label = 'clubs.members.moderator'.tr();
        break;
      case ClubRole.member:
        badgeColor = Colors.grey;
        textColor = Colors.grey.shade800;
        label = 'clubs.members.member'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF2A2A2A),
            child: TabBar(
              indicatorColor: const Color(0xFFE53935),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'clubs.tournaments.upcoming'.tr()),
                Tab(text: 'clubs.tournaments.active'.tr()),
                Tab(text: 'clubs.tournaments.past'.tr()),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTournamentList(TournamentStatus.registration),
                _buildTournamentList(TournamentStatus.active),
                _buildTournamentList(TournamentStatus.completed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentList(TournamentStatus status) {
    return Column(
      children: [
        if (status == TournamentStatus.registration)
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              onPressed: _showCreateTournamentDialog,
              icon: const Icon(Icons.add),
              label: Text('clubs.tournaments.create'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Tournament>>(
            stream: TournamentService.instance.getTournamentsStream(widget.clubId, status: status),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final tournaments = snapshot.data ?? [];

              if (tournaments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          status == TournamentStatus.registration
                              ? 'No Upcoming Tournaments'
                              : status == TournamentStatus.active
                                  ? 'No Active Tournaments'
                                  : 'No Past Tournaments',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: tournaments.length,
                itemBuilder: (context, index) {
                  final tournament = tournaments[index];
                  return _buildTournamentCard(tournament);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final isParticipant = _user != null && tournament.isParticipant(_user.uid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tournament.isCompleted
              ? Colors.grey
              : tournament.isActive
                  ? Colors.green
                  : const Color(0xFFE53935),
          child: Icon(
            tournament.isCompleted ? Icons.emoji_events : Icons.emoji_events_outlined,
            color: Colors.white,
          ),
        ),
        title: Text(
          tournament.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournament.format == TournamentFormat.singleElimination
                  ? 'clubs.tournaments.singleElimination'.tr()
                  : 'clubs.tournaments.roundRobin'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '${tournament.participantIds.length}/${tournament.maxParticipants} players',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (tournament.isCompleted && tournament.winnerDisplayName != null)
              Text(
                'clubs.tournaments.champion'.tr(namedArgs: {'name': tournament.winnerDisplayName!}),
                style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700)),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isParticipant)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            if (tournament.isRegistrationOpen)
              Text(
                'clubs.tournaments.registrationOpen'.tr(),
                style: const TextStyle(fontSize: 11, color: Color(0xFFE53935)),
              ),
          ],
        ),
        onTap: () => _openTournamentDetail(tournament),
      ),
    );
  }

  Future<void> _showCreateTournamentDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const TournamentCreateDialog(),
    );

    if (result != null && mounted) {
      try {
        await TournamentService.instance.createTournament(
          clubId: widget.clubId,
          name: result['name'],
          format: result['format'],
          maxParticipants: result['maxParticipants'],
          registrationDeadline: result['registrationDeadline'],
          startTime: result['startTime'],
          questionsPerMatch: result['questionsPerMatch'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tournament created!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openTournamentDetail(Tournament tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentDetailPage(
          clubId: widget.clubId,
          tournamentId: tournament.tournamentId,
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF2A2A2A),
            child: TabBar(
              indicatorColor: const Color(0xFFE53935),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Activity Feed'),
                Tab(text: 'Leaderboard'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildActivityFeed(),
                _buildLeaderboard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ClubActivityService.instance.getClubActivityFeed(widget.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading activity: ${snapshot.error}'));
        }

        final activities = snapshot.data ?? [];

        if (activities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timeline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Activity Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Club activities will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _buildActivityCard(activity);
          },
        );
      },
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type'] as String;
    final userName = activity['userName'] as String;
    IconData icon;
    Color iconColor;
    String description;

    switch (type) {
      case 'homeChallenge':
        icon = Icons.flag;
        iconColor = Colors.blue;
        final challengeType = activity['challengeType'] ?? 'Challenge';
        final score = activity['score'] ?? 0;
        final total = activity['total'] ?? 10;
        description = '$userName completed $challengeType Challenge: $score/$total';
        break;
      case 'publicRace':
        icon = Icons.emoji_events;
        iconColor = Colors.amber;
        final placement = activity['placement'] ?? 0;
        description = '$userName placed #$placement in a public race';
        break;
      case 'milestone':
        icon = Icons.star;
        iconColor = Colors.purple;
        final achievementName = activity['achievementName'] ?? 'an achievement';
        description = '$userName unlocked $achievementName!';
        break;
      case 'clubRace':
        icon = Icons.emoji_events;
        iconColor = Colors.green;
        description = '$userName completed a club race';
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
        description = userName;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          description,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatTimestamp(activity['timestamp']),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final DateTime dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM d').format(dateTime);
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildLeaderboard() {
    return StreamBuilder<List<ClubMember>>(
      stream: ClubRaceService.instance.getTopPointEarnersStream(widget.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading leaderboard: ${snapshot.error}'));
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Rankings Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete club races to earn points!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final rank = index + 1;
            return _buildLeaderboardCard(member, rank);
          },
        );
      },
    );
  }

  Widget _buildLeaderboardCard(ClubMember member, int rank) {
    String medal = '';
    Color rankColor = Colors.grey;

    if (rank == 1) {
      medal = '🥇';
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      medal = '🥈';
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      medal = '🥉';
      rankColor = const Color(0xFFCD7F32);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          child: Center(
            child: medal.isNotEmpty
                ? Text(medal, style: const TextStyle(fontSize: 24))
                : Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
          ),
        ),
        title: Text(
          member.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${member.clubRacesWon} wins • ${member.clubRacesCompleted} races',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${member.clubPoints}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
              ),
            ),
            Text(
              'points',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
