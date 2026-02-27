import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const RowingApp());
}

class RowingApp extends StatelessWidget {
  const RowingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        fontFamily: 'sans-serif',
      ),
      home: const OnboardingCarousel(),
    );
  }
}

// --- CONTROLLER PRINCIPAL ---
class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({super.key});

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final PageController _pageController = PageController();

  void _moveNext() {
    if (_pageController.page?.round() == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FeedScreen()),
      );
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _moveBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SplashScreen(onTimeout: _moveNext), // Frame 11
          AuthScreen(
            onLoginSuccess: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => const FeedScreen())),
            onRegisterStart: _moveNext,
          ), // Frame 12
          GenderScreen(onNext: _moveNext, onBack: _moveBack), // Frame 13
          AgePickerScreen(onNext: _moveNext, onBack: _moveBack), // Frame 14
          WeightPickerScreen(onNext: _moveNext, onBack: _moveBack), // Frame 15
        ],
      ),
    );
  }
}

// --- FRAME 11: LOADING ---
class SplashScreen extends StatefulWidget {
  final VoidCallback onTimeout;
  const SplashScreen({super.key, required this.onTimeout});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), widget.onTimeout);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE53935),
      body: Center(
        child: Icon(Icons.tsunami, size: 100, color: Colors.white),
      ),
    );
  }
}

// --- FRAME 12: LOGIN / REGISTER ---
class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onRegisterStart;
  const AuthScreen({super.key, required this.onLoginSuccess, required this.onRegisterStart});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF0D47A1)), // Bleu profond
          ClipPath(
            clipper: LoginClipper(),
            child: Container(color: const Color(0xFFE53935)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _authTab("Login", isLogin, () => setState(() => isLogin = true)),
                      const SizedBox(width: 20),
                      _authTab("Sign up", !isLogin, () => setState(() => isLogin = false)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    isLogin ? "Welcome Back.\nHUGO" : "Create Account.\nJOIN US",
                    style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  _buildTextField("Email:"),
                  _buildTextField("Password:", obscure: true),
                  const SizedBox(height: 30),
                  Center(
                    child: primaryButton(
                      isLogin ? "Sign In" : "Continue",
                      isLogin ? widget.onLoginSuccess : widget.onRegisterStart,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          decoration: active ? TextDecoration.underline : null,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {bool obscure = false}) {
    return TextField(
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
    );
  }
}

// --- FRAME 13: GENDER ---
class GenderScreen extends StatelessWidget {
  final VoidCallback onNext, onBack;
  const GenderScreen({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Tell us About Yourself", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          const Text("Gender", style: TextStyle(fontSize: 18, color: Colors.black54)),
          const SizedBox(height: 30),
          ...["Male", "Female", "Non-binary", "Prefer not to say"].map((g) => _genderOption(g)),
          const SizedBox(height: 50),
          _navigationRow(onBack, onNext),
        ],
      ),
    );
  }

  Widget _genderOption(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onNext,
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: const BorderSide(color: Colors.grey),
          ),
          child: Text(label, style: const TextStyle(color: Colors.black)),
        ),
      ),
    );
  }
}

// --- FRAMES 14 & 15: DYNAMIC PICKERS ---
class AgePickerScreen extends StatelessWidget {
  final VoidCallback onNext, onBack;
  const AgePickerScreen({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DynamicScalePicker(
      title: "How Old Are You",
      min: 12,
      max: 90,
      initial: 20,
      onNext: onNext,
      onBack: onBack,
    );
  }
}

class WeightPickerScreen extends StatelessWidget {
  final VoidCallback onNext, onBack;
  const WeightPickerScreen({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DynamicScalePicker(
      title: "What is your weight",
      min: 30,
      max: 200,
      initial: 70,
      unit: "kg",
      onNext: onNext,
      onBack: onBack,
    );
  }
}

class DynamicScalePicker extends StatefulWidget {
  final String title, unit;
  final int min, max, initial;
  final VoidCallback onNext, onBack;

  const DynamicScalePicker({
    super.key,
    required this.title,
    required this.min,
    required this.max,
    required this.initial,
    required this.onNext,
    required this.onBack,
    this.unit = "",
  });

