import 'dart:async';
import 'package:flutter/material.dart';
import 'stitch_theme.dart';

class TournamentCountdown extends StatefulWidget {
  final DateTime startTime;
  final VoidCallback? onTimerFinished;
  final bool isCompact;
  final String? status;

  const TournamentCountdown({
    Key? key,
    required this.startTime,
    this.onTimerFinished,
    this.isCompact = false,
    this.status,
  }) : super(key: key);

  @override
  State<TournamentCountdown> createState() => _TournamentCountdownState();
}

class _TournamentCountdownState extends State<TournamentCountdown> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    final now = DateTime.now().toUtc();
    final difference = widget.startTime.difference(now);

    if (difference.isNegative) {
      _timeLeft = Duration.zero;
      _timer?.cancel();
      widget.onTimerFinished?.call();
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = difference;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) {
      final label = widget.status == 'completed' ? 'COMPLETED' : 'ONGOING';
      final color = widget.status == 'completed' ? StitchTheme.success : StitchTheme.error;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: widget.isCompact ? 10 : 12),
        ),
      );
    }

    if (widget.isCompact) {
      final hours = _timeLeft.inHours.toString().padLeft(2, '0');
      final mins = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
      final secs = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');
      
      return Text(
        '${hours}h ${mins}m ${secs}s',
        style: const TextStyle(
          color: StitchTheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_timeLeft.inDays > 0) ...[
          _buildTimeBox(_timeLeft.inDays.toString(), 'DAYS'),
          _buildDivider(),
        ],
        _buildTimeBox((_timeLeft.inHours % 24).toString().padLeft(2, '0'), 'HRS'),
        _buildDivider(),
        _buildTimeBox((_timeLeft.inMinutes % 60).toString().padLeft(2, '0'), 'MINS'),
        _buildDivider(),
        _buildTimeBox((_timeLeft.inSeconds % 60).toString().padLeft(2, '0'), 'SECS'),
      ],
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: StitchTheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: StitchTheme.textMuted.withOpacity(0.7),
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 20,
      width: 1,
      color: Colors.white10,
    );
  }
}
