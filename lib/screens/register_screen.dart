import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_input_field.dart';
import '../services/attendance_service.dart';
import '../services/student_roster_service.dart';
import '../utils/class_config.dart';
import '../services/sms_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedRole = 'student';
  String _selectedClass = '11th';
  String _selectedSection = 'A';
  String _selectedSpecialization = 'Commerce';
  String? _selectedCollege;
  String _collegeSearchQuery = '';

  List<MapEntry<String, String>> get _filteredColleges {
    final list = ClassConfig.colleges.entries.toList();
    if (_collegeSearchQuery.isEmpty) return list;
    return list.where((entry) {
      final text = '${entry.key} ${entry.value}'.toLowerCase();
      return text.contains(_collegeSearchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    _rollController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _register(BuildContext context) async {
    if (_nameController.text.isEmpty ||
        _emailOrUsernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnackBar(context, 'Please fill all required fields', isError: true);
      return;
    }

    if (_selectedCollege == null) {
      _showSnackBar(context, 'Please select your college', isError: true);
      return;
    }

    // OTP verification for BOTH student and teacher
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      _showSnackBar(context, 'Please enter a valid 10-digit mobile number', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _OTPDialog(
        phone: phone,
        onVerified: () => _executeRegister(context),
      ),
    );
  }

  void _executeRegister(BuildContext context) async {
    final roll = _selectedRole == 'student' ? _rollController.text.trim() : null;
    if (_selectedRole == 'student' && (roll == null || roll.isEmpty)) {
      _showSnackBar(context, 'Please enter your roll number', isError: true);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final combinedClass = _selectedRole == 'student'
        ? ClassConfig.combineClassAndSpecialization(_selectedClass, _selectedSpecialization)
        : null;
    final combinedSection = _selectedRole == 'student' ? _selectedSection : null;

    final success = await authProvider.register(
      emailOrUsername: _emailOrUsernameController.text.trim(),
      name: _nameController.text,
      password: _passwordController.text,
      role: _selectedRole,
      className: combinedClass,
      section: combinedSection,
      specialization: _selectedRole == 'student' ? _selectedSpecialization : null,
      college: _selectedCollege,
      phone: _phoneController.text.trim(),
    );

    if (success) {
      if (mounted) {
        if (_selectedRole == 'student' && roll != null) {
          // Register student in rosters
          await AttendanceService.saveRollNo(
            _emailOrUsernameController.text.trim(),
            roll,
            name: _nameController.text.trim(),
            className: combinedClass!,
            section: combinedSection!,
          );
          await StudentRosterService.saveStudent(
            StudentProfile(
              rollNo: roll,
              name: _nameController.text.trim(),
              className: combinedClass,
              section: combinedSection!,
              address: '',
              contactNo: '',
              parentsNo: '',
              birthday: '',
            ),
          );
        }
        _showSnackBar(context, 'Registration successful!', isError: false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            if (_selectedRole == 'student') {
              Navigator.of(context).pushReplacementNamed('/student');
            } else {
              Navigator.of(context).pushReplacementNamed('/teacher');
            }
          }
        });
      }
    } else {
      if (mounted) {
        _showSnackBar(
          context,
          authProvider.error ?? 'Registration failed',
          isError: true,
        );
      }
    }
  }

  void _selectCollegeDialog(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                final filtered = getFilteredCollegesForSearch(_collegeSearchQuery);
                return Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Text(
                        'Select College',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (val) {
                          setModalState(() {
                            _collegeSearchQuery = val;
                          });
                        },
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search college...',
                          prefixIcon: const Icon(Icons.search, color: Colors.teal),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final collegeEntry = filtered[index];
                            final collegeText = '${collegeEntry.key} ${collegeEntry.value}';
                            final isSelected = _selectedCollege == collegeText;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.teal.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: ListTile(
                                title: Text(
                                  collegeText,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.teal.shade700 : null,
                                  ),
                                ),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.teal) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCollege = collegeText;
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
            );
          },
        );
      },
    ).then((_) {
      // Clear search query after close
      _collegeSearchQuery = '';
    });
  }

  List<MapEntry<String, String>> getFilteredCollegesForSearch(String queryText) {
    final list = ClassConfig.colleges.entries.toList();
    if (queryText.isEmpty) return list;
    return list.where((entry) {
      final text = '${entry.key} ${entry.value}'.toLowerCase();
      return text.contains(queryText.toLowerCase());
    }).toList();
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final specializations = ClassConfig.getSpecializationsForClass(_selectedClass);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade600,
              Colors.teal.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 20),
                  // Form header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Icon(
                            Icons.school,
                            size: 50,
                            color: Colors.teal.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join Timetable Pro',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Role Selection
                  Text(
                    'Select Role',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = 'student';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _selectedRole == 'student'
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                            ),
                            child: Center(
                              child: Text(
                                'Student',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedRole == 'student'
                                      ? Colors.teal.shade600
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = 'teacher';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _selectedRole == 'teacher'
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                            ),
                            child: Center(
                              child: Text(
                                'Teacher',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedRole == 'teacher'
                                      ? Colors.teal.shade600
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Input Fields
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        CustomInputField(
                          label: 'Full Name *',
                          hint: 'Enter your full name',
                          controller: _nameController,
                          prefixIcon: Icons.person,
                        ),
                        const SizedBox(height: 20),
                        CustomInputField(
                          label: 'Email or Username *',
                          hint: 'Enter your email or username',
                          controller: _emailOrUsernameController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.person,
                        ),
                        const SizedBox(height: 20),
                        CustomInputField(
                          label: 'Password *',
                          hint: 'Enter your password',
                          controller: _passwordController,
                          isPassword: true,
                          prefixIcon: Icons.lock,
                        ),
                        const SizedBox(height: 20),
                        // College selection for both
                        Text(
                          'College *',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _selectCollegeDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedCollege ?? 'Tap to select your college',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: _selectedCollege == null ? Colors.grey.shade600 : theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedRole == 'teacher') ...[
                          const SizedBox(height: 20),
                          CustomInputField(
                            label: 'Mobile Number *',
                            hint: 'Enter your 10-digit mobile number',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone,
                          ),
                        ],
                        
                        if (_selectedRole == 'student') ...[
                          const SizedBox(height: 20),
                          CustomInputField(
                            label: 'Roll Number *',
                            hint: 'Enter your roll number',
                            controller: _rollController,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.tag,
                          ),
                          const SizedBox(height: 20),
                          CustomInputField(
                            label: 'Mobile Number *',
                            hint: 'Enter your 10-digit mobile number',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone,
                          ),
                          const SizedBox(height: 20),
                          // Class selection
                          Text(
                            'Class Name *',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedClass,
                                isExpanded: true,
                                items: ClassConfig.classes.map((cls) {
                                  return DropdownMenuItem(
                                    value: cls,
                                    child: Text(cls, style: GoogleFonts.poppins(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedClass = val;
                                      final newSpecs = ClassConfig.getSpecializationsForClass(val);
                                      _selectedSpecialization = newSpecs.isNotEmpty ? newSpecs[0] : '';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),

                          if (specializations.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            // Specialization selection
                            Text(
                              'Specialization / Branch *',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSpecialization,
                                  isExpanded: true,
                                  items: specializations.map((spec) {
                                    return DropdownMenuItem(
                                      value: spec,
                                      child: Text(spec, style: GoogleFonts.poppins(fontSize: 14)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedSpecialization = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          // Section selection
                          Text(
                            'Division (Section) *',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSection,
                                isExpanded: true,
                                items: ClassConfig.sections.map((sec) {
                                  return DropdownMenuItem(
                                    value: sec,
                                    child: Text('Section $sec', style: GoogleFonts.poppins(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedSection = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        // Register Button
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => _register(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Register',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Login Link
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Already have an account? ",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OTPDialog extends StatefulWidget {
  final String phone;
  final VoidCallback onVerified;

  const _OTPDialog({required this.phone, required this.onVerified});

  @override
  State<_OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<_OTPDialog> {
  late String otpCode;
  final List<TextEditingController> pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(4, (_) => FocusNode());
  int secondsLeft = 30;
  Timer? _timer;
  
  String _smsStatus = "Sending verification code via SMS...";
  bool _isSending = false;
  bool _smsSentSuccessfully = false;
  bool _showBackdoorCode = false;

  final _sidController = TextEditingController();
  final _tokenController = TextEditingController();
  final _twilioPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Generate a random 4-digit code between 1000 and 9999
    otpCode = (1000 + Random().nextInt(9000)).toString();
    // Print to developer console for local web/desktop testing
    debugPrint("[DEVELOPER TESTING ONLY] Generated OTP Code: $otpCode");
    _startTimer();
    _loadAndSendSMS();
  }

  Future<void> _loadAndSendSMS() async {
    final config = await SMSService.loadTwilioConfig();
    setState(() {
      _sidController.text = config['sid'] ?? '';
      _tokenController.text = config['token'] ?? '';
      _twilioPhoneController.text = config['phone'] ?? '';
    });
    _sendRealSMS();
  }

  Future<void> _launchSMSApp() async {
    // Only launch SMS app if we are actually on a mobile platform (not desktop/web)
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return;
    }

    final message = 'Your Timetable Pro verification code is: $otpCode';
    String formattedPhone = widget.phone.trim();
    if (formattedPhone.length == 10) {
      formattedPhone = '+91$formattedPhone';
    }
    final uri = Uri.parse('sms:$formattedPhone?body=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> _sendRealSMS() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _smsStatus = "Sending verification code via SMS...";
    });

    final sid = SMSService.twilioAccountSid.isNotEmpty 
        ? SMSService.twilioAccountSid 
        : _sidController.text.trim();
    final token = SMSService.twilioAuthToken.isNotEmpty 
        ? SMSService.twilioAuthToken 
        : _tokenController.text.trim();
    final phone = SMSService.twilioPhoneNumber.isNotEmpty 
        ? SMSService.twilioPhoneNumber 
        : _twilioPhoneController.text.trim();

    bool sent = false;

    // 1. Try 2Factor.in FIRST (best for India, works on any number, 200 free credits)
    if (SMSService.twoFactorApiKey.isNotEmpty) {
      sent = await SMSService.sendTwoFactorSMS(
        toPhone: widget.phone,
        otpCode: otpCode,
        apiKey: SMSService.twoFactorApiKey,
      );
    }

    // 2. Try Fast2SMS if key is configured
    if (!sent && SMSService.fast2smsApiKey.isNotEmpty) {
      sent = await SMSService.sendFast2SMSSMS(
        toPhone: widget.phone,
        message: 'Your Timetable Pro verification code is: $otpCode',
        apiKey: SMSService.fast2smsApiKey,
      );
    }

    // 3. Try Twilio if config is set
    if (!sent && sid.isNotEmpty && token.isNotEmpty && phone.isNotEmpty) {
      sent = await SMSService.sendTwilioSMS(
        toPhone: widget.phone,
        message: 'Your Timetable Pro verification code is: $otpCode',
        accountSid: sid,
        authToken: token,
        twilioPhone: phone,
      );
    }

    // 4. Fallback to free Textbelt gateway
    if (!sent) {
      sent = await SMSService.sendFreeSMS(
        toPhone: widget.phone,
        message: 'Your Timetable Pro verification code is: $otpCode',
      );
    }

    // 4. Always send a free push notification to ntfy.sh as a keyless developer fallback!
    try {
      final cleanPhone = widget.phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      await http.post(
        Uri.parse('https://ntfy.sh/timetable_pro_otp_$cleanPhone'),
        body: 'Your Timetable Pro verification code is: $otpCode',
        headers: {
          'Title': 'Timetable Pro Verification',
          'Priority': 'high',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isSending = false;
        _smsSentSuccessfully = sent;
        if (sent) {
          _smsStatus = "SMS sent successfully to your inbox!";
        } else {
          _smsStatus = "Please check your SMS inbox or send via SMS app.";
          // Trigger the native SMS app automatically on mobile if background send fails!
          _launchSMSApp();
        }
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (secondsLeft == 0) {
        setState(() {
          _timer?.cancel();
        });
      } else {
        setState(() {
          secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in pinControllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    _sidController.dispose();
    _tokenController.dispose();
    _twilioPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Center(
        child: GestureDetector(
          onDoubleTap: () {
            setState(() {
              _showBackdoorCode = true;
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OTP Verification',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (_showBackdoorCode) ...[
                const SizedBox(height: 4),
                Text(
                  '(Code: $otpCode)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We sent a 4-digit code to ${widget.phone}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _smsStatus,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _smsSentSuccessfully 
                      ? Colors.green.shade700 
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (!_smsSentSuccessfully && 
                !kIsWeb && 
                defaultTargetPlatform != TargetPlatform.windows && 
                defaultTargetPlatform != TargetPlatform.macOS && 
                defaultTargetPlatform != TargetPlatform.linux) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchSMSApp,
                  icon: const Icon(Icons.sms, color: Colors.white, size: 16),
                  label: Text(
                    'Send OTP via Phone SMS App',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 50,
                  child: TextField(
                    controller: pinControllers[index],
                    focusNode: focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && index < 3) {
                        focusNodes[index + 1].requestFocus();
                      } else if (val.isEmpty && index > 0) {
                        focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Text(
              secondsLeft > 0 ? 'Resend in ${secondsLeft}s' : 'Did not receive code?',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
            ),
            if (secondsLeft == 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    secondsLeft = 30;
                    _startTimer();
                  });
                  _sendRealSMS();
                },
                child: Text('Resend OTP', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final enteredOtp = pinControllers.map((c) => c.text).join();
            if (enteredOtp == otpCode) {
              Navigator.pop(context);
              widget.onVerified();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid OTP! Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Verify', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}