  @override
  State<DynamicScalePicker> createState() => _DynamicScalePickerState();
}

class _DynamicScalePickerState extends State<DynamicScalePicker> {
  late FixedExtentScrollController _controller;
  double _currentScrollOffset = 0.0;
  final double itemHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _currentScrollOffset = (widget.initial - widget.min) * itemHeight;
    _controller = FixedExtentScrollController(initialItem: widget.initial - widget.min);
    _controller.addListener(() {
      setState(() {
        _currentScrollOffset = _controller.offset;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Column(
        children: [
          const SizedBox(height: 80),
          Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Les deux lignes rouges fixes
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 180, height: 2, color: Colors.red),
                    SizedBox(height: itemHeight),
                    Container(width: 180, height: 2, color: Colors.red),
                  ],
                ),
                ListWheelScrollView.useDelegate(
                  controller: _controller,
                  itemExtent: itemHeight,
                  physics: const FixedExtentScrollPhysics(),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: (widget.max - widget.min) + 1,
                    builder: (context, index) {
                      double itemPosition = index * itemHeight;
                      double distance = (itemPosition - _currentScrollOffset).abs();
                      
                      // howClose est à 1.0 au centre, et diminue en s'éloignant.
                      // On divise par itemHeight * 2 pour que le changement commence bien avant les lignes.
                      double howClose = 1.0 - (distance / (itemHeight * 2.0)).clamp(0.0, 1.0);

                      return Center(
                        child: Text(
                          "${widget.min + index}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''}",
                          style: TextStyle(
                            fontSize: 20 + (18 * howClose), // De 20 à 38
                            fontWeight: howClose > 0.7 ? FontWeight.w900 : (howClose > 0.4 ? FontWeight.bold : FontWeight.normal),
                            color: Colors.black.withOpacity(0.3 + (0.7 * howClose)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _navigationRow(widget.onBack, widget.onNext),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// --- FEED SCREEN (FINAL) ---
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Header Area
          const SliverToBoxAdapter(child: MainHeader()),
          
          // Weekly Summary Card
          const SliverToBoxAdapter(child: WeeklySummaryCard()),

          // The Feed List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Insert "Who to Follow" after the second post
                if (index == 2) return const WhoToFollowSection();
                return const ActivityPostCard();
              },
              childCount: 5,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.perm_identity), label: 'Perm Identity'),
        ],
      ),
    );
  }
}

class MainHeader extends StatelessWidget {
  const MainHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.network('https://cdn-icons-png.flaticon.com/512/2910/2910793.png', height: 40), // Placeholder logo
              Row(
                children: [
                  const Text('Home', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 15),
                  const Icon(Icons.notifications_none, color: Colors.red),
                  const SizedBox(width: 15),
                  const Icon(Icons.account_circle, color: Colors.red),
                  const SizedBox(width: 15),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: const [
              Text('Following', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.red, decorationThickness: 2)),
              SizedBox(width: 20),
              Text('You', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 20),
              Text('Discover', style: TextStyle(color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}
class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Summary', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Distance', style: TextStyle(color: Colors.white70)),
                    Text('48.9 km', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Activities', style: TextStyle(color: Colors.white70)),
                    Text('4', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                shape: const StadiumBorder(),
              ),
              child: const Text('View progress', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

class ActivityPostCard extends StatelessWidget {
  const ActivityPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.grey),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('My name is Hugo', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('2h ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.more_horiz),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text('Shit myself while rowing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              StatItem(label: 'Distance', value: '33.2km'),
              StatItem(label: 'Time', value: '1h 12m'),
              StatItem(label: 'Avg', value: '1h 12m'),
              StatItem(label: 'Split', value: '1h 12m'),
            ],
          ),
          const SizedBox(height: 15),
          // Map Placeholder
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
             
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.favorite_border, color: Colors.red),
              const SizedBox(width: 15),
              const Icon(Icons.chat_bubble_outline, color: Colors.red),
              const Spacer(),
              const Icon(Icons.share_outlined, color: Colors.red),
            ],
          )
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String label, value;
  const StatItem({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class WhoToFollowSection extends StatelessWidget {
  const WhoToFollowSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Who to Follow:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('See All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 5,
            itemBuilder: (context, index) => const FollowCard(),
          ),
        )
      ],
    );
  }
}

class FollowCard extends StatelessWidget {
  const FollowCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 15, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.grey),
          const SizedBox(height: 10),
          const Text('Peter McQualere', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('10 friends in common', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 30)),
            child: const Text('Follow', style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }
}


// --- COMPOSANTS REUTILISABLES ---

Widget _navigationRow(VoidCallback onBack, VoidCallback onNext) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onBack,
          child: const CircleAvatar(
            backgroundColor: Colors.black,
            radius: 25,
            child: Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        primaryButton("Next", onNext),
      ],
    ),
  );
}

Widget primaryButton(String text, VoidCallback onPressed) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFE53935),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
      elevation: 0,
    ),
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
      ],
    ),
  );
}

class LoginClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height * 0.75);
    path.lineTo(size.width, size.height * 0.6);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(oldClipper) => false;
}