import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static final String geminiKey = dotenv.env['GEMINI_KEY'] ?? '';
  static final String mapTilerKey = dotenv.env['MAPTILER_KEY'] ?? '';
}