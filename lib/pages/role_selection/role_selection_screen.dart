import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _cardsController;
  late AnimationController _floatingController;

  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _studentCardFade;
  late Animation<Offset> _studentCardSlide;
  late Animation<double> _facultyCardFade;
  late Animation<Offset> _facultyCardSlide;
  late Animation<double> _floatingAnim;

  int? _hoveredCard; // 0 = student, 1 = faculty

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _studentCardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _cardsController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _studentCardSlide =
        Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _facultyCardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _cardsController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
      ),
    );

    _facultyCardSlide =
        Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _floatingAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    // Stagger the animations
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _cardsController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardsController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32), // deep green
              Color(0xFF43A047), // mid green
              Color(0xFF66BB6A), // light green
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative background circles
              _buildBackgroundDecor(),

              // Main content
              Column(
                children: [
                  const SizedBox(height: 50),

                  // Animated logo / icon
                  AnimatedBuilder(
                    animation: _floatingAnim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatingAnim.value),
                        child: child,
                      );
                    },
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFE8F5E9)],
                        ).createShader(bounds),
                        child: const Text(
                          "Campus Link",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Select your role to continue",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Student Card
                  FadeTransition(
                    opacity: _studentCardFade,
                    child: SlideTransition(
                      position: _studentCardSlide,
                      child: _buildRoleCard(
                        context,
                        index: 0,
                        icon: Icons.school_rounded,
                        title: "Student",
                        subtitle: "Access your courses and connect with peers",
                        accentColor: const Color(0xFF1B5E20),
                        // TODO: Role pass information here for student
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/login',
                          arguments: 'student',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Faculty Card
                  FadeTransition(
                    opacity: _facultyCardFade,
                    child: SlideTransition(
                      position: _facultyCardSlide,
                      child: _buildRoleCard(
                        context,
                        index: 1,
                        icon: Icons.people_alt_rounded,
                        title: "Faculty",
                        subtitle:
                            "Manage classes and communicate with students",
                        accentColor: const Color(0xFF004D40),
                         // TODO: Role pass information here for faculty
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/login',
                          arguments: 'faculty',
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bottom hint
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        "Tap a card to get started",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -60 + _floatingAnim.value * 0.5,
              right: -60,
              child: _glowCircle(180, Colors.white.withOpacity(0.06)),
            ),
            Positioned(
              top: 100 - _floatingAnim.value * 0.3,
              left: -80,
              child: _glowCircle(200, Colors.white.withOpacity(0.04)),
            ),
            Positioned(
              bottom: 80 + _floatingAnim.value * 0.4,
              right: -40,
              child: _glowCircle(150, Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              bottom: -30 - _floatingAnim.value * 0.2,
              left: 20,
              child: _glowCircle(120, Colors.white.withOpacity(0.04)),
            ),
          ],
        );
      },
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isHovered = _hoveredCard == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hoveredCard = index),
        onTapUp: (_) {
          setState(() => _hoveredCard = null);
          onTap();
        },
        onTapCancel: () => setState(() => _hoveredCard = null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..translate(0.0, isHovered ? 3.0 : 0.0),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFFF1F8E9) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(isHovered ? 0.25 : 0.15),
                blurRadius: isHovered ? 20 : 16,
                spreadRadius: isHovered ? 2 : 0,
                offset: Offset(0, isHovered ? 6 : 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF43A047), accentColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF43A047).withOpacity(0.4),
                      blurRadius: isHovered ? 16 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),

              const SizedBox(width: 20),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B2D1C),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Arrow
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()
                  ..translate(isHovered ? 4.0 : 0.0, 0.0),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: const Color(0xFF43A047),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
