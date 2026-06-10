import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ask_meu/services/ask_meu_ai_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found or failed to load. AI features may not work.");
  }
  runApp(const AskMeuApp());
}

class AskMeuApp extends StatelessWidget {
  const AskMeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASK MEU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB22222),
          surface: Color(0xFF2A2A2A),
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AskMeuLogo(fontSize: 52),
              const SizedBox(height: 12),
              const Text(
                'MIDDLE EAST UNIVERSITY',
                style: TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// SHARED LOGO WIDGET
// ─────────────────────────────────────────
class AskMeuLogo extends StatelessWidget {
  final double fontSize;
  const AskMeuLogo({super.key, this.fontSize = 40});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'ASK ',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          TextSpan(
            text: 'MEU',
            style: TextStyle(
              color: const Color(0xFFB22222),
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _passController = TextEditingController();

  // 3. Add a loading state variable
  bool _isLoading = false;

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF888888), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFB22222), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // 4. Create the Firebase Sign-in method
  Future<void> _signIn() async {
    // Basic validation
    if (_idController.text.trim().isEmpty || _passController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Email/ID and Password.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Attempt sign in
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _idController.text.trim(),
        password: _passController.text.trim(),
      );

      // If successful and widget is still mounted, navigate
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on FirebaseAuthException catch (e) {
      // Handle Firebase specific errors
      String errorMessage = 'An unexpected error occurred.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errorMessage = 'No user found with those credentials.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email format is invalid.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFB22222),
          ),
        );
      }
    } finally {
      // Stop the loading indicator
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AskMeuLogo(fontSize: 44),
              const SizedBox(height: 60),
              TextField(
                controller: _idController,
                style: const TextStyle(color: Colors.white),
                // Note: Changed hint to indicate email is expected by Firebase Auth
                decoration: _inputDecoration('Student Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Student Password'),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  // 5. Connect the button to the sign-in method
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB22222),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFB22222).withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MAIN SHELL (Bottom Nav)
// ─────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    AiChatScreen(),
    MapScreen(),
    ReportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF232323),
          border: Border(
            top: BorderSide(color: Color(0xFF333333), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xFF666666),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline, size: 22),
              label: 'AI Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined, size: 22),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined, size: 22),
              label: 'Report',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// AI CHAT SCREEN
