import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/tournament.dart';

class TournamentCreateDialog extends StatefulWidget {
  const TournamentCreateDialog({Key? key}) : super(key: key);

  @override
  State<TournamentCreateDialog> createState() => _TournamentCreateDialogState();
}

class _TournamentCreateDialogState extends State<TournamentCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  TournamentFormat _format = TournamentFormat.singleElimination;
  int _maxParticipants = 8;
  DateTime _registrationDeadline = DateTime.now().add(const Duration(days: 1));
  DateTime _startTime = DateTime.now().add(const Duration(days: 2));
  int _questionsPerMatch = 10;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isRegistration) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isRegistration ? _registrationDeadline : _startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isRegistration ? _registrationDeadline : _startTime),
      );

      if (time != null && mounted) {
        setState(() {
          final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (isRegistration) {
            _registrationDeadline = dateTime;
          } else {
            _startTime = dateTime;
          }
        });
      }
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'format': _format,
        'maxParticipants': _maxParticipants,
        'registrationDeadline': _registrationDeadline,
        'startTime': _startTime,
        'questionsPerMatch': _questionsPerMatch,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'clubs.tournaments.create'.tr(),
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament Name
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'clubs.tournaments.name'.tr(),
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a tournament name';
                  }
                  if (value.trim().length > 30) {
                    return 'Max 30 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Format Selection
              Text(
                'clubs.tournaments.format'.tr(),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<TournamentFormat>(
                      value: TournamentFormat.singleElimination,
                      groupValue: _format,
                      onChanged: (value) => setState(() => _format = value!),
                      title: Text(
                        'clubs.tournaments.singleElimination'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      activeColor: const Color(0xFFE53935),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<TournamentFormat>(
                      value: TournamentFormat.roundRobin,
                      groupValue: _format,
                      onChanged: (value) => setState(() => _format = value!),
                      title: Text(
                        'clubs.tournaments.roundRobin'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      activeColor: const Color(0xFFE53935),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Max Participants
              Text(
                'clubs.tournaments.maxParticipants'.tr(),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              DropdownButtonFormField<int>(
                value: _maxParticipants,
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935)),
                  ),
                ),
                items: [4, 8, 16, 32].map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text('$value players'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _maxParticipants = value!),
              ),
              const SizedBox(height: 16),

              // Questions Per Match
              Text(
                'clubs.tournaments.questionsPerMatch'.tr(),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              DropdownButtonFormField<int>(
                value: _questionsPerMatch,
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935)),
                  ),
                ),
                items: [5, 10, 15, 20].map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text('$value questions'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _questionsPerMatch = value!),
              ),
              const SizedBox(height: 16),

              // Registration Deadline
              Text(
                'clubs.tournaments.registrationDeadline'.tr(),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _selectDateTime(context, true),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  DateFormat('MMM d, yyyy - HH:mm').format(_registrationDeadline),
                  style: const TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[700]!),
                ),
              ),
              const SizedBox(height: 16),

              // Start Time
              Text(
                'clubs.tournaments.startTime'.tr(),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _selectDateTime(context, false),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  DateFormat('MMM d, yyyy - HH:mm').format(_startTime),
                  style: const TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[700]!),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
          ),
          child: Text('clubs.tournaments.create'.tr(), style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
