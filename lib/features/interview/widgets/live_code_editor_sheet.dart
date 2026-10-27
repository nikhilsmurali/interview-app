import 'package:ai_interviewer/core/services/openai_service.dart';
import 'package:flutter/material.dart';

class LiveCodeEditorSheet extends StatefulWidget {
  final String currentQuestion;
  final Function(String solutionText) onAttachToAnswer;
  final VoidCallback? onClose;
  final bool isEmbedded;

  const LiveCodeEditorSheet({
    super.key,
    required this.currentQuestion,
    required this.onAttachToAnswer,
    this.onClose,
    this.isEmbedded = false,
  });

  @override
  State<LiveCodeEditorSheet> createState() => _LiveCodeEditorSheetState();
}

class _LiveCodeEditorSheetState extends State<LiveCodeEditorSheet> {
  final TextEditingController _codeController = TextEditingController();
  final OpenAIService _openAIService = OpenAIService();

  String _selectedLanguage = 'Dart';
  final List<String> _languages = [
    'Dart',
    'Python',
    'JavaScript',
    'TypeScript',
    'Java',
    'C++',
    'Go',
    'SQL',
  ];

  final Map<String, String> _templates = {
    'Dart': '''// Dart Solution
class Solution {
  // Solve the problem for:
  void solve() {
    // Write your solution here
    
  }
}
''',
    'Python': '''# Python Solution
class Solution:
    def solve(self, input_data):
        # Write your solution here
        pass
''',
    'JavaScript': '''// JavaScript Solution
function solve(input) {
  // Write your solution here
  
}
''',
    'TypeScript': '''// TypeScript Solution
function solve<T>(input: T): void {
  // Write your solution here
  
}
''',
    'Java': '''// Java Solution
public class Solution {
    public void solve(String input) {
        // Write your solution here
        
    }
}
''',
    'C++': '''// C++ Solution
#include <iostream>
#include <vector>

class Solution {
public:
    void solve() {
        // Write your solution here
        
    }
};
''',
    'Go': '''// Go Solution
package main

func solve(input string) {
    // Write your solution here
    
}
''',
    'SQL': '''-- SQL Query Solution
SELECT *
FROM table_name
WHERE condition = true;
''',
  };

  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    _codeController.text = _templates[_selectedLanguage] ?? '';
    _codeController.addListener(_updateLineCount);
    _updateLineCount();
  }

  void _updateLineCount() {
    final count = '\n'.allMatches(_codeController.text).length + 1;
    if (count != _lineCount) {
      setState(() => _lineCount = count);
    }
  }

  void _onLanguageChanged(String? newLang) {
    if (newLang == null || newLang == _selectedLanguage) return;
    setState(() {
      _selectedLanguage = newLang;
      _codeController.text = _templates[newLang] ?? '';
      _analysisResult = null;
    });
  }

  Future<void> _analyzeComplexityAndReview() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write some code first.')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await _openAIService.evaluateCodeSolution(
        question: widget.currentQuestion,
        code: code,
        language: _selectedLanguage,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing code: $e')),
        );
      }
    }
  }

  void _attachToAnswer() {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln("[Candidate Code Solution - $_selectedLanguage]");
    buffer.writeln("```${_selectedLanguage.toLowerCase()}");
    buffer.writeln(code);
    buffer.writeln("```");

    if (_analysisResult != null) {
      buffer.writeln("Time Complexity: ${_analysisResult!['timeComplexity'] ?? 'N/A'}");
      buffer.writeln("Space Complexity: ${_analysisResult!['spaceComplexity'] ?? 'N/A'}");
      if (_analysisResult!['summary'] != null) {
        buffer.writeln("Approach: ${_analysisResult!['summary']}");
      }
    }

    widget.onAttachToAnswer(buffer.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Code solution attached to your current answer!'),
        backgroundColor: Color(0xFF1B8A5A),
      ),
    );

    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_updateLineCount);
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.isEmbedded ? double.infinity : MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: widget.isEmbedded
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: widget.isEmbedded ? Border.all(color: Colors.white12) : null,
      ),
      child: Column(
        children: [
          // Drag handle (modal only)
          if (!widget.isEmbedded)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A00).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code_rounded, color: Color(0xFFFF5A00), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Code Editor & Big-O Analyzer',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Type your solution, analyze Big-O complexity, or attach to your response',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Active question reminder banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.help_outline_rounded, color: Color(0xFFFF8A00), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.currentQuestion.isNotEmpty
                        ? widget.currentQuestion
                        : "Write code to solve the technical scenario.",
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                // Language Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      dropdownColor: const Color(0xFF1E1E2D),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFF5A00)),
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang),
                        );
                      }).toList(),
                      onChanged: _onLanguageChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _codeController.text = _templates[_selectedLanguage] ?? '',
                  icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white60),
                  label: const Text('Reset Template', style: TextStyle(color: Colors.white60, fontSize: 11)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _codeController.clear(),
                  icon: const Icon(Icons.clear_all_rounded, size: 14, color: Colors.white60),
                  label: const Text('Clear', style: TextStyle(color: Colors.white60, fontSize: 11)),
                ),
              ],
            ),
          ),

          // Editor Window
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F17),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line Numbers Column
                  Container(
                    width: 38,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                    ),
                    child: Column(
                      children: List.generate(
                        _lineCount,
                        (index) => Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                  // Code input area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: TextField(
                        controller: _codeController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          color: Color(0xFFE0E0FF),
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '// Write or paste your code implementation...',
                          hintStyle: TextStyle(color: Colors.white24, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // AI Analysis Result (if available)
          if (_analysisResult != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF5A00).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A00).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "⏱️ Time: ${_analysisResult!['timeComplexity'] ?? 'N/A'}",
                          style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "💾 Space: ${_analysisResult!['spaceComplexity'] ?? 'N/A'}",
                          style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "⭐ Rating: ${_analysisResult!['rating'] ?? '8'}/10",
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _analysisResult!['summary'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_analysisResult!['optimizationTips'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "💡 ${_analysisResult!['optimizationTips']}",
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeComplexityAndReview,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      _isAnalyzing ? "Analyzing Complexity..." : "Review Big-O & Bugs",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _attachToAnswer,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      "Attach to Answer",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
