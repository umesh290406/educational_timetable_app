class OnlineTest {
  final String id;
  final String title;
  final String instructions;
  final String className;
  final String? section;
  final String? specialization;
  final int durationMinutes;
  final String teacherId;
  final String teacherName;
  final String createdAt;
  final int attemptCount;
  final bool attempted;
  final int? score;
  final int? totalQuestions;

  OnlineTest({
    required this.id,
    required this.title,
    required this.instructions,
    required this.className,
    this.section,
    this.specialization,
    required this.durationMinutes,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
    this.attemptCount = 0,
    this.attempted = false,
    this.score,
    this.totalQuestions,
  });

  factory OnlineTest.fromJson(Map<String, dynamic> json) {
    return OnlineTest(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      instructions: json['instructions'] ?? '',
      className: json['className'] ?? '',
      section: json['section'],
      specialization: json['specialization'],
      durationMinutes: int.tryParse(json['durationMinutes']?.toString() ?? '30') ?? 30,
      teacherId: json['teacherId'] ?? '',
      teacherName: json['teacherName'] ?? '',
      createdAt: json['createdAt'] ?? '',
      attemptCount: int.tryParse(json['attempt_count']?.toString() ?? '0') ?? 0,
      attempted: json['attempted'] == true || json['attempted'] == 'true',
      score: json['score'] != null ? int.tryParse(json['score'].toString()) : null,
      totalQuestions: json['totalQuestions'] != null ? int.tryParse(json['totalQuestions'].toString()) : null,
    );
  }
}

class TestQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int? correctOptionIndex; // null for students

  TestQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    this.correctOptionIndex,
  });

  factory TestQuestion.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    List<String> optionList = [];
    if (opts is List) {
      optionList = opts.map((e) => e.toString()).toList();
    }
    return TestQuestion(
      id: json['id'] ?? '',
      questionText: json['questionText'] ?? '',
      options: optionList,
      correctOptionIndex: json['correctOptionIndex'] != null
          ? int.tryParse(json['correctOptionIndex'].toString())
          : null,
    );
  }
}

class TestAttempt {
  final String id;
  final String testId;
  final String studentId;
  final String studentName;
  final int score;
  final int totalQuestions;
  final String completedAt;

  TestAttempt({
    required this.id,
    required this.testId,
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
  });

  factory TestAttempt.fromJson(Map<String, dynamic> json) {
    return TestAttempt(
      id: json['id'] ?? '',
      testId: json['testId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      score: int.tryParse(json['score']?.toString() ?? '0') ?? 0,
      totalQuestions: int.tryParse(json['totalQuestions']?.toString() ?? '0') ?? 0,
      completedAt: json['completedAt'] ?? '',
    );
  }
}
