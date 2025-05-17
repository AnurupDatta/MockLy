import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mcq/saved_notes.dart';

// Use the same theme as mcq_page.dart
class AppTheme {
  static const Color primaryRed = Color(0xFFE63946);
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color cardBackground = Color(0xFF2D2D2D);
  static const Color accentRed = Color(0xFFFF4B4B);
  static const Color textLight = Color(0xFFF1F1F1);
  static const Color textGrey = Color(0xFFB0B0B0);
}

class GenerateMcq extends StatefulWidget {
  const GenerateMcq({super.key});

  @override
  State<GenerateMcq> createState() => _GenerateMcqState();
}

class _GenerateMcqState extends State<GenerateMcq> {
  bool _isLoading = false;
  String _pdfText = '';
  String _fileName = '';
  List<MCQQuestion> _questions = [];

  Future<void> _pickPDF() async {
    setState(() {
      _isLoading = true;
      _questions = [];
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        _fileName = result.files.single.name;

        // Extract text from PDF
        _pdfText = await _extractTextFromPDF(file);

        // Generate MCQs using Gemini API
        await _generateMCQs();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _extractTextFromPDF(File file) async {
    PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
    String text = '';
    for (int i = 0; i < document.pages.count; i++) {
      text += PdfTextExtractor(
        document,
      ).extractText(startPageIndex: i, endPageIndex: i);
    }
    document.dispose();
    return text;
  }

  Future<void> _generateMCQs() async {
    String truncatedText =
        _pdfText.length > 5000 ? _pdfText.substring(0, 5000) : _pdfText;

    String prompt = '''
    Based on the following text from a PDF, generate as many multiple-choice questions (MCQs) with 4 options each.
    For each question, indicate the correct answer.
    Format the response as JSON with the following structure:
    [
      {
        "question": "Question text",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "correctAnswer": "Option A"
      }
    ]
    
    Here's the text:
    $truncatedText
    ''';

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyBEh_qsPZ7P0RwSsz6q1U7THmyyzLAJw70',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 8192,
          },
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final generatedText =
            jsonResponse['candidates'][0]['content']['parts'][0]['text'];

        final jsonStartIndex = generatedText.indexOf('[');
        final jsonEndIndex = generatedText.lastIndexOf(']') + 1;

        if (jsonStartIndex >= 0 && jsonEndIndex > jsonStartIndex) {
          final jsonStr = generatedText.substring(jsonStartIndex, jsonEndIndex);
          final List<dynamic> questionsJson = jsonDecode(jsonStr);

          setState(() {
            _questions =
                questionsJson.map((q) => MCQQuestion.fromJson(q)).toList();
          });
        } else {
          throw Exception('Could not parse JSON from response');
        }
      } else {
        throw Exception('Failed to generate MCQs: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating MCQs: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveCurrentMcqsToNotes() async {
    if (_questions.isEmpty) return;
    final titleController = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: const Color(0xFF2D2D2D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: const Color(0xFFE63946).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  title: const Text(
                    'Save MCQs as Notes',
                    style: TextStyle(
                      color: Color(0xFFF1F1F1),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        style: const TextStyle(
                          color: Color(0xFFF1F1F1),
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Enter a title for this MCQ note',
                          labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                          errorText: errorText,
                          errorStyle: const TextStyle(color: Color(0xFFE63946)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: const Color(0xFFE63946).withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE63946),
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE63946),
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE63946),
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                        ),
                        onChanged: (value) {
                          setState(() {
                            errorText =
                                value.trim().isEmpty
                                    ? 'Title cannot be empty'
                                    : null;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_questions.length} MCQs will be saved as notes',
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFFB0B0B0)),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          setState(() {
                            errorText = 'Title cannot be empty';
                          });
                          return;
                        }
                        Navigator.pop(context, title);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );

    final title = result;
    if (title == null || title.isEmpty) return;

    final mcqs =
        _questions
            .map(
              (q) => {
                'question': q.question,
                'options': q.options,
                'correctIndex': q.options.indexOf(q.correctAnswer),
              },
            )
            .toList();

    final mcqSet = {'title': title, 'mcqs': mcqs};

    final prefs = await SharedPreferences.getInstance();
    final List<String> saved =
        prefs.getStringList('saved_notes_mcq_sets') ?? [];
    saved.add(jsonEncode(mcqSet));
    await prefs.setStringList('saved_notes_mcq_sets', saved);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Text(
                'MCQs saved to notes!',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SavedNotes()));
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppTheme.darkBackground,
        primaryColor: AppTheme.primaryRed,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.primaryRed,
          secondary: AppTheme.accentRed,
          surface: AppTheme.cardBackground,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
        cardTheme: CardTheme(
          color: AppTheme.cardBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Generate MCQ',
            style: TextStyle(
              color: AppTheme.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: AppTheme.cardBackground,
          elevation: 0,
          centerTitle: true,
        ),
        body:
            _isLoading
                ? Container(
                  color: AppTheme.darkBackground,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.primaryRed,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing your PDF...',
                          style: TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.darkBackground,
                        AppTheme.darkBackground.withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryRed.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _pickPDF,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 28,
                            ),
                            label: const Text(
                              'Create New MCQ Set',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 20,
                              ),
                              backgroundColor: AppTheme.primaryRed.withOpacity(
                                0.9,
                              ),
                              foregroundColor: Colors.white,
                              elevation: 6,
                              shadowColor: AppTheme.primaryRed.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: AppTheme.primaryRed.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_fileName.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryRed.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description,
                                  color: AppTheme.primaryRed,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _fileName,
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_questions.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(child: Container()),
                              ElevatedButton.icon(
                                onPressed: _saveCurrentMcqsToNotes,
                                icon: const Icon(Icons.save),
                                label: const Text('Save as Notes'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _questions.length,
                              itemBuilder: (context, index) {
                                return MCQCard(
                                  question: _questions[index],
                                  questionNumber: index + 1,
                                );
                              },
                            ),
                          ),
                        ] else if (_fileName.isNotEmpty) ...[
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  size: 64,
                                  color: AppTheme.textGrey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No MCQs generated yet.\nPlease wait or try another PDF.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}

class MCQQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;

  MCQQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory MCQQuestion.fromJson(Map<String, dynamic> json) {
    return MCQQuestion(
      question: json['question'],
      options: List<String>.from(json['options']),
      correctAnswer: json['correctAnswer'],
    );
  }
}

class MCQCard extends StatelessWidget {
  final MCQQuestion question;
  final int questionNumber;

  const MCQCard({
    Key? key,
    required this.question,
    required this.questionNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryRed.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Q$questionNumber',
                      style: const TextStyle(
                        color: AppTheme.primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...question.options.map((option) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textGrey.withOpacity(0.3),
                    ),
                    color: AppTheme.cardBackground,
                  ),
                  child: ListTile(
                    title: Text(
                      option,
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              Text(
                'Correct Answer: ${question.correctAnswer}',
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
