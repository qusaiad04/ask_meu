import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/ask_meu_ai_service.dart';
import '../../auth/screens/login_screen.dart';

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
  final List<Map<String, String>> _messages = [];

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

  Future<void> _loadChatHistory() async {
    await _aiService.initializeService();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('ask_meu_chat_history_${user.uid}');

    List<Map<String, String>> historyToLoad = [];
    if (savedData != null) {
      final List<dynamic> decoded = jsonDecode(savedData);
      historyToLoad = decoded.map((e) => Map<String, String>.from(e)).toList();
    }

    setState(() {
      _messages.clear();
      _messages.addAll(historyToLoad);
    });

    _aiService.startSessionWithHistory(_messages);
    _scrollToBottom();
  }

  Future<void> _saveChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ask_meu_chat_history_${user.uid}', jsonEncode(_messages));
  }

  void _sendMessage([String? chipText]) async {
    final text = chipText ?? _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      if (chipText == null) _msgController.clear();
      _isLoading = true;
    });

    _scrollToBottom();
    await _saveChatHistory();

    String aiResponse = await _aiService.sendMessage(text);

    setState(() {
      _messages.add({'role': 'assistant', 'text': aiResponse});
      _isLoading = false;
    });

    _scrollToBottom();
    await _saveChatHistory();
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

  Future<void> _clearChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ask_meu_chat_history_${user.uid}');

    setState(() => _messages.clear());
    _aiService.startSessionWithHistory([]);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 56, left: 24, right: 16, bottom: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ask Meu AI', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFB22222)), tooltip: 'Clear Conversation', onPressed: _clearChat),
                  IconButton(icon: const Icon(Icons.logout, color: Colors.white), tooltip: 'Logout', onPressed: _logout),
                ],
              ),
            ],
          ),
        ),
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
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                      ? Text(msg['text']!, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))
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
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Ask Meu AI is typing...', style: TextStyle(color: Color(0xFF666666), fontSize: 12, fontStyle: FontStyle.italic))),
          ),
        if (!_isLoading && _messages.length < 5)
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
                      label: Text(prompt, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      backgroundColor: const Color(0xFF2C2C2C),
                      side: const BorderSide(color: Color(0xFF333333)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () => _sendMessage(prompt),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF232323),
            border: Border(top: BorderSide(color: Color(0xFF333333), width: 0.5)),
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
                    hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _isLoading ? const Color(0xFF555555) : const Color(0xFFB22222), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}