class ClassConfig {
  static const List<String> classes = [
    '11th',
    '12th',
    'Diploma-1',
    'Diploma-2',
    'Diploma-3',
    'FE',
    'SE',
    'TE',
    'BE',
  ];

  static const List<String> sections = ['A', 'B', 'C', 'D', 'E'];

  static List<String> getSpecializationsForClass(String className) {
    if (className == '11th' || className == '12th') {
      return ['Commerce', 'Arts', 'Science'];
    }
    if (className.startsWith('Diploma-')) {
      return [
        'Diploma in Computer Engineering',
        'Diploma in Information Technology (IT)',
        'Diploma in Mechanical Engineering',
        'Diploma in Civil Engineering',
        'Diploma in Electrical Engineering',
        'Diploma in Electronics & Telecommunication Engineering',
        'Diploma in Automobile Engineering',
        'Diploma in Artificial Intelligence & Machine Learning (AI & ML)',
        'Diploma in Cyber Security',
        'Diploma in Data Science',
      ];
    }
    if (['FE', 'SE', 'TE', 'BE'].contains(className)) {
      return [
        'B.E. (Bachelor of Engineering)',
        'B.Tech (Bachelor of Technology)',
        'BCA (Bachelor of Computer Applications)',
        'B.Sc. (Bachelor of Science)',
        'B.Com (Bachelor of Commerce)',
        'BBA (Bachelor of Business Administration)',
        'BMS (Bachelor of Management Studies)',
        'B.A. (Bachelor of Arts)',
        'MBBS (Bachelor of Medicine and Bachelor of Surgery)',
        'BDS (Bachelor of Dental Surgery)',
        'BAMS (Bachelor of Ayurvedic Medicine and Surgery)',
        'BHMS (Bachelor of Homeopathic Medicine and Surgery)',
        'B.Pharm (Bachelor of Pharmacy)',
      ];
    }
    return [];
  }

  // Parse combined string (e.g. "11th - Science" -> {"class": "11th", "specialization": "Science"})
  static Map<String, String> parseClassAndSpecialization(String? combined) {
    if (combined == null || combined.isEmpty) {
      return {'class': '11th', 'specialization': 'Commerce'};
    }
    final parts = combined.split(' - ');
    if (parts.length >= 2) {
      return {
        'class': parts[0].trim(),
        'specialization': parts.sublist(1).join(' - ').trim(),
      };
    }
    // Fallback if it's just class without specialization
    final cls = parts[0].trim();
    final specs = getSpecializationsForClass(cls);
    return {
      'class': cls,
      'specialization': specs.isNotEmpty ? specs[0] : '',
    };
  }

  // Combine class and specialization
  static String combineClassAndSpecialization(String className, String specialization) {
    if (specialization.isEmpty) return className;
    return '$className - $specialization';
  }
}
