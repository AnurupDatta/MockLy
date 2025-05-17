import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFF1F1F1)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          mcqSet.title,
          style: const TextStyle(
            color: Color(0xFFF1F1F1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: mcqSet.mcqs.length,
          itemBuilder: (context, index) {
            final mcq = mcqSet.mcqs[index];
            // Safe check for correctIndex
            String correctAnswerText;
            if (mcq.correctIndex >= 0 &&
                mcq.correctIndex < mcq.options.length) {
              correctAnswerText = mcq.options[mcq.correctIndex];
            } else {
              correctAnswerText = 'Invalid correct answer index';
            }
            return Card(
              color: const Color(0xFF2D2D2D),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
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
                            color: const Color(0xFFE63946).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Q${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFFE63946),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mcq.question,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFF1F1F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(mcq.options.length, (optIdx) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFB0B0B0).withOpacity(0.3),
                          ),
                          color: const Color(0xFF2D2D2D),
                        ),
                        child: ListTile(
                          title: Text(
                            mcq.options[optIdx],
                            style: const TextStyle(
                              color: Color(0xFFF1F1F1),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      'Correct Answer: $correctAnswerText',
                      style: const TextStyle(
                        color: Color(0xFFE63946),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
