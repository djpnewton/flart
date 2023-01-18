import 'package:flutter/material.dart';

class BasicScreen extends StatelessWidget {
  final Widget child;
  final String? title;

  const BasicScreen(this.child, {this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: title != null ? Text(title!) : null,
        ),
        body: child);
  }
}
