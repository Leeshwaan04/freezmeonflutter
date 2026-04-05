import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../design_system.dart';
class FreezeRoomPage extends StatefulWidget {
  const FreezeRoomPage({super.key});

  @override
  State<FreezeRoomPage> createState() => _FreezeRoomPageState();
}

class _FreezeRoomPageState extends State<FreezeRoomPage>
    with TickerProviderStateMixin {
  // ── State ───────────────────────────────────────────────────────────────────

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _room;       // current FreezeRoom from API
  List<Map<String, dynamic>> _participants = [];
  String? _myAnswer;
  List<String> _myReveals = [];

  final _answerController = TextEditingController();
  bool _submitting = false;

  // Reveal animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Socket subscriptions
  StreamSubscription<Map<String, dynamic>>? _answerSub;
  StreamSubscription<Map<String, dynamic>>? _revealSub;
  StreamSubscription<Map<String, dynamic>>? _closedSub;

  // countdown
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _load();
    _subscribeSocket();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _answerController.dispose();
    _countdownTimer?.cancel();
    _answerSub?.cancel();
    _revealSub?.cancel();
    _closedSub?.cancel();
    if (_room != null) {
      WebSocketService.instance.leaveFreezeRoom(_room!['id'] as String);
    }
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio
          .get<Map<String, dynamic>>('/freeze-room/current');
      final data = res.data;
      if (data == null || data['room'] == null) {
        setState(() { _loading = false; _room = null; });
        return;
      }
      setState(() {
        _room = data['room'] as Map<String, dynamic>;
        _myAnswer = data['myAnswer'] as String?;
        _myReveals = (data['myReveals'] as List<dynamic>?)
                ?.cast<String>() ??
            [];
        _loading = false;
      });
      _startCountdown();
      WebSocketService.instance.joinFreezeRoom(_room!['id'] as String);
      if (_myAnswer != null) await _loadParticipants();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadParticipants() async {
    if (_room == null) return;
    try {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/freeze-room/participants',
        queryParameters: {'roomId': _room!['id']},
      );
      setState(() {
        _participants = (res.data ?? []).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final closesAt = _room?['closesAt'] as String?;
    if (closesAt == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final closes = DateTime.tryParse(closesAt);
      if (closes == null) return;
      final diff = closes.difference(DateTime.now());
      if (!mounted) return;
      if (diff.isNegative) {
        _countdownTimer?.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining = diff);
      }
    });
  }

  void _subscribeSocket() {
    final ws = WebSocketService.instance;
    _answerSub = ws.onFreezeRoomAnswer.listen((data) {
      // A new anonymous answer came in — refresh participant list
      if (_myAnswer != null) _loadParticipants();
    });
    _revealSub = ws.onFreezeRoomReveal.listen((data) {
      // Someone revealed to us — show match celebration
      final matchedWith = data['matchedWith'] as String?;
      if (matchedWith != null && mounted) _showMatchCelebration(matchedWith);
    });
    _closedSub = ws.onFreezeRoomClosed.listen((_) {
      if (mounted) setState(() => _remaining = Duration.zero);
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty || _room == null) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.instance.dio.post<void>('/freeze-room/join', data: {
        'roomId': _room!['id'],
        'answer': answer,
      });
      setState(() {
        _myAnswer = answer;
        _submitting = false;
      });
      _loadParticipants();
    } catch (e) {
      setState(() => _submitting = false);
      _showError('Could not submit answer: $e');
    }
  }

  Future<void> _revealParticipant(String participantUid) async {
    if (_myReveals.length >= 3) {
      _showError('You can only reveal 3 people per session.');
      return;
    }
    if (_myReveals.contains(participantUid)) return;
    try {
      final res = await ApiClient.instance.dio.post<Map<String, dynamic>>(
        '/freeze-room/reveal',
        data: {'roomId': _room!['id'], 'targetUid': participantUid},
      );
      setState(() => _myReveals = [..._myReveals, participantUid]);
      final matched = res.data?['matched'] as bool? ?? false;
      if (matched && mounted) _showMatchCelebration(participantUid);
    } catch (e) {
      _showError('Could not reveal: $e');
    }
  }

  void _showMatchCelebration(String matchedWith) {
    showDialog<void>(
      context: context,
      builder: (_) => _MatchDialog(matchedWith: matchedWith),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: FreezmeDesignSystem.error),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final flow = AppFlowScope.of(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: flow.pop,
            child: const Icon(Icons.arrow_back_ios_new,
                color: FreezmeDesignSystem.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('❄️ Freeze Room',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: FreezmeDesignSystem.textPrimary)),
          const Spacer(),
          if (_remaining > Duration.zero)
            _CountdownChip(remaining: _remaining),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: FreezmeDesignSystem.primary));
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    if (_room == null || _remaining == Duration.zero) {
      return _NoRoomView(onRefresh: _load);
    }
    if (_myAnswer == null) {
      return _AnswerInputView(
        room: _room!,
        controller: _answerController,
        submitting: _submitting,
        onSubmit: _submitAnswer,
        pulseAnim: _pulseAnim,
      );
    }
    return _ParticipantsView(
      room: _room!,
      participants: _participants,
      myAnswer: _myAnswer!,
      myReveals: _myReveals,
      onReveal: _revealParticipant,
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.remaining});
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final label = h > 0
        ? '${h}h ${m.toString().padLeft(2, '0')}m'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FreezmeDesignSystem.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined,
              size: 12, color: FreezmeDesignSystem.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FreezmeDesignSystem.primary)),
        ],
      ),
    );
  }
}

class _NoRoomView extends StatelessWidget {
  const _NoRoomView({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('❄️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('No room open right now',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: FreezmeDesignSystem.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Freeze Rooms open every 2 hours for 20 minutes.\nCheck back soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: FreezmeDesignSystem.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: FreezmeDesignSystem.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: FreezmeDesignSystem.error, size: 48),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FreezmeDesignSystem.textSecondary)),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AnswerInputView extends StatelessWidget {
  const _AnswerInputView({
    required this.room,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
    required this.pulseAnim,
  });

  final Map<String, dynamic> room;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    final prompt = room['prompt'] as String? ?? '';
    final promptType = room['promptType'] as String? ?? 'reflective';
    final participantCount = room['participantCount'] as int? ?? 0;

    final typeEmoji = switch (promptType) {
      'playful' => '😄',
      'values' => '💡',
      _ => '🌊',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live count banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: FreezmeDesignSystem.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: pulseAnim,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: FreezmeDesignSystem.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$participantCount ${participantCount == 1 ? 'person' : 'people'} in the room',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FreezmeDesignSystem.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Prompt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FreezmeDesignSystem.primary.withValues(alpha: 0.08),
                  FreezmeDesignSystem.accentGloss.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(typeEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      promptType[0].toUpperCase() + promptType.substring(1),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FreezmeDesignSystem.primary,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  prompt,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: FreezmeDesignSystem.textPrimary,
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Anonymous note
          const Row(
            children: [
              Icon(Icons.visibility_off_outlined,
                  size: 14, color: FreezmeDesignSystem.textTertiary),
              SizedBox(width: 6),
              Text(
                'Your answer is anonymous until someone reveals you',
                style: TextStyle(
                    fontSize: 12, color: FreezmeDesignSystem.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Answer input
          TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 200,
            style: const TextStyle(
                fontSize: 15, color: FreezmeDesignSystem.textPrimary),
            decoration: InputDecoration(
              hintText: 'Write your answer…',
              hintStyle: TextStyle(
                  color: FreezmeDesignSystem.textTertiary.withValues(alpha: 0.7)),
              filled: true,
              fillColor: FreezmeDesignSystem.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FreezmeDesignSystem.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FreezmeDesignSystem.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: FreezmeDesignSystem.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: FreezmeDesignSystem.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor:
                    FreezmeDesignSystem.primary.withValues(alpha: 0.5),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enter the Room',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsView extends StatelessWidget {
  const _ParticipantsView({
    required this.room,
    required this.participants,
    required this.myAnswer,
    required this.myReveals,
    required this.onReveal,
  });

  final Map<String, dynamic> room;
  final List<Map<String, dynamic>> participants;
  final String myAnswer;
  final List<String> myReveals;
  final Future<void> Function(String uid) onReveal;

  @override
  Widget build(BuildContext context) {
    final prompt = room['prompt'] as String? ?? '';

    return Column(
      children: [
        // Your answer card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FreezmeDesignSystem.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your answer',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FreezmeDesignSystem.primary,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(myAnswer,
                    style: const TextStyle(
                        fontSize: 14, color: FreezmeDesignSystem.textPrimary)),
              ],
            ),
          ),
        ),

        // Reveals counter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                '${myReveals.length}/3 reveals used',
                style: const TextStyle(
                    fontSize: 12,
                    color: FreezmeDesignSystem.textSecondary),
              ),
              const Spacer(),
              Text(
                '${participants.length} answers in the room',
                style: const TextStyle(
                    fontSize: 12,
                    color: FreezmeDesignSystem.textSecondary),
              ),
            ],
          ),
        ),

        // Prompt text (compact)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            '"$prompt"',
            style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: FreezmeDesignSystem.textTertiary),
          ),
        ),

        const Divider(height: 16),

        // Participants list
        Expanded(
          child: participants.isEmpty
              ? const Center(
                  child: Text('No other answers yet. Check back shortly.',
                      style: TextStyle(color: FreezmeDesignSystem.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = participants[i];
                    final uid = p['uid'] as String;
                    final answer = p['answer'] as String? ?? '';
                    final revealed = myReveals.contains(uid);
                    return _ParticipantCard(
                      uid: uid,
                      answer: answer,
                      revealed: revealed,
                      revealsLeft: 3 - myReveals.length,
                      onReveal: () => onReveal(uid),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.uid,
    required this.answer,
    required this.revealed,
    required this.revealsLeft,
    required this.onReveal,
  });

  final String uid;
  final String answer;
  final bool revealed;
  final int revealsLeft;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: revealed
              ? FreezmeDesignSystem.primary.withValues(alpha: 0.3)
              : FreezmeDesignSystem.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FreezmeDesignSystem.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(
                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Text('?',
                  style: TextStyle(
                      fontSize: 18,
                      color: FreezmeDesignSystem.primary,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  revealed ? 'Revealed ✓' : 'Anonymous',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: revealed
                          ? FreezmeDesignSystem.success
                          : FreezmeDesignSystem.textTertiary),
                ),
                const SizedBox(height: 4),
                Text(
                  answer,
                  style: const TextStyle(
                      fontSize: 14,
                      color: FreezmeDesignSystem.textPrimary,
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!revealed && revealsLeft > 0)
            GestureDetector(
              onTap: onReveal,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      FreezmeDesignSystem.primary,
                      FreezmeDesignSystem.accentGloss,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Reveal',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            )
          else if (revealed)
            const Icon(Icons.check_circle,
                color: FreezmeDesignSystem.success, size: 20),
        ],
      ),
    );
  }
}

class _MatchDialog extends StatelessWidget {
  const _MatchDialog({required this.matchedWith});
  final String matchedWith;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text(
              'You both revealed!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: FreezmeDesignSystem.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'A match has been created.\nHead to your chats to say hello.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: FreezmeDesignSystem.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FreezmeDesignSystem.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('See my matches'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
