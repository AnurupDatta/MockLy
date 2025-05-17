import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mcq/generate_mcq.dart';
import 'package:mcq/saved_mcq.dart';
import 'package:mcq/saved_notes.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// Custom theme colors
class AppTheme {
  static const Color primaryRed = Color(0xFFE63946);
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color cardBackground = Color(0xFF2D2D2D);
  static const Color accentRed = Color(0xFFFF4B4B);
  static const Color textLight = Color(0xFFF1F1F1);
  static const Color textGrey = Color(0xFFB0B0B0);
}

class McqPage extends StatefulWidget {
  const McqPage({Key? key}) : super(key: key);

  @override
  State<McqPage> createState() => _McqPageState();
}

class _McqPageState extends State<McqPage> {
  bool _isLoading = false;
  String _pdfText = '';
  String _fileName = '';
  List<MCQQuestion> _questions = [];
  int _score = 0;
  bool _showScore = false;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE63946),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error generating MCQs: ${e.toString()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE63946),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _shuffleQuestions() {
    setState(() {
      _questions.shuffle();
      _showScore = false;
      _score = 0;
    });
  }

  void _calculateScore() {
    setState(() {
      _score = _questions.where((q) => q.isCorrectlyAnswered).length;
      _showScore = true;
    });
  }

  void _resetQuiz() {
    setState(() {
      for (var question in _questions) {
        question.selectedAnswer = null; // Reset selected answers
      }
      _showScore = false; // Hide the score
      _score = 0; // Reset the score
    });
  }

  Future<void> _saveCurrentMcqs() async {
    if (_questions.isEmpty) return;
    final titleController = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFE63946).withOpacity(0.1),
              width: 1,
            ),
          ),
          title: const Text(
            'Save MCQs',
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
                  labelText: 'Enter a title for this MCQ set',
                  labelStyle: const TextStyle(
                    color: Color(0xFFB0B0B0),
                  ),
                  errorText: errorText,
                  errorStyle: const TextStyle(
                    color: Color(0xFFE63946),
                  ),
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
                    errorText = value.trim().isEmpty ? 'Title cannot be empty' : null;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                '${_questions.length} MCQs will be saved',
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
                style: TextStyle(
                  color: Color(0xFFB0B0B0),
                ),
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

    // Convert MCQQuestion to Mcq model
    final mcqs = _questions.map((q) => {
      'question': q.question,
      'options': q.options,
      'correctIndex': q.options.indexOf(q.correctAnswer),
    }).toList();

    final mcqSet = {'title': title, 'mcqs': mcqs};
    
    // Debug logging
    print('Saving MCQ set:');
    print('Title: $title');
    print('Number of MCQs: ${mcqs.length}');
    print('First MCQ: ${mcqs.first}');

    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('saved_mcq_sets') ?? [];
    saved.add(jsonEncode(mcqSet));
    await prefs.setStringList('saved_mcq_sets', saved);

    // Debug print to verify saving
    print('Current saved MCQ sets: ${saved.length}');
    print('Latest saved set: ${saved.last}');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'MCQs saved successfully!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SavedMcq(),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _navigateToPracticeMCQ() {
    Navigator.of(context).pop(); // Close the drawer
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const McqPage()));
  }

  void _navigateToGenerateMCQ() {
    Navigator.of(context).pop(); // Close the drawer
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const GenerateMcq()));
  }

  void _navigateToSavedMCQ() {
    Navigator.of(context).pop(); // Close the drawer
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SavedMcq()));
  }
   void _navigateToMCQnotes() {
    Navigator.of(context).pop(); // Close the drawer
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SavedNotes()));
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
        drawer: Drawer(
          backgroundColor: AppTheme.cardBackground,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.create, color: AppTheme.primaryRed),
                  title: Text(
                    'Generate MCQ',
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _navigateToGenerateMCQ,
                ),
                ListTile(
                  leading: Icon(Icons.quiz, color: AppTheme.primaryRed),
                  title: Text(
                    'Practice MCQ',
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _navigateToPracticeMCQ,
                ),
                ListTile(
                  leading: Icon(Icons.save, color: AppTheme.primaryRed),
                  title: Text(
                    'Saved MCQs for Practice',
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _navigateToSavedMCQ,
                ),
                ListTile(
                  leading: Icon(Icons.save, color: AppTheme.primaryRed),
                  title: Text(
                    'Saved MCQs for Notes',
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _navigateToMCQnotes,
                ),
              ],
            ),
          ),
        ),
        appBar: AppBar(
          leading: Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(Icons.menu, color: AppTheme.textLight),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
          ),
          title: const Text(
            'PDF MCQ Generator',
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
                            icon: const Icon(Icons.upload_file, size: 28),
                            label: const Text(
                              'Upload PDF',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildActionButton(
                                    'Shuffle Questions',
                                    Icons.shuffle,
                                    _shuffleQuestions,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildActionButton(
                                    'Calculate Score',
                                    Icons.calculate,
                                    _calculateScore,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildActionButton(
                                    'Reattempt Quiz',
                                    Icons.refresh,
                                    _resetQuiz,
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await _saveCurrentMcqs();
                                    },
                                    icon: const Icon(Icons.save),
                                    label: const Text('Save MCQs'),
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
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_showScore)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryRed.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    color: AppTheme.primaryRed,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Your Score: $_score / ${_questions.length}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _questions.length,
                              itemBuilder: (context, index) {
                                return MCQCard(
                                  question: _questions[index],
                                  questionNumber: index + 1,
                                  showCorrectness: _showScore,
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

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.cardBackground,
        foregroundColor: AppTheme.textLight,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class MCQQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;
  String? selectedAnswer;

  MCQQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.selectedAnswer,
  });

  bool get isCorrectlyAnswered => selectedAnswer == correctAnswer;

  factory MCQQuestion.fromJson(Map<String, dynamic> json) {
    return MCQQuestion(
      question: json['question'],
      options: List<String>.from(json['options']),
      correctAnswer: json['correctAnswer'],
    );
  }
}

class MCQCard extends StatefulWidget {
  final MCQQuestion question;
  final int questionNumber;
  final bool showCorrectness; // New property to show correctness

  const MCQCard({
    Key? key,
    required this.question,
    required this.questionNumber,
    required this.showCorrectness,
  }) : super(key: key);

  @override
  State<MCQCard> createState() => _MCQCardState();
}

class _MCQCardState extends State<MCQCard> {
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
                      'Q${widget.questionNumber}',
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
                      widget.question.question,
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
              ...widget.question.options.map((option) {
                final isSelected = option == widget.question.selectedAnswer;
                final isCorrect = option == widget.question.correctAnswer;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          widget.showCorrectness
                              ? (isCorrect
                                  ? AppTheme.primaryRed
                                  : (isSelected
                                      ? Colors.red.withOpacity(0.5)
                                      : AppTheme.textGrey.withOpacity(0.3)))
                              : (isSelected
                                  ? AppTheme.primaryRed
                                  : AppTheme.textGrey.withOpacity(0.3)),
                    ),
                    color:
                        widget.showCorrectness
                            ? (isCorrect
                                ? AppTheme.primaryRed.withOpacity(0.1)
                                : (isSelected
                                    ? Colors.red.withOpacity(0.1)
                                    : AppTheme.cardBackground))
                            : (isSelected
                                ? AppTheme.primaryRed.withOpacity(0.1)
                                : AppTheme.cardBackground),
                  ),
                  child: RadioListTile<String>(
                    title: Text(
                      option,
                      style: TextStyle(
                        color:
                            widget.showCorrectness
                                ? (isCorrect
                                    ? AppTheme.primaryRed
                                    : (isSelected
                                        ? Colors.red
                                        : AppTheme.textLight))
                                : AppTheme.textLight,
                        fontWeight:
                            isSelected || isCorrect
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    value: option,
                    groupValue: widget.question.selectedAnswer,
                    onChanged:
                        widget.showCorrectness
                            ? null
                            : (value) {
                              setState(() {
                                widget.question.selectedAnswer = value;
                              });
                            },
                    activeColor: AppTheme.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
              if (widget.showCorrectness) ...[
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _resetQuestion,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardBackground,
                      foregroundColor: AppTheme.textLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _resetQuestion() {
    setState(() {
      widget.question.selectedAnswer = null;
    });
  }
}
