import 'package:flutter/material.dart';

class GenerateMcq extends StatefulWidget {
  const GenerateMcq({super.key});

  @override
  State<GenerateMcq> createState() => _GenerateMcqState();
}

class _GenerateMcqState extends State<GenerateMcq> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate MCQ'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'This is the Generate MCQ page',
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}