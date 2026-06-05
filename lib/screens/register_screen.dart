import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_input_field.dart';
import '../services/attendance_service.dart';
import '../services/student_roster_service.dart';
import '../utils/class_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollController = TextEditingController();
  final _collegeCodeController = TextEditingController();
  
  String _selectedRole = 'student';
  String _selectedClass = '11th';
  String _selectedSection = 'A';
  String _selectedSpecialization = 'Commerce';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rollController.dispose();
    _collegeCodeController.dispose();
    super.dispose();
  }

  void _register(BuildContext context) async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnackBar(context, 'Please fill all required fields', isError: true);
      return;
    }

    if (_selectedRole == 'teacher') {
      final code = _collegeCodeController.text.trim().toUpperCase();
      if (code != 'UMESH2904' && code != 'SHREYAS29') {
        _showSnackBar(context, 'Invalid College Code! Account creation restricted.', isError: true);
        return;
      }
    }

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
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      role: _selectedRole,
      className: combinedClass,
      section: combinedSection,
      specialization: _selectedRole == 'student' ? _selectedSpecialization : null,
    );

    if (success) {
      if (mounted) {
        if (_selectedRole == 'student' && roll != null) {
          // Register student in rosters
          await AttendanceService.saveRollNo(
            _emailController.text.trim(),
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

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
                          label: 'Email Address *',
                          hint: 'Enter your email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email,
                        ),
                        const SizedBox(height: 20),
                        CustomInputField(
                          label: 'Password *',
                          hint: 'Enter your password',
                          controller: _passwordController,
                          isPassword: true,
                          prefixIcon: Icons.lock,
                        ),
                        if (_selectedRole == 'teacher') ...[
                          const SizedBox(height: 20),
                          CustomInputField(
                            label: 'College Code *',
                            hint: 'Enter teacher verification code',
                            controller: _collegeCodeController,
                            prefixIcon: Icons.security,
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
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context).pop();
                              },
                          ),
                        ],
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