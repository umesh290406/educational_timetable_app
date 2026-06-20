import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/captcha_widget.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaInputController = TextEditingController();
  String _selectedRole = 'student';
  String _expectedCaptcha = '';
  bool _captchaError = false;

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    _captchaInputController.dispose();
    super.dispose();
  }

  void _login(BuildContext context) async {
    if (_emailOrUsernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar(context, 'Please fill all fields', isError: true);
      return;
    }

    // Validate CAPTCHA (case-sensitive)
    if (_captchaInputController.text.trim() != _expectedCaptcha) {
      setState(() => _captchaError = true);
      _showSnackBar(context, 'Incorrect CAPTCHA. Please try again.', isError: true);
      _captchaInputController.clear();
      return;
    }

    setState(() => _captchaError = false);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      emailOrUsername: _emailOrUsernameController.text,
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (success) {
      if (mounted) {
        if (_selectedRole == 'student') {
          Navigator.of(context).pushReplacementNamed('/student');
        } else {
          Navigator.of(context).pushReplacementNamed('/teacher');
        }
      }
    } else {
      if (mounted) {
        _showSnackBar(context, authProvider.error ?? 'Login failed', isError: true);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade600, Colors.teal.shade400],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // ── Header ─────────────────────────────────────────────────
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
                          child: Icon(Icons.school, size: 50, color: Colors.teal.shade600),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Timetable Pro',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Login to Your Account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Role selector ──────────────────────────────────────────
                  Text('Select Role',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _roleButton('student', 'Student', Icons.school_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _roleButton('teacher', 'Teacher', Icons.person_outline)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Form card ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        CustomInputField(
                          label: 'Email or Username',
                          hint: 'Enter your email or username',
                          controller: _emailOrUsernameController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.person,
                        ),
                        const SizedBox(height: 20),
                        CustomInputField(
                          label: 'Password',
                          hint: 'Enter your password',
                          controller: _passwordController,
                          isPassword: true,
                          prefixIcon: Icons.lock,
                        ),
                        const SizedBox(height: 24),

                        // ── CAPTCHA ────────────────────────────────────────
                        CaptchaWidget(
                          onRefreshed: (newText) {
                            _expectedCaptcha = newText;
                            _captchaInputController.clear();
                            if (_captchaError) setState(() => _captchaError = false);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _captchaInputController,
                          style: GoogleFonts.poppins(fontSize: 14, letterSpacing: 2),
                          textCapitalization: TextCapitalization.none,
                          onChanged: (_) {
                            if (_captchaError) setState(() => _captchaError = false);
                          },
                          decoration: InputDecoration(
                            labelText: 'Enter the text above',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            hintText: 'Type exactly as shown (case-sensitive)',
                            hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
                            prefixIcon: Icon(
                              Icons.security,
                              color: _captchaError ? Colors.red : Colors.teal.shade600,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _captchaError ? Colors.red : Colors.grey.shade300,
                                width: _captchaError ? 2 : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _captchaError ? Colors.red : Colors.teal.shade600,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: _captchaError ? Colors.red.shade50 : Colors.grey.shade50,
                            errorText: _captchaError ? 'CAPTCHA mismatch — enter exactly as shown' : null,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Login button ───────────────────────────────────
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: authProvider.isLoading ? null : () => _login(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 20, width: 20,
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
                                            strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.login, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Text('Login',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Register link ──────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: GoogleFonts.poppins(color: Colors.white),
                          children: [
                            TextSpan(
                              text: 'Register',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? Colors.teal.shade600 : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.teal.shade600 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}