// lib/features/report/services/report_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> uploadToImgBB(Uint8List imageBytes) async {
    const String imgbbApiKey = 'db28fb2205195a52a7ef3bfee50a88ed';
    final String base64Image = base64Encode(imageBytes);

    final url = Uri.parse('https://api.imgbb.com/1/upload');
    final response = await http.post(url, body: {
      'key': imgbbApiKey,
      'image': base64Image,
    });

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['data']['url'];
    }
    throw Exception('Failed to upload image to ImgBB');
  }

  Future<void> sendReport({required String description, Uint8List? imageBytes}) async {
    final user = _auth.currentUser;
    final studentEmail = user?.email ?? 'Unknown Student';
    final studentId = studentEmail.split('@').first;
    String? imageUrl;

    if (imageBytes != null) {
      imageUrl = await uploadToImgBB(imageBytes);
    }

    await _firestore.collection('reports').add({
      'studentEmail': studentEmail,
      'studentId': studentId,
      'description': description,
      'imageUrl': imageUrl,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final emailjsUrl = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final emailResponse = await http.post(
      emailjsUrl,
      headers: {'Content-Type': 'application/json', 'origin': 'http://localhost'},
      body: json.encode({
        'service_id': 'service_p1e003j',
        'template_id': 'template_j7q5sv2',
        'user_id': 'bWX0R9UPlUN7m4G1T',
        'template_params': {
          'student_email': studentEmail,
          'student_id': studentId,
          'description': description,
          'image_url': imageUrl ?? 'https://via.placeholder.com/500x200?text=No+Image+Provided',
        }
      }),
    );

    if (emailResponse.statusCode != 200) {
      throw Exception('EmailJS deployment failed: ${emailResponse.body}');
    }
  }
}