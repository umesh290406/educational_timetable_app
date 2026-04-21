class NotificationModel {
  final String id;
  final String studentId;
  final String? lectureId;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.studentId,
    this.lectureId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      lectureId: json['lectureId'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      notificationType: json['notificationType'] ?? 'reminder',
      isRead: json['isRead'] == true || json['isRead'] == 1,
      createdAt: json['createdAt'] ?? DateTime.now().toString(),
    );
  }
}