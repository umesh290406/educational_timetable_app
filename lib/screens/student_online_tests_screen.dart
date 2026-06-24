import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/online_test_model.dart';
import '../services/online_test_service.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT ONLINE TESTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class StudentOnlineTestsScreen extends StatefulWidget {
  const StudentOnlineTestsScreen({super.key});

  @override
  State<StudentOnlineTestsScreen> createState() => _StudentOnlineTestsScreenState();
}

class _StudentOnlineTestsScreenState extends State<StudentOnlineTestsScreen> {
  List<OnlineTest> _tests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final className = auth.user?.className ?? '';
    final section = auth.user?.section ?? '';
    final specialization = auth.user?.specialization;
    if (className.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final tests = await OnlineTestService.getTestsForClass(
      className, 
      section, 
      specialization: specialization,
    );
    if (mounted) setState(() { _tests = tests; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Online Tests', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadTests),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _tests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_outlined, size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No tests available', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text('Your teacher hasn\'t scheduled any tests yet.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tests.length,
                    itemBuilder: (_, i) => _buildTestCard(_tests[i], auth.user?.name ?? 'Student'),
                  ),
                ),
    );
  }

  Widget _buildTestCard(OnlineTest test, String studentName) {
    final attempted = test.attempted;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: attempted ? Colors.green.shade50 : Colors.teal.shade50,
                  child: Icon(
                    attempted ? Icons.check_circle : Icons.quiz,
                    color: attempted ? Colors.green.shade600 : Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(test.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        [
                          'By ${test.teacherName}',
                          if (test.specialization != null && test.specialization!.isNotEmpty)
                            test.specialization!,
                        ].join(' • '),
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (attempted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text('Done', style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip(Icons.timer_outlined, '${test.durationMinutes} min', Colors.orange),
                const SizedBox(width: 8),
                if (attempted && test.score != null && test.totalQuestions != null)
                  _chip(Icons.star_outlined, 'Score: ${test.score}/${test.totalQuestions}', Colors.blue),
              ],
            ),
            const SizedBox(height: 14),
            if (!attempted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: Text('Start Test', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _openInstructions(test, studentName),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 8),
                    Text('You have already submitted this test.',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _openInstructions(OnlineTest test, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _InstructionsSheet(test: test, studentName: studentName, onStart: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test, studentName: studentName)),
        ).then((_) => _loadTests());
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTRUCTIONS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _InstructionsSheet extends StatelessWidget {
  final OnlineTest test;
  final String studentName;
  final VoidCallback onStart;
  const _InstructionsSheet({required this.test, required this.studentName, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (_, sc) => SingleChildScrollView(
        controller: sc,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.rule, color: Colors.red.shade600, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(test.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17)),
                      Text('${test.durationMinutes} minutes • Read instructions carefully',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text('STRICT INSTRUCTIONS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade700)),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    test.instructions.isNotEmpty ? test.instructions
                        : '1. This is a closed-book test.\n2. No external help allowed.\n3. Each question has one correct answer.\n4. You cannot re-attempt after submission.',
                    style: GoogleFonts.poppins(fontSize: 13, height: 1.7, color: Colors.red.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'By starting this test, you agree to follow all the rules above. Once you submit, you cannot attempt again.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text('I Understand, Start Test', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onStart,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAKE TEST SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TakeTestScreen extends StatefulWidget {
  final OnlineTest test;
  final String studentName;
  const TakeTestScreen({super.key, required this.test, required this.studentName});

  @override
  State<TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<TakeTestScreen> {
  List<TestQuestion> _questions = [];
  Map<String, int> _answers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  late Timer _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.test.durationMinutes * 60;
    _loadQuestions();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _timer.cancel();
        _submitTest(forceSubmit: true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final result = await OnlineTestService.getTestQuestions(widget.test.id);
    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _questions = result['questions'] as List<TestQuestion>;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to load questions'), backgroundColor: Colors.red));
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _submitTest({bool forceSubmit = false}) async {
    if (!forceSubmit && _answers.length < _questions.length) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Submit Test?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('You have answered ${_answers.length} of ${_questions.length} questions. Unanswered questions will be marked wrong. Continue?',
              style: GoogleFonts.poppins(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);
    _timer.cancel();

    final answers = _questions.map((q) => {
      'questionId': q.id,
      'selectedIndex': _answers[q.id] ?? -1,
    }).toList();

    final result = await OnlineTestService.submitAttempt(
      testId: widget.test.id,
      studentName: widget.studentName,
      answers: answers,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (result['success'] == true) {
      final score = result['score'] as int;
      final total = result['totalQuestions'] as int;
      _showResultDialog(score, total);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Submission failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showResultDialog(int score, int total) {
    final pct = total > 0 ? (score / total * 100).round() : 0;
    final passed = pct >= 40;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              color: passed ? Colors.amber : Colors.red.shade400, size: 30),
          const SizedBox(width: 10),
          Text(passed ? 'Well Done!' : 'Test Submitted', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed ? Colors.green.shade50 : Colors.red.shade50,
              ),
              child: Center(
                child: Text('$pct%', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold,
                    color: passed ? Colors.green.shade600 : Colors.red.shade600)),
              ),
            ),
            const SizedBox(height: 16),
            Text('You scored $score out of $total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(passed ? 'Great job! Keep it up.' : 'Better luck next time.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // test screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back to Tests', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String get _timerText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.teal.shade600),
        body: const Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final isUrgent = _secondsLeft <= 60;

    return WillPopScope(
      onWillPop: () async {
        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Leave Test?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text('If you leave now, your progress will be lost and you cannot re-attempt.', style: GoogleFonts.poppins(fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        return leave == true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.teal.shade600,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(widget.test.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Icon(Icons.timer, size: 16, color: isUrgent ? Colors.white : Colors.white70),
                const SizedBox(width: 4),
                Text(_timerText, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.teal.shade600.withOpacity(0.07),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_answers.length}/${_questions.length} answered',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                  LinearProgressIndicator(
                    value: _questions.isEmpty ? 0 : _answers.length / _questions.length,
                    backgroundColor: Colors.teal.shade100,
                    color: Colors.teal.shade600,
                    minHeight: 6,
                  ).let((w) => SizedBox(width: 160, child: w)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _questions.length,
                itemBuilder: (_, i) => _buildQuestion(i, _questions[i]),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Test',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting ? null : () => _submitTest(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(int index, TestQuestion q) {
    final selected = _answers[q.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: selected != null ? Colors.teal.shade600 : Colors.grey.shade200,
                  child: Text('${index + 1}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: selected != null ? Colors.white : Colors.grey.shade600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(q.questionText, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, height: 1.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...List.generate(q.options.length, (oi) {
              final isSelected = selected == oi;
              return GestureDetector(
                onTap: () => setState(() => _answers[q.id] = oi),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.teal.shade600 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.teal.shade600 : Colors.grey.shade400, width: 2),
                          color: isSelected ? Colors.teal.shade600 : Colors.white,
                        ),
                        child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(q.options[oi], style: GoogleFonts.poppins(fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.teal.shade800 : Colors.black87)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
