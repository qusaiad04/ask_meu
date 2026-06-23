// lib/main_shell.dart
import 'package:flutter/material.dart';

// Absolute package paths prevent any "URI doesn't exist" compilation issues
import 'package:ask_meu/features/chat/screens/ai_chat_screen.dart';
import 'package:ask_meu/features/map/screens/map_screen.dart';
import 'package:ask_meu/features/report/screens/report_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // REMOVED 'const' here because screens contain non-constant service initializations
  final List<Widget> _pages = [
    const AiChatScreen(),
    const MapScreen(),
    const ReportScreen(),
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