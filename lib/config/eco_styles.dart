import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  
  static const Color primaryRed = Color(0xFF5A6A37); 
  static const Color accentBlue = Color(0xFFD47B39); 
  static const Color darkText = Color(0xFF3E3E3E); 
  static const Color lightText = Color(0xFF7B705A); 
  static const Color bgColor = Color(0xFFF4EED9); 
  static const Color cardBg = Color(0xFFFFFCF6); 

  
  static const Color plasticColor = Color(0xFF7BAE4F); 
  static const Color glassColor = Color(0xFFB5CFA0); 
  static const Color organicColor = Color(0xFF5A6A37); 
  static const Color paperColor = Color(0xFFF0C86E); 
  static const Color electronicColor = Color(0xFF9A6B47); 
  static const Color metalColor = Color(0xFF4E342E); 
  static const Color notWasteColor = Color(0xFF8B8C7A); 

  
  static const Color statusError = Color(0xFFD9534F); 
  static const Color statusSuccess = Color(0xFF7BAE4F); 
  static const Color statusInfo = Color(0xFFB88746); 
  static const Color statusWarning = Color(0xFFD47B39); 

  
  static final TextStyle headline1 = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: darkText,
  );

  static final TextStyle headline2 = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: darkText,
  );

  static final TextStyle subtitle = GoogleFonts.pacifico(
    fontSize: 14,
    color: lightText,
  );

  static final TextStyle bodyText = GoogleFonts.poppins(
    fontSize: 14,
    color: lightText,
  );

  static final TextStyle button = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}
