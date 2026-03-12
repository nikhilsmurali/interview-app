import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  const apiKey = 'AIzaSyAJdmHv1nlTq1OIhXN_QFO5B_KhIj5RAtA';
  
  try {
    final model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: apiKey,
    );

    print('Testing Gemini API with gemini-pro');
    final content = [Content.text('Hello')];
    final response = await model.generateContent(content);
    
    if (response.text != null) {
      print('SUCCESS: ${response.text}');
    } else {
      print('FAILURE: Empty response');
    }
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}
