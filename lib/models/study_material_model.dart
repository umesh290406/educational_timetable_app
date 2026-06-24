class StudyMaterial {
  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String fileName;
  final String fileType;
  final String className;
  final String? section;
  final String? specialization;
  final String? college;
  final String teacherId;
  final String teacherName;
  final String createdAt;

  StudyMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.className,
    this.section,
    this.specialization,
    this.college,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      className: json['className'] ?? '',
      section: json['section'],
      specialization: json['specialization'],
      college: json['college'],
      teacherId: json['teacherId'] ?? '',
      teacherName: json['teacherName'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
