class Lecture {
  final String id;
  final String subjectName;
  final String teacherName;
  final String className;
  final String? section;
  final String startTime;
  final String endTime;
  final String? roomNumber;
  final DateTime lectureDate;
  final bool isCancelled;
  final String? cancellationReason;

  Lecture({
    required this.id,
    required this.subjectName,
    required this.teacherName,
    required this.className,
    this.section,
    required this.startTime,
    required this.endTime,
    this.roomNumber,
    required this.lectureDate,
    this.isCancelled = false,
    this.cancellationReason,
  });

  factory Lecture.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['lectureDate'] ?? DateTime.now().toString());
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return Lecture(
      id: json['_id'] ?? json['id'] ?? '',
      subjectName: json['subjectName'] ?? '',
      teacherName: json['teacherName'] ?? '',
      className: json['className'] ?? '',
      section: json['section'],
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '00:00',
      roomNumber: json['roomNumber'],
      lectureDate: parsedDate,
      isCancelled: json['isCancelled'] ?? false,
      cancellationReason: json['cancellationReason'],
    );
  }
}