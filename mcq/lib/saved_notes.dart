import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

// Model for MCQ (same as in saved_mcq.dart)
class Mcq {
  final String question;
  final List<String> options;
  final int correctIndex;

  Mcq({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory Mcq.fromJson(Map<String, dynamic> json) => Mcq(
    question: json['question'],
    options: List<String>.from(json['options']),
    correctIndex: json['correctIndex'],
  );
}

// Model for MCQ Set
class McqSet {
  final String title;
  final List<Mcq> mcqs;

  McqSet({required this.title, required this.mcqs});

  factory McqSet.fromJson(Map<String, dynamic> json) => McqSet(
    title: json['title'],
    mcqs: (json['mcqs'] as List).map((e) => Mcq.fromJson(e)).toList(),
  );
}

class SavedNotes extends StatefulWidget {
  const SavedNotes({super.key});

  @override
  State<SavedNotes> createState() => _SavedNotesState();
}

class _SavedNotesState extends State<SavedNotes> {
  List<McqSet> savedSets = [];

  @override
  void initState() {
    super.initState();
    _loadSavedNotes();
  }

  Future<void> _loadSavedNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? data = prefs.getStringList('saved_notes_mcq_sets');
    if (data != null && data.isNotEmpty) {
      setState(() {
        savedSets = data.map((e) => McqSet.fromJson(jsonDecode(e))).toList();
      });
    } else {
      setState(() {
        savedSets = [];
      });
    }
  }

  void _openMcqSet(McqSet set) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => McqNotesViewPage(mcqSet: set)),
    );
  }

  Future<void> _deleteMcqSet(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Delete MCQ Note',
              style: TextStyle(
                color: Color(0xFFF1F1F1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to delete "${savedSets[index].title}"?',
              style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFB0B0B0)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      final List<String> saved =
          prefs.getStringList('saved_notes_mcq_sets') ?? [];
      saved.removeAt(index);
      await prefs.setStringList('saved_notes_mcq_sets', saved);

      setState(() {
        savedSets.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MCQ note deleted successfully'),
            backgroundColor: Color(0xFFE63946),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFF1F1F1)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Saved MCQ Notes',
          style: TextStyle(
            color: Color(0xFFF1F1F1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      body:
          savedSets.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.note_alt,
                      size: 64,
                      color: const Color(0xFFB0B0B0).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved MCQ notes',
                      style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: savedSets.length,
                  itemBuilder: (context, index) {
                    final set = savedSets[index];
                    return Card(
                      color: const Color(0xFF2D2D2D),
                      elevation: 4,
                      shadowColor: const Color(0xFFE63946).withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: const Color(0xFFE63946).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: InkWell(
                        onTap: () => _openMcqSet(set),
                        borderRadius: BorderRadius.circular(16),
                        splashColor: const Color(0xFFE63946).withOpacity(0.1),
                        highlightColor: const Color(
                          0xFFE63946,
                        ).withOpacity(0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE63946,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.note_alt,
                                  color: Color(0xFFE63946),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  set.title,
                                  style: const TextStyle(
                                    color: Color(0xFFF1F1F1),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE63946,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${set.mcqs.length} MCQs',
                                  style: const TextStyle(
                                    color: Color(0xFFE63946),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFE63946),
                                  size: 20,
                                ),
                                onPressed: () => _deleteMcqSet(index),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFFE63946,
                                  ).withOpacity(0.1),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

class McqNotesViewPage extends StatelessWidget {
  final McqSet mcqSet;
  const McqNotesViewPage({super.key, required this.mcqSet});

  Future<void> _downloadAsPdf(BuildContext context) async {
    final PdfDocument document = PdfDocument();
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfFont boldFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      12,
      style: PdfFontStyle.bold,
    );

    // Add a page and set up layout variables
    PdfPage page = document.pages.add();
    double y = 0;
    const double leftMargin = 0;
    const double topMargin = 0;
    const double pageWidth = 500;
    const double lineSpacing = 8;
    const double questionSpacing = 18;
    const double optionSpacing = 16;
    const double answerSpacing = 20;
    const double bottomMargin = 40;

    // Title
    page.graphics.drawString(
      mcqSet.title,
      PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
      bounds: Rect.fromLTWH(leftMargin, y, pageWidth, 30),
    );
    y += 32;

    int qNo = 1;
    for (final mcq in mcqSet.mcqs) {
      // Check if we need a new page
      if (y > page.getClientSize().height - bottomMargin) {
        page = document.pages.add();
        y = topMargin;
      }
      // Question
      page.graphics.drawString(
        'Q$qNo. ${mcq.question}',
        boldFont,
        bounds: Rect.fromLTWH(leftMargin, y, pageWidth, questionSpacing),
      );
      y += questionSpacing + lineSpacing;

      // Options
      for (int i = 0; i < mcq.options.length; i++) {
        // Check if we need a new page before drawing option
        if (y > page.getClientSize().height - bottomMargin) {
          page = document.pages.add();
          y = topMargin;
        }
        page.graphics.drawString(
          '${String.fromCharCode(65 + i)}. ${mcq.options[i]}',
          font,
          bounds: Rect.fromLTWH(
            leftMargin + 20,
            y,
            pageWidth - 20,
            optionSpacing,
          ),
        );
        y += optionSpacing;
      }

      // Correct answer
      if (y > page.getClientSize().height - bottomMargin) {
        page = document.pages.add();
        y = topMargin;
      }
      page.graphics.drawString(
        'Correct Answer: ${mcq.options[mcq.correctIndex]}',
        boldFont,
        bounds: Rect.fromLTWH(leftMargin, y, pageWidth, answerSpacing),
        brush: PdfBrushes.red,
      );
      y += answerSpacing + lineSpacing;

      qNo++;
    }

    final List<int> bytes = await document.save();
    document.dispose();

    String? outputDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to save PDF',
    );
    if (outputDir != null) {
      String sanitizedTitle = mcqSet.title.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      String outputPath = '$outputDir/$sanitizedTitle.pdf';
      final file = File(outputPath);
      await file.writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded to $outputPath'),
            backgroundColor: const Color(0xFFE63946),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFF1F1F1)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MCQ Notes',
          style: TextStyle(
            color: Color(0xFFF1F1F1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFFF1F1F1)),
            onPressed: () => _downloadAsPdf(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mcqSet.title,
                style: const TextStyle(
                  color: Color(0xFFF1F1F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                itemCount: mcqSet.mcqs.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final mcq = mcqSet.mcqs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE63946).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q${index + 1}: ${mcq.question}',
                          style: const TextStyle(
                            color: Color(0xFFF1F1F1),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          itemCount: mcq.options.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, i) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${String.fromCharCode(65 + i)}.',
                                    style: const TextStyle(
                                      color: Color(0xFFB0B0B0),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      mcq.options[i],
                                      style: const TextStyle(
                                        color: Color(0xFFF1F1F1),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Correct Answer: ${mcq.options[mcq.correctIndex]}',
                          style: const TextStyle(
                            color: Color(0xFFE63946),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
