import 'package:flutter/material.dart'; // 1. Changed to material.dart to fix debugPrint
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show rootBundle;

class AskMeuAIService {
  late GenerativeModel _model;
  late ChatSession _chat;

  static const String _baseSystemRules = '''
    You are the unified Ask MEU AI Assistant. You specialize in three areas:
    1. Academic Calendar & Dates
    2. Tuition and Financial Calculations
    3. Academic Advising & Schedule Selection

    IMPORTANT: Always respond to the user in the same language they use to ask their question. 
    If the user asks in Arabic, respond in clear, professional Arabic. 
    If they ask in English, respond in English.

    --- RULES ---
    Calendar: If a date is a range, mention both dates.
    
    Financial: 
    - Total Cost = (price_per_hour * Number of Credit Hours) + Registration Fee.
    - Registration Fee: 500 JOD (Regular Semester), 300 JOD (Summer).
    - If Tawjihi score, Major, or Credit Hours are missing, politely ask for them.
    - 0 JOD price for 98% and above only applies to Jordanian students.

    Advising:
    - Enforce Prerequisites Strictly.
    - Prioritize Bottleneck Courses (e.g., OOP C++, Data Structures).
    - Handle Corequisites: Automatically include mandatory labs.
    - Senior courses require 90+ hours.
  ''';

  Future<void> initializeService() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not set in the .env file');
    }

    final String calendarData = await rootBundle.loadString('assets/data/calendar.json');
    final String financialData = await rootBundle.loadString('assets/data/financial.json');
    final String curriculumData = await rootBundle.loadString('assets/data/cs_curriculum.json');

    final String finalSystemPrompt = '''
      $_baseSystemRules

      --- 1. ACADEMIC CALENDAR DATA ---
      $calendarData

      --- 2. FINANCIAL DATA ---
      $financialData

      --- 3. ACADEMIC ADVISING DATA ---
      $curriculumData
    ''';

    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // <-- Update this from 1.5 to 2.5
      apiKey: apiKey,
      systemInstruction: Content.system(finalSystemPrompt),
    );
  }

  void startSessionWithHistory(List<Map<String, String>> history) {
    List<Content> geminiHistory = history.map((msg) {
      if (msg['role'] == 'user') {
        return Content.text(msg['text'] ?? '');
      } else {
        return Content.model([TextPart(msg['text'] ?? '')]);
      }
    }).toList();

    _chat = _model.startChat(history: geminiHistory);
  }

  Future<String> sendMessage(String text) async {
    int retryCount = 0;
    const int maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final response = await _chat.sendMessage(Content.text(text));
        return response.text ?? 'عذراً، لم أتمكن من معالجة طلبك.';
      } catch (e) {
        retryCount++;
        debugPrint("=== Connection attempt $retryCount failed: $e ===");

        if (e.toString().contains('503') && retryCount < maxRetries) {
          // Wait 2 seconds before retrying to let the server spike pass
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        // If we exhausted all retries, show a clean user-friendly Arabic message
        return 'خوادم الخدمة مشغولة حالياً بسبب الضغط العالي. يرجى المحاولة مرة أخرى خلال ثوانٍ.';
      }
    }
    return 'عذراً، فشل الاتصال بخوادم الجامعة.';
  }
}