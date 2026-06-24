class ClassConfig {
  static const Map<String, String> colleges = {
    '1': 'Bombay Physical Culture Association College',
    '9': 'Akbar Peerbhoy College of Education',
    '10': 'M.H. Saboo Siddik College of Engineering',
    '11': 'Anand Vishwa Gurukul College',
    '12': 'B.N. Bandodkar College of Science',
    '13': 'Dr. Balasaheb Khardekar College',
    '14': 'Bal Bharati College',
    '16': 'Sant Gadge Maharaj College',
    '17': 'Bharati Vidyapeeth College of Engineering',
    '18': 'Bharati Vidyapeeth Institute of Management',
    '20': 'L.R. Tiwari College of Law',
    '21': 'Jeevandeep Law College',
    '22': 'B.N.N. College',
    '23': 'Birla College',
    '25': 'Bombay Teachers Training College',
    '28': 'Burhani College',
    '32': 'Chetana College',
    '45': 'Dr. Ambedkar College of Commerce & Economics',
    '57': 'Guru Nanak Khalsa College',
    '75': 'Guru Nanak College of Arts, Science & Commerce',
    '83': 'H.R. College of Commerce & Economics',
    '89': 'Jai Hind College',
    '104': 'K.C. College',
    '106': 'Kishinchand Chellaram College',
    '118': 'K.J. Somaiya College',
    '128': 'Lala Lajpatrai College',
    '135': 'M.L. Dahanukar College',
    '140': 'Mithibai College',
    '145': 'Nagindas Khandwala College',
    '161': 'Podar College',
    '170': 'Ramnarain Ruia College',
    '172': 'R.D. National College',
    '183': 'SIES College of Arts, Science & Commerce',
    '191': 'Sathaye College',
    '194': 'S.K. Somaiya College',
    '198': "St. Xavier's College",
    '202': 'Sydenham College',
    '210': 'Thakur College of Science & Commerce',
    '215': 'Tolani College',
    '221': 'Vaze College',
    '230': 'Wilson College',
    '3012': 'VJTI',
    '3184': 'Fr. Conceicao Rodrigues College of Engineering',
    '3185': 'VESIT',
    '3194': 'Vidyavardhini College of Engineering',
    '3199': 'D.J. Sanghvi College of Engineering',
    '3201': 'Rizvi College of Engineering',
    '3203': 'Atharva College of Engineering',
    '3208': 'Don Bosco Institute of Technology',
    '3211': 'SIES Graduate School of Technology',
    '3214': 'Xavier Institute of Engineering',
    '3215': 'Sardar Patel Institute of Technology',
    '3222': 'Thadomal Shahani Engineering College',
    '3225': 'Shah & Anchor Kutchhi Engineering College',
    '3228': 'Rajiv Gandhi Institute of Technology',
    '3230': 'St. Francis Institute of Technology',
    '3232': 'Vidyalankar Institute of Technology',
    '3235': 'K.J. Somaiya Institute of Technology',
    '3240': 'Fr. Agnel College of Engineering, Vashi',
    '3245': 'Terna Engineering College',
    '3250': 'Datta Meghe College of Engineering',
    '3252': 'Saraswati College of Engineering',
    '3254': 'Pillai College of Engineering',
    '3257': 'A.P. Shah Institute of Technology',
    '3260': 'Lokmanya Tilak College of Engineering',
    '3263': 'A.C. Patil College of Engineering',
    '3265': 'KC College of Engineering',
    '3268': 'Konkan Gyanpeeth College of Engineering',
    '3270': 'St. John College of Engineering',
    '3272': 'L.R. Tiwari College of Engineering',
    '3275': 'Bharat College of Engineering',
    '3278': 'B.R. Harne College of Engineering',
    '3280': 'Alamuri Ratnamala Institute of Engineering',
    '3282': 'Ideal Institute of Technology',
    '3285': 'Theem College of Engineering',
    '3288': 'Yadavrao Tasgaonkar Institute of Engineering',
    '3290': 'Dilkap Research Institute of Engineering',
  };

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