// ─────────────────────────────────────────
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AskMeuAIService _aiService = AskMeuAIService();
  bool _isLoading = false;

  // Start with an empty list. We will load saved messages in initState.
  final List<Map<String, String>> _messages = [];

  // Quick Action Chips definitions
  final List<String> _quickPrompts = [
    "Where is the IT Faculty?",
    "How do I report an issue?",
    "When are the midterm exams?",
    "Navigate to the library"
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  // --- PERSISTENCE: LOAD ---
  Future<void> _loadChatHistory() async {
    await _aiService.initializeService();

    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('ask_meu_chat_history');

    List<Map<String, String>> historyToLoad = [];

    if (savedData != null) {
      final List<dynamic> decoded = jsonDecode(savedData);
      historyToLoad = decoded.map((e) => Map<String, String>.from(e)).toList();
    }

    setState(() {
      _messages.addAll(historyToLoad);
    });

    // Ignite the AI's brain with the loaded history!
    _aiService.startSessionWithHistory(_messages);
    _scrollToBottom();
  }

  // --- PERSISTENCE: SAVE ---
  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ask_meu_chat_history', jsonEncode(_messages));
  }

  // --- SEND MESSAGE LOGIC ---
  void _sendMessage([String? chipText]) async {
    final text = chipText ?? _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      if (chipText == null) _msgController.clear();
      _isLoading = true;
    });

    _scrollToBottom();
    await _saveChatHistory(); // Save user message immediately

    // Call the real Gemini API
    String aiResponse = await _aiService.sendMessage(text);

    setState(() {
      _messages.add({
        'role': 'assistant',
        'text': aiResponse
      });
      _isLoading = false;
    });

    _scrollToBottom();
    await _saveChatHistory(); // Save AI message immediately
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- PERSISTENCE: CLEAR MEMORY ---
  Future<void> _clearChat() async {
    // 1. Wipe the local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ask_meu_chat_history');

    // 2. Clear the UI
    setState(() {
      _messages.clear();
    });

    // 3. Restart the AI's brain with a blank slate
    _aiService.startSessionWithHistory([]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        //const SizedBox(height: 56),
        // --- CUSTOM HEADER ---
        Container(
          padding: const EdgeInsets.only(top: 56, left: 24, right: 16, bottom: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(
              bottom: BorderSide(color: Color(0xFF333333), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ask Meu AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB22222)),
                tooltip: 'Clear Conversation',
                onPressed: () {
                  // Optional: You could wrap this in a showDialog to confirm first!
                  _clearChat();
                },
              ),
            ],
          ),
        ),

        // --- CHAT WINDOW ---
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) {
              final msg = _messages[i];
              final isUser = msg['role'] == 'user';

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF3A3A3A) : const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: isUser
                  // User gets normal Text
                      ? Text(
                    msg['text']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  )
                  // AI gets Markdown rendering
                      : MarkdownBody(
                    data: msg['text']!,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      listBullet: const TextStyle(color: Colors.white, fontSize: 14),
                      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // --- LOADING INDICATOR ---
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ask Meu AI is typing...',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),

        // --- QUICK ACTION CHIPS ---
        if (!_isLoading && _messages.length < 5) // Hide chips if bot is typing or chat gets long
          Container(
            width: double.infinity,
            color: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _quickPrompts.map((prompt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(
                        prompt,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      backgroundColor: const Color(0xFF2C2C2C),
                      side: const BorderSide(color: Color(0xFF333333)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () => _sendMessage(prompt),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // --- TEXT INPUT AREA ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF232323),
            border: Border(
              top: BorderSide(color: Color(0xFF333333), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  enabled: !_isLoading,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'What would you like to know?',
                    hintStyle: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isLoading ? const Color(0xFF555555) : const Color(0xFFB22222),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// MAP SCREEN
// ─────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 1. Define the relationship between buildings and their floors
  final Map<String, List<String>> _buildingData = {
    'B': ['Basement', '1'],
    'H': ['1', '2'],
    'N': ['1', '3'],
  };

  // 2. Set initial state
  String _selectedBuilding = 'B';
  String _selectedFloor = 'Basement';

  Widget _dropdownSection(
      String label, String sublabel, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            items: items
                .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(color: Colors.white)),
            ))
                .toList(),
            onChanged: onChanged,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF2C2C2C),
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Color(0xFF888888), size: 20),
            isDense: true,
            isExpanded: true, // Ensures the dropdown text doesn't overflow
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3. Dynamically generate the image path based on current selections
    // Example output: 'assets/images/map_B_Basement.png'
    String imagePath = 'assets/images/map_${_selectedBuilding}_$_selectedFloor.jpg';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdownSection(
                  'Building',
                  'Select the building',
                  _selectedBuilding,
                  _buildingData.keys.toList(),
                      (v) {
                    if (v != null) {
                      setState(() {
                        _selectedBuilding = v;
                        // Reset the floor to the first available floor of the new building
                        // to prevent errors if the old floor doesn't exist in the new building.
                        _selectedFloor = _buildingData[v]!.first;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _dropdownSection(
                  'Floor',
                  'Select the floor',
                  _selectedFloor,
                  _buildingData[_selectedBuilding]!, // Only show floors for selected building
                      (v) {
                    if (v != null) {
                      setState(() => _selectedFloor = v);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // 4. Use InteractiveViewer for zooming and panning the image
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        // 5. Add an error builder so the app doesn't crash if an image is missing
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              'Missing Image:\n$imagePath',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Building $_selectedBuilding  |  Floor $_selectedFloor',
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// REPORT SCREEN
// ─────────────────────────────────────────
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _descController = TextEditingController();

  // Variables optimized for Web and Mobile compatibility
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;

  // 1. Pick Image (Web Compatible)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // readAsBytes is required for Microsoft Edge / Web testing
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImage = pickedFile;
        _imageBytes = bytes;
      });
    }
  }


  // 2. Submit Report (Using Free ImgBB API)
  Future<void> _submitReport() async {
    final description = _descController.text.trim();

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a description.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final studentEmail = user?.email ?? 'Unknown Student';
      final studentId = studentEmail.split('@').first;

      String? imageUrl;

      // --- 1. IMGBB IMAGE UPLOAD ---
      if (_imageBytes != null) {
        // Convert the image bytes to a Base64 string for ImgBB
        final String base64Image = base64Encode(_imageBytes!);

        // Paste your ImgBB API Key here
        const String imgbbApiKey = 'db28fb2205195a52a7ef3bfee50a88ed';

        final imgbbUrl = Uri.parse('https://api.imgbb.com/1/upload');
        final imgbbResponse = await http.post(
          imgbbUrl,
          body: {
            'key': imgbbApiKey,
            'image': base64Image,
          },
        );

        if (imgbbResponse.statusCode == 200) {
          final jsonResponse = json.decode(imgbbResponse.body);
          // Extract the public URL from the ImgBB response
          imageUrl = jsonResponse['data']['url'];
        } else {
          throw Exception('Failed to upload image to ImgBB: ${imgbbResponse.body}');
        }
      }

      // --- 2. SAVE TO FIRESTORE (Still keeping text history in Firebase) ---
      await FirebaseFirestore.instance.collection('reports').add({
        'studentEmail': studentEmail,
        'studentId': studentId,
        'description': description,
        'imageUrl': imageUrl, // This is now the ImgBB link
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // --- 3. SEND EMAIL VIA EMAILJS ---
      final emailjsUrl = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final emailResponse = await http.post(
        emailjsUrl,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: json.encode({
          'service_id': 'service_p1e003j',
          'template_id': 'template_j7q5sv2',
          'user_id': 'bWX0R9UPlUN7m4G1T',
          'template_params': {
            'student_email': studentEmail,
            'student_id': studentId,
            'description': description,
            // Pass the ImgBB URL to the EmailJS template
            'image_url': imageUrl ?? 'https://via.placeholder.com/500x200?text=No+Image+Provided',
          }
        }),
      );

      if (emailResponse.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report sent successfully!'), backgroundColor: Colors.green),
          );
          _descController.clear();
          setState(() {
            _selectedImage = null;
            _imageBytes = null;
          });
        }
      } else {
        throw Exception('EmailJS Error: ${emailResponse.body}');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFB22222)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Problem',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Description Input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _descController,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Description',
                  hintStyle: TextStyle(color: Color(0xFF666666), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Image Picker Area
          GestureDetector(
            onTap: _pickImage,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF888888),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedImage != null
                        ? 'Image selected'
                        : 'Add picture (optional)',
                    style: TextStyle(
                      color: _selectedImage != null ? Colors.green : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_selectedImage != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => setState(() {
                      _selectedImage = null;
                      _imageBytes = null;
                    }),
                  )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB22222),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                disabledBackgroundColor: const Color(0xFFB22222).withOpacity(0.5),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                'Submit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}