import 'package:flutter/material.dart';

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