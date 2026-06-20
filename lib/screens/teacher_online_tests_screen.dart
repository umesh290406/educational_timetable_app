import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/online_test_model.dart';
import '../services/online_test_service.dart';
import '../providers/auth_provider.dart';
import '../utils/class_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER TESTS SCREEN  (list of tests + create)
// ─────────────────────────────────────────────────────────────────────────────
class TeacherOnlineTestsScreen extends StatefulWidget {
  const TeacherOnlineTestsScreen({super.key});

  @override
  State<TeacherOnlineTestsScreen> createState() => _TeacherOnlineTestsScreenState();
}

class _TeacherOnlineTestsScreenState extends State<TeacherOnlineTestsScreen> {
  List<OnlineTest> _tests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() => _isLoading = true);
    final tests = await OnlineTestService.getTeacherTests();
    if (mounted) setState(() { _tests = tests; _isLoading = false; });
  }

  Future<void> _deleteTest(String testId) async {
    final ok = await OnlineTestService.deleteTest(testId);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test deleted'), backgroundColor: Colors.red),
      );
      _loadTests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        title: Text('Online Tests',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTests,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal.shade600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Create Test',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateTestScreen()),
          );
          if (result == true) _loadTests();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _tests.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadTests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tests.length,
                    itemBuilder: (_, i) => _buildTestCard(_tests[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No tests yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Tap the button below to create your first online test.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildTestCard(OnlineTest test) {
    // Build a readable target string
    final parts = <String>[test.className];
    if (test.specialization != null && test.specialization!.isNotEmpty) parts.add(test.specialization!);
    if (test.section != null && test.section!.isNotEmpty) parts.add('Section ${test.section}');
    final targetLabel = parts.join(' › ');

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
                  backgroundColor: Colors.teal.shade50,
                  child: Icon(Icons.quiz, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(test.title,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(targetLabel,
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'attempts') {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TestAttemptsScreen(test: test),
                      ));
                    } else if (val == 'delete') {
                      _confirmDelete(test.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'attempts',
                      child: Row(children: [
                        Icon(Icons.people_alt_outlined, color: Colors.teal.shade700, size: 18),
                        const SizedBox(width: 10),
                        Text('View Attempts', style: GoogleFonts.poppins(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Text('Delete Test',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(Icons.timer_outlined, '${test.durationMinutes} min', Colors.orange),
                _chip(Icons.people_alt_outlined, '${test.attemptCount} attempted', Colors.blue),
                _chip(Icons.school_outlined, 'By ${test.teacherName}', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmDelete(String testId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Test?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'This will permanently delete the test and all student attempts.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _deleteTest(testId); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE TEST SCREEN  (with cascading Class → Specialization → Section)
// ─────────────────────────────────────────────────────────────────────────────
class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController(
    text: '1. This is a closed-book test. No notes or reference material allowed.\n'
        '2. Do not use any external help or communicate with others.\n'
        '3. Each question has only one correct answer.\n'
        '4. Once submitted, your answers cannot be changed.\n'
        '5. Complete the test within the given time limit.',
  );
  final _durationController = TextEditingController(text: '30');

  String _selectedClass = '11th';
  String _selectedSection = 'A';
  String? _selectedSpecialization;
  bool _isLoading = false;

  List<String> get _availableSpecializations =>
      ClassConfig.getSpecializationsForClass(_selectedClass);

  final List<_QuestionDraft> _questions = [_QuestionDraft()];

  @override
  void initState() {
    super.initState();
    // Set initial specialization
    final specs = ClassConfig.getSpecializationsForClass(_selectedClass);
    _selectedSpecialization = specs.isNotEmpty ? specs.first : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _durationController.dispose();
    for (final q in _questions) { q.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      _snack('Please enter a test title', isError: true); return;
    }
    final duration = int.tryParse(_durationController.text.trim());
    if (duration == null || duration <= 0) {
      _snack('Please enter a valid duration in minutes', isError: true); return;
    }
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.questionController.text.trim().isEmpty) {
        _snack('Question ${i + 1} is empty', isError: true); return;
      }
      if (q.options.any((o) => o.text.trim().isEmpty)) {
        _snack('All options for Question ${i + 1} must be filled', isError: true); return;
      }
      if (q.correctIndex == null) {
        _snack('Select the correct answer for Question ${i + 1}', isError: true); return;
      }
    }

    setState(() => _isLoading = true);

    final questions = _questions.map((q) => {
      'questionText': q.questionController.text.trim(),
      'options': q.options.map((o) => o.text.trim()).toList(),
      'correctOptionIndex': q.correctIndex!,
    }).toList();

    final result = await OnlineTestService.createTest(
      title: _titleController.text.trim(),
      instructions: _instructionsController.text.trim(),
      className: _selectedClass,
      section: _selectedSection,
      specialization: _selectedSpecialization,
      durationMinutes: duration,
      questions: questions,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Test published successfully!');
      Navigator.pop(context, true);
    } else {
      _snack(result['message'] ?? 'Failed to create test', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        title: Text('Create Online Test',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text('Publish',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Test Details', child: Column(
              children: [
                _field(_titleController, 'Test Title *', Icons.title),
                const SizedBox(height: 12),
                _field(_durationController, 'Duration (minutes) *', Icons.timer_outlined,
                    keyboardType: TextInputType.number),
              ],
            )),
            const SizedBox(height: 16),

            // ── TARGET CLASS (cascading) ──────────────────────────────────────
            _section('Target Audience', child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1: Class
                Text('Step 1 – Select Class',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                _dropdown(
                  label: 'Class',
                  value: _selectedClass,
                  items: ClassConfig.classes,
                  onChanged: (v) {
                    final specs = ClassConfig.getSpecializationsForClass(v!);
                    setState(() {
                      _selectedClass = v;
                      _selectedSpecialization = specs.isNotEmpty ? specs.first : null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Step 2: Specialization (only if available)
                if (_availableSpecializations.isNotEmpty) ...[
                  Text('Step 2 – Select Specialization / Branch',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSpecialization,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Specialization',
                      prefixIcon: Icon(Icons.category_outlined, color: Colors.teal.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _availableSpecializations
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSpecialization = v),
                  ),
                  const SizedBox(height: 16),
                  Text('Step 3 – Select Section',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                ] else ...[
                  Text('Step 2 – Select Section',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 8),
                _dropdown(
                  label: 'Section',
                  value: _selectedSection,
                  items: ClassConfig.sections,
                  onChanged: (v) => setState(() => _selectedSection = v!),
                ),

                const SizedBox(height: 12),
                // Preview pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_outlined, size: 15, color: Colors.teal.shade700),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _buildTargetLabel(),
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600,
                              color: Colors.teal.shade800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )),
            const SizedBox(height: 16),

            _section('Strict Instructions (shown to students before test)', child:
              TextField(
                controller: _instructionsController,
                maxLines: 8,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter test rules and instructions...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Questions (${_questions.length})',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add, color: Colors.teal),
                  label: Text('Add Question',
                      style: GoogleFonts.poppins(color: Colors.teal, fontWeight: FontWeight.bold)),
                  onPressed: () => setState(() => _questions.add(_QuestionDraft())),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_questions.length, (i) => _buildQuestionCard(i)),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _buildTargetLabel() {
    final parts = <String>[_selectedClass];
    if (_selectedSpecialization != null && _selectedSpecialization!.isNotEmpty) {
      parts.add(_selectedSpecialization!);
    }
    parts.add('Section $_selectedSection');
    return 'Target: ${parts.join(' › ')}';
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
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
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.teal.shade600,
                  child: Text('${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('Question ${index + 1}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                if (_questions.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => setState(() {
                      _questions[index].dispose();
                      _questions.removeAt(index);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: q.questionController,
              maxLines: 2,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter question text...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            Text('Options — tap ○ to mark correct answer:',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...List.generate(q.options.length, (oi) => _buildOptionRow(index, oi)),
            if (q.options.length < 5)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Colors.teal),
                label: Text('Add Option', style: GoogleFonts.poppins(fontSize: 12, color: Colors.teal)),
                onPressed: () => setState(() => q.options.add(TextEditingController())),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(int qi, int oi) {
    final q = _questions[qi];
    final isCorrect = q.correctIndex == oi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => q.correctIndex = oi),
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isCorrect ? Colors.teal.shade600 : Colors.grey.shade400, width: 2),
                color: isCorrect ? Colors.teal.shade600 : Colors.white,
              ),
              child: isCorrect ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: q.options[oi],
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Option ${String.fromCharCode(65 + oi)}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isCorrect ? Colors.teal.shade50 : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          if (q.options.length > 2)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
              onPressed: () => setState(() {
                q.options[oi].dispose();
                q.options.removeAt(oi);
                if (q.correctIndex == oi) q.correctIndex = null;
                else if (q.correctIndex != null && q.correctIndex! > oi) {
                  q.correctIndex = q.correctIndex! - 1;
                }
              }),
            ),
        ],
      ),
    );
  }

  Widget _section(String label, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e, style: GoogleFonts.poppins(fontSize: 13)),
          )).toList(),
      onChanged: onChanged,
    );
  }
}

class _QuestionDraft {
  final questionController = TextEditingController();
  final List<TextEditingController> options = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int? correctIndex;

  void dispose() {
    questionController.dispose();
    for (final o in options) o.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST ATTEMPTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TestAttemptsScreen extends StatefulWidget {
  final OnlineTest test;
  const TestAttemptsScreen({super.key, required this.test});

  @override
  State<TestAttemptsScreen> createState() => _TestAttemptsScreenState();
}

class _TestAttemptsScreenState extends State<TestAttemptsScreen> {
  List<TestAttempt> _attempts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final attempts = await OnlineTestService.getTestAttempts(widget.test.id);
    if (mounted) setState(() { _attempts = attempts; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attempts', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17)),
            Text(widget.test.title,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _attempts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No attempts yet',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text('Students haven\'t attempted this test yet.',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.teal.shade600.withOpacity(0.07),
                      child: Row(
                        children: [
                          Icon(Icons.bar_chart, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '${_attempts.length} student${_attempts.length == 1 ? '' : 's'} attempted',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.teal.shade800),
                          ),
                          const Spacer(),
                          Text(
                            'Avg: ${(_attempts.map((a) => a.score).reduce((a, b) => a + b) / _attempts.length).toStringAsFixed(1)}/${_attempts[0].totalQuestions}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _attempts.length,
                        itemBuilder: (_, i) {
                          final a = _attempts[i];
                          final pct = a.totalQuestions > 0 ? a.score / a.totalQuestions : 0.0;
                          final color = pct >= 0.7
                              ? Colors.green
                              : pct >= 0.4
                                  ? Colors.orange
                                  : Colors.red;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.15),
                                child: Text(
                                  '${(pct * 100).round()}%',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                              title: Text(a.studentName,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                a.completedAt.isNotEmpty
                                    ? 'Submitted: ${a.completedAt.substring(0, 10)}'
                                    : 'Submitted',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${a.score}/${a.totalQuestions}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
