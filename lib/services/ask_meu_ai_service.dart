import 'dart:convert';
import 'package:flutter/services.dart'; // Required for rootBundle
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AskMeuAIService {
  late GenerativeModel _model;
  late ChatSession _chatSession;
  bool _isInitialized = false;

  // We move the setup out of the constructor into an async init method
  Future<void> initializeService() async {
    if (_isInitialized) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not set in the .env file');
    }

    // 1. Load the CS Curriculum from the local JSON file
    final String jsonString = await rootBundle.loadString('assets/data/cs_curriculum.json');

    // 2. Inject it into the AI's brain
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system('''
        You are the official digital assistant for Ask Meu, the AI-powered application for Middle East University (MEU) in Amman, Jordan.
        
        CORE CONTEXT:
        - You help students with campus navigation, app issues, and academic planning.
        
        COMPUTER SCIENCE CURRICULUM DATA:
        Here is the official database of CS courses, descriptions, and prerequisites. Use this exact data to answer student questions about their degree plan:
        $jsonString
        
        RULES:
        1. If a student asks what they need to take before a specific class, look up the "prerequisites" in the JSON data.
        2. If a student asks what a course is about, summarize the "description" field.
        3. Keep answers concise, polite, and formatted with bullet points if listing multiple courses.
      '''),
    );

    _isInitialized = true;
  }

  void startSessionWithHistory(List<Map<String, String>> pastMessages) {
    if (!_isInitialized) throw Exception("Call initializeService() first!");

    List<Content> history = pastMessages.map((msg) {
      if (msg['role'] == 'user') {
        return Content.text(msg['text'] ?? '');
      } else {
        return Content.model([TextPart(msg['text'] ?? '')]);
      }
    }).toList();

    _chatSession = _model.startChat(history: history);
  }

  Future<String> sendMessage(String text) async {
    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      return response.text ?? "I'm sorry, I couldn't process that response.";
    } catch (e) {
      // ADD THIS PRINT STATEMENT so we can read the exact crash log!
      print('======================');
      print('GEMINI AI CRASH REPORT:');
      print(e.toString());
      print('======================');

      return "Network error. Please check your connection and try again.";
    }
  }
}