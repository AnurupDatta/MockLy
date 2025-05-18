import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Model for MCQ
class Mcq {
  final String question;
  final List<String> options;
  final int correctIndex;
  int? selectedAnswer;

  Mcq({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.selectedAnswer,
  });

  factory Mcq.fromJson(Map<String, dynamic> json) => Mcq(
    question: json['question'],
    options: List<String>.from(json['options']),
    correctIndex: json['correctIndex'],
  );

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
  };
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

  Map<String, dynamic> toJson() => {
    'title': title,
    'mcqs': mcqs.map((e) => e.toJson()).toList(),
  };
}

class SavedMcq extends StatefulWidget {
  const SavedMcq({super.key});

  @override
  State<SavedMcq> createState() => _SavedMcqState();
}

class _SavedMcqState extends State<SavedMcq> {
  List<McqSet> savedSets = [];

  @override
  void initState() {
    super.initState();
    _loadSavedMcqs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavedMcqs();
  }

  Future<void> _loadSavedMcqs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? data = prefs.getStringList('saved_mcq_sets');
    
    // Debug logging
    print('Loading saved MCQ sets:');
    print('Raw data from SharedPreferences: $data');
    
    if (data != null && data.isNotEmpty) {
      try {
        final loadedSets = data.map((e) {
          print('Parsing MCQ set: $e');
          return McqSet.fromJson(jsonDecode(e));
        }).toList();
        
        print('Successfully loaded ${loadedSets.length} MCQ sets');
        print('First set title: ${loadedSets.first.title}');
        print('First set MCQs count: ${loadedSets.first.mcqs.length}');
        
        setState(() {
          savedSets = loadedSets;
        });
      } catch (e) {
        print('Error parsing saved MCQ sets: $e');
        setState(() {
          savedSets = [];
        });
      }
    } else {
      print('No saved MCQ sets found');
      setState(() {
        savedSets = [];
      });
    }
  }

  void _openMcqSet(McqSet set) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => McqPracticePage(mcqSet: set)),
    );
  }

  // Add delete function
  Future<void> _deleteMcqSet(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          'Delete MCQ Set',
          style: TextStyle(
            color: Color(0xFFF1F1F1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${savedSets[index].title}"?',
          style: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
              ),
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
      final List<String> saved = prefs.getStringList('saved_mcq_sets') ?? [];
      saved.removeAt(index);
      await prefs.setStringList('saved_mcq_sets', saved);
      
      setState(() {
        savedSets.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MCQ set deleted successfully'),
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
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFFF1F1F1),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Saved MCQs',
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A1A),
              const Color(0xFF1A1A1A).withOpacity(0.95),
            ],
          ),
        ),
        child: savedSets.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.save_alt,
                      size: 64,
                      color: const Color(0xFFB0B0B0).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved MCQs',
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 16,
                      ),
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
                        highlightColor: const Color(0xFFE63946).withOpacity(0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE63946).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.quiz,
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
                                  color: const Color(0xFFE63946).withOpacity(0.1),
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
                                  backgroundColor: const Color(0xFFE63946).withOpacity(0.1),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    );
                    },
                ),
              ),
      ),
    );
  }
}

// Quiz page for practicing saved MCQs with app UI
class McqPracticePage extends StatefulWidget {
  final McqSet mcqSet;
  const McqPracticePage({super.key, required this.mcqSet});

  @override
  State<McqPracticePage> createState() => _McqPracticePageState();
}

class _McqPracticePageState extends State<McqPracticePage> {
  late List<Mcq> mcqs;
  int score = 0;
  bool showScore = false;

  @override
  void initState() {
    super.initState();
    mcqs =
        widget.mcqSet.mcqs
            .map(
              (mcq) => Mcq(
                question: mcq.question,
                options: List<String>.from(mcq.options),
                correctIndex: mcq.correctIndex,
              ),
            )
            .toList();
  }

  void _shuffleQuestions() {
    setState(() {
      mcqs.shuffle();
      showScore = false;
      score = 0;
      for (var mcq in mcqs) {
        mcq.selectedAnswer = null;
      }
    });
  }

  void _calculateScore() {
    setState(() {
      score = mcqs.where((q) => q.selectedAnswer == q.correctIndex).length;
      showScore = true;
    });
  }

  void _resetQuiz() {
    setState(() {
      for (var mcq in mcqs) {
        mcq.selectedAnswer = null;
      }
      showScore = false;
      score = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFFF1F1F1),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.mcqSet.title,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A1A),
              const Color(0xFF1A1A1A).withOpacity(0.95),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.28,
                      child: ElevatedButton.icon(
                        onPressed: _shuffleQuestions,
                        icon: const Icon(Icons.shuffle, size: 20),
                        label: const Text('Shuffle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE63946),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.28,
                      child: ElevatedButton.icon(
                        onPressed: _calculateScore,
                        icon: const Icon(Icons.calculate, size: 20),
                        label: const Text('Score'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE63946),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.32,
                      child: ElevatedButton.icon(
                        onPressed: _resetQuiz,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Reattempt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE63946),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showScore)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE63946).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE63946).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFE63946),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Your Score: $score / ${mcqs.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF1F1F1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: mcqs.length,
                  itemBuilder: (context, index) {
                    final mcq = mcqs[index];
                    final isAnswered = mcq.selectedAnswer != null;
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
                                    color: const Color(
                                      0xFFE63946,
                                    ).withOpacity(0.1),
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
                              final isSelected = mcq.selectedAnswer == optIdx;
                              final isCorrect = mcq.correctIndex == optIdx;
                              Color borderColor = const Color(
                                0xFFB0B0B0,
                              ).withOpacity(0.3);
                              Color fillColor = const Color(0xFF2D2D2D);
                              if (showScore) {
                                if (isCorrect) {
                                  borderColor = const Color(0xFFE63946);
                                  fillColor = const Color(
                                    0xFFE63946,
                                  ).withOpacity(0.1);
                                } else if (isSelected) {
                                  borderColor = Colors.red.withOpacity(0.5);
                                  fillColor = Colors.red.withOpacity(0.1);
                                }
                              } else if (isSelected) {
                                borderColor = const Color(0xFFE63946);
                                fillColor = const Color(
                                  0xFFE63946,
                                ).withOpacity(0.1);
                              }
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                  color: fillColor,
                                ),
                                child: RadioListTile<int>(
                                  value: optIdx,
                                  groupValue: mcq.selectedAnswer,
                                  onChanged:
                                      showScore
                                          ? null
                                          : (val) {
                                            setState(() {
                                              mcq.selectedAnswer = val;
                                            });
                                          },
                                  title: Text(
                                    mcq.options[optIdx],
                                    style: TextStyle(
                                      color:
                                          showScore
                                              ? (isCorrect
                                                  ? const Color(0xFFE63946)
                                                  : (isSelected
                                                      ? Colors.red
                                                      : const Color(0xFFF1F1F1)))
                                              : const Color(0xFFF1F1F1),
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal, // Only selected is bold
                                    ),
                                  ),
                                  activeColor: const Color(0xFFE63946),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }),
                            if (showScore)
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      mcq.selectedAnswer = null;
                                    });
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset Question'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D2D2D),
                                    foregroundColor: const Color(0xFFF1F1F1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
