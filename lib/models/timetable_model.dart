class Timetable {
  final String id;
  final String subjectName;
  final String teacherName;
  final String className;
  final String section;
  final String day; // Monday, Tuesday, etc
  final String startTime; // 10:00
  final String endTime; // 11:00
  final String roomNumber;
  final bool isCancelled;
  final String? cancellationReason;
  final String createdAt;

  Timetable({
    required this.id,
    required this.subjectName,
    required this.teacherName,
    required this.className,
    required this.section,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.roomNumber,
    this.isCancelled = false,
    this.cancellationReason,
    required this.createdAt,
  });

  factory Timetable.fromJson(Map<String, dynamic> json) {
    return Timetable(
      id: json['id'] ?? json['_id'] ?? '',
      subjectName: json['subjectName'] ?? '',
      teacherName: json['teacherName'] ?? '',
      className: json['className'] ?? '',
      section: json['section'] ?? '',
      day: json['day'] ?? 'Monday',
      startTime: json['startTime'] ?? '10:00',
      endTime: json['endTime'] ?? '11:00',
      roomNumber: json['roomNumber'] ?? '',
      isCancelled: json['isCancelled'] == true || json['isCancelled'] == 1,
      cancellationReason: json['cancellationReason'],
      createdAt: json['createdAt'] ?? DateTime.now().toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectName': subjectName,
      'teacherName': teacherName,
      'className': className,
      'section': section,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'roomNumber': roomNumber,
      'isCancelled': isCancelled,
      'cancellationReason': cancellationReason,
      'createdAt': createdAt,
    };
  }
}