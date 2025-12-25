import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin_web/providers/auth_provider.dart';
import 'package:admin_web/screens/signup_screen.dart';
import 'package:admin_web/screens/tv_connection_screen.dart';
import 'package:admin_web/screens/admin_dashboard.dart';
import 'package:admin_web/utils/admin_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _masjidNameController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showTVConnection = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _masjidNameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _masjidNameController.text.trim(),
      );
      
      // Login successful - navigate to Admin Dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AdminDashboard(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: AdminTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToTVConnection() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const TVConnectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SignupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AdminTheme.primaryBlueLight.withOpacity(0.05),
              AdminTheme.primaryBlue.withOpacity(0.03),
              AdminTheme.backgroundBlueLight.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AdminTheme.primaryBlueLight.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AdminTheme.primaryBlue.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              child: SizedBox(
                height: size.height,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : size.width * 0.1,
                  ),
                  child: Row(
                    children: [
                      // Left side - Brand/Info (Desktop only)
                      if (!isMobile) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Logo and Brand
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: AdminTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AdminTheme.primaryBlueLight.withOpacity(0.3),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.mosque,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Our Masjid App',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: AdminTheme.textPrimary,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 40),
                                    const Text(
                                      'Welcome to\nOur Masjid App',
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        color: AdminTheme.textPrimary,
                                        height: 1.1,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Modern mosque management platform for announcements, prayer times, and TV displays.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: AdminTheme.textMuted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // Features
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFeature(
                                      icon: Icons.tv,
                                      title: 'TV Display',
                                      description: 'Show announcements & prayer times on multiple TVs',
                                    ),
                                    const SizedBox(height: 24),
                                    _buildFeature(
                                      icon: Icons.schedule,
                                      title: 'Smart Prayer Times',
                                      description: 'Automatic calculations with multiple methods',
                                    ),
                                    const SizedBox(height: 24),
                                    _buildFeature(
                                      icon: Icons.announcement,
                                      title: 'Digital Announcements',
                                      description: 'Manage and schedule announcements easily',
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // TV Connection Button
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: MouseRegion(
                                    onEnter: (_) => setState(() => _showTVConnection = true),
                                    onExit: (_) => setState(() => _showTVConnection = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      transform: Matrix4.translationValues(
                                        _showTVConnection ? -5 : 0,
                                        0,
                                        0,
                                      ),
                                      child: OutlinedButton.icon(
                                        onPressed: _navigateToTVConnection,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          side: BorderSide(
                                            color: AdminTheme.primaryBlueLight.withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.tv,
                                          color: AdminTheme.primaryBlue,
                                          size: 20,
                                        ),
                                        label: const Text(
                                          'Connect TV Display',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AdminTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],

                      // Right side - Login Form
                      Expanded(
                        flex: isMobile ? 1 : 1,
                        child: Center(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? 400 : 480,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Mobile Header
                                if (isMobile) ...[
                                  Column(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          gradient: AdminTheme.primaryGradient,
                                          borderRadius: BorderRadius.circular(18),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AdminTheme.primaryBlueLight.withOpacity(0.3),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.mosque,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Our Masjid App',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: AdminTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Sign in to your account',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                ],

                                // Login Card
                                Material(
                                  elevation: 24,
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white,
                                  shadowColor: Colors.black.withOpacity(0.1),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(40),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Desktop Form Header
                                          if (!isMobile) ...[
                                            const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w800,
                                                color: AdminTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Enter your details to continue',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: AdminTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 32),
                                          ],

                                          // Masjid Name
                                          _buildTextField(
                                            controller: _masjidNameController,
                                            label: 'Masjid Name',
                                            hint: 'Enter your masjid name',
                                            icon: Icons.mosque_outlined,
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter masjid name';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // Email
                                          _buildTextField(
                                            controller: _emailController,
                                            label: 'Email Address',
                                            hint: 'you@example.com',
                                            icon: Icons.email_outlined,
                                            keyboardType: TextInputType.emailAddress,
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter your email';
                                              }
                                              if (!value.contains('@') || !value.contains('.')) {
                                                return 'Please enter a valid email';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // Password
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Password',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AdminTheme.textSubtle,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                controller: _passwordController,
                                                obscureText: !_showPassword,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: AdminTheme.textPrimary,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: 'Enter your password',
                                                  hintStyle: TextStyle(color: Colors.grey.shade400),
                                                  filled: true,
                                                  fillColor: Colors.grey.shade50,
                                                  prefixIcon: Icon(
                                                    Icons.lock_outline,
                                                    color: Colors.grey.shade500,
                                                    size: 20,
                                                  ),
                                                  suffixIcon: IconButton(
                                                    icon: Icon(
                                                      _showPassword ? Icons.visibility_off : Icons.visibility,
                                                      color: Colors.grey.shade500,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _showPassword = !_showPassword;
                                                      });
                                                    },
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: const BorderSide(
                                                      color: AdminTheme.primaryBlueLight,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  errorBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: const BorderSide(
                                                      color: Colors.red,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 18,
                                                  ),
                                                ),
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) {
                                                    return 'Please enter your password';
                                                  }
                                                  if (value.length < 6) {
                                                    return 'Password must be at least 6 characters';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),

                                          // Forgot Password
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () {},
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: const Text(
                                                'Forgot Password?',
                                                style: TextStyle(
                                                  color: AdminTheme.primaryBlue,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Sign In Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 56,
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _login,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AdminTheme.primaryBlue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                elevation: 0,
                                                shadowColor: Colors.transparent,
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                                      ),
                                                    )
                                                  : const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          'Sign In',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Icon(Icons.arrow_forward, size: 20),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 32),

                                          // Divider
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                child: Text(
                                                  'or',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 32),

                                          // Sign Up Link
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Don't have an account? ",
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: _isLoading ? null : _navigateToSignup,
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                child: const Text(
                                                  'Sign up',
                                                  style: TextStyle(
                                                    color: AdminTheme.primaryBlue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // TV Connection Button for Mobile
                                          if (isMobile) ...[
                                            const SizedBox(height: 32),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: _navigateToTVConnection,
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    side: BorderSide(
                                                      color: AdminTheme.borderLight,
                                                    ),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.tv,
                                                  color: AdminTheme.primaryBlue,
                                                  size: 20,
                                                ),
                                                label: const Text(
                                                  'Connect TV Display',
                                                  style: TextStyle(
                                                    color: AdminTheme.primaryBlue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Mobile Footer
                                if (isMobile) ...[
                                  const SizedBox(height: 40),
                                  Text(
                                    '© 2025 Our Masjid App. All rights reserved.',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AdminTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            color: AdminTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AdminTheme.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: AdminTheme.backgroundSection,
            prefixIcon: Icon(
              icon,
              color: AdminTheme.textMuted,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AdminTheme.primaryBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AdminTheme.accentRed,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AdminTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: AdminTheme.primaryBlue,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AdminTheme.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
