import 'dart:math' as math;
import 'package:ai_interviewer/core/services/openai_service.dart';
import 'package:flutter/material.dart';

class SystemComponentDefinition {
  final String type;
  final String label;
  final IconData icon;
  final Color color;

  const SystemComponentDefinition({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class WhiteboardNode {
  final String id;
  final String type;
  String label;
  Offset position;
  final IconData icon;
  final Color color;

  WhiteboardNode({
    required this.id,
    required this.type,
    required this.label,
    required this.position,
    required this.icon,
    required this.color,
  });
}

class WhiteboardConnection {
  final String id;
  final String fromId;
  final String toId;
  String label;

  WhiteboardConnection({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.label,
  });
}

class SystemDesignWhiteboardSheet extends StatefulWidget {
  final String currentQuestion;
  final Function(String architectureSummary) onAttachToAnswer;
  final VoidCallback? onClose;
  final bool isEmbedded;

  const SystemDesignWhiteboardSheet({
    super.key,
    required this.currentQuestion,
    required this.onAttachToAnswer,
    this.onClose,
    this.isEmbedded = false,
  });

  @override
  State<SystemDesignWhiteboardSheet> createState() => _SystemDesignWhiteboardSheetState();
}

class _SystemDesignWhiteboardSheetState extends State<SystemDesignWhiteboardSheet> {
  final OpenAIService _openAIService = OpenAIService();

  static const List<SystemComponentDefinition> _palette = [
    SystemComponentDefinition(type: 'client', label: 'Client / App', icon: Icons.devices_rounded, color: Colors.lightBlueAccent),
    SystemComponentDefinition(type: 'lb', label: 'Load Balancer', icon: Icons.balance_rounded, color: Color(0xFFFF5A00)),
    SystemComponentDefinition(type: 'gateway', label: 'API Gateway', icon: Icons.shield_rounded, color: Colors.purpleAccent),
    SystemComponentDefinition(type: 'service', label: 'Microservice', icon: Icons.layers_rounded, color: Colors.indigoAccent),
    SystemComponentDefinition(type: 'cache', label: 'Redis Cache', icon: Icons.bolt_rounded, color: Colors.redAccent),
    SystemComponentDefinition(type: 'sqldb', label: 'Postgres DB', icon: Icons.storage_rounded, color: Colors.amberAccent),
    SystemComponentDefinition(type: 'nosqldb', label: 'NoSQL / Mongo', icon: Icons.dataset_rounded, color: Colors.greenAccent),
    SystemComponentDefinition(type: 'queue', label: 'Kafka Queue', icon: Icons.sync_alt_rounded, color: Colors.tealAccent),
    SystemComponentDefinition(type: 'storage', label: 'S3 Storage', icon: Icons.cloud_queue_rounded, color: Colors.cyanAccent),
    SystemComponentDefinition(type: 'cdn', label: 'CDN / Edge', icon: Icons.public_rounded, color: Colors.orangeAccent),
  ];

  final List<WhiteboardNode> _nodes = [];
  final List<WhiteboardConnection> _connections = [];

  String? _selectedNodeId;
  String? _connectingSourceId;
  bool _isConnectMode = false;
  String _selectedProtocol = 'HTTPS / REST';

  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;

  @override
  void initState() {
    super.initState();
    _populateDefaultStarterTopology();
  }

  void _populateDefaultStarterTopology() {
    _nodes.add(WhiteboardNode(
      id: 'node_1',
      type: 'client',
      label: 'Client App',
      position: const Offset(40, 100),
      icon: Icons.devices_rounded,
      color: Colors.lightBlueAccent,
    ));
    _nodes.add(WhiteboardNode(
      id: 'node_2',
      type: 'lb',
      label: 'Load Balancer',
      position: const Offset(180, 100),
      icon: Icons.balance_rounded,
      color: const Color(0xFFFF5A00),
    ));
    _nodes.add(WhiteboardNode(
      id: 'node_3',
      type: 'service',
      label: 'API Service',
      position: const Offset(320, 100),
      icon: Icons.layers_rounded,
      color: Colors.indigoAccent,
    ));
    _nodes.add(WhiteboardNode(
      id: 'node_4',
      type: 'sqldb',
      label: 'PostgreSQL DB',
      position: const Offset(460, 100),
      icon: Icons.storage_rounded,
      color: Colors.amberAccent,
    ));

    _connections.add(WhiteboardConnection(id: 'conn_1', fromId: 'node_1', toId: 'node_2', label: 'HTTPS'));
    _connections.add(WhiteboardConnection(id: 'conn_2', fromId: 'node_2', toId: 'node_3', label: 'gRPC'));
    _connections.add(WhiteboardConnection(id: 'conn_3', fromId: 'node_3', toId: 'node_4', label: 'Read/Write'));
  }

  void _addNodeFromPalette(SystemComponentDefinition comp) {
    final newId = 'node_${DateTime.now().millisecondsSinceEpoch}';
    final randomOffset = Offset(
      80.0 + (_nodes.length % 4) * 110.0,
      160.0 + ((_nodes.length ~/ 4) % 3) * 90.0,
    );

    setState(() {
      _nodes.add(WhiteboardNode(
        id: newId,
        type: comp.type,
        label: comp.label,
        position: randomOffset,
        icon: comp.icon,
        color: comp.color,
      ));
      _selectedNodeId = newId;
    });
  }

  void _onNodeTapped(String nodeId) {
    if (_isConnectMode) {
      if (_connectingSourceId == null) {
        setState(() => _connectingSourceId = nodeId);
      } else {
        if (_connectingSourceId != nodeId) {
          // Create connection
          final newConn = WhiteboardConnection(
            id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
            fromId: _connectingSourceId!,
            toId: nodeId,
            label: _selectedProtocol,
          );
          setState(() {
            _connections.add(newConn);
            _connectingSourceId = null;
            _isConnectMode = false;
          });
        }
      }
    } else {
      setState(() {
        _selectedNodeId = nodeId;
      });
    }
  }

  void _deleteSelectedNode() {
    if (_selectedNodeId == null) return;
    setState(() {
      _connections.removeWhere((c) => c.fromId == _selectedNodeId || c.toId == _selectedNodeId);
      _nodes.removeWhere((n) => n.id == _selectedNodeId);
      _selectedNodeId = null;
    });
  }

  void _clearCanvas() {
    setState(() {
      _nodes.clear();
      _connections.clear();
      _selectedNodeId = null;
      _connectingSourceId = null;
      _analysisResult = null;
    });
  }

  Future<void> _analyzeArchitecture() async {
    if (_nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one component to the canvas.')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final compsData = _nodes.map((n) => {'name': n.label, 'type': n.type}).toList();
      final connsData = _connections.map((c) {
        final fromNode = _nodes.firstWhere((n) => n.id == c.fromId, orElse: () => _nodes.first);
        final toNode = _nodes.firstWhere((n) => n.id == c.toId, orElse: () => _nodes.last);
        return {'from': fromNode.label, 'to': toNode.label, 'label': c.label};
      }).toList();

      final result = await _openAIService.evaluateSystemDesign(
        question: widget.currentQuestion,
        components: compsData,
        connections: connsData,
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
          SnackBar(content: Text('Error analyzing architecture: $e')),
        );
      }
    }
  }

  void _attachToAnswer() {
    if (_nodes.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln("[Candidate System Design Architecture]");
    buffer.writeln("Components:");
    for (var n in _nodes) {
      buffer.writeln("- ${n.label} (${n.type})");
    }

    if (_connections.isNotEmpty) {
      buffer.writeln("Data Flow & Connections:");
      for (var c in _connections) {
        final from = _nodes.firstWhere((n) => n.id == c.fromId, orElse: () => _nodes.first).label;
        final to = _nodes.firstWhere((n) => n.id == c.toId, orElse: () => _nodes.last).label;
        buffer.writeln("- $from -> $to [${c.label}]");
      }
    }

    if (_analysisResult != null) {
      buffer.writeln("Architecture Score: ${_analysisResult!['rating'] ?? '8.0'}/10");
      buffer.writeln("Verdict: ${_analysisResult!['verdict'] ?? 'Feasible'}");
      if (_analysisResult!['summary'] != null) {
        buffer.writeln("Assessment: ${_analysisResult!['summary']}");
      }
    }

    widget.onAttachToAnswer(buffer.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ System architecture attached to current answer!'),
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
  Widget build(BuildContext context) {
    return Container(
      height: widget.isEmbedded ? double.infinity : MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A00).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_tree_rounded, color: Color(0xFFFF5A00), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Design Whiteboard',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Drop architecture boxes, draw connections, and run AI scalability reviews',
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

          // Palette Carousel / Component Bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              border: const Border(
                top: BorderSide(color: Colors.white10),
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _palette.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final comp = _palette[index];
                return InkWell(
                  onTap: () => _addNodeFromPalette(comp),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: comp.color.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(comp.icon, color: comp.color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          comp.label,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.add, color: Colors.white38, size: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Canvas Controls Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                // Toggle Connect Mode
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isConnectMode = !_isConnectMode;
                      _connectingSourceId = null;
                    });
                  },
                  icon: Icon(_isConnectMode ? Icons.link_off_rounded : Icons.link_rounded, size: 16),
                  label: Text(_isConnectMode ? "Cancel Link" : "Link Nodes", style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConnectMode ? const Color(0xFFFF5A00) : Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_isConnectMode) ...[
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProtocol,
                      dropdownColor: const Color(0xFF222233),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      items: ['HTTPS / REST', 'gRPC', 'Cache Hit/Miss', 'Pub / Sub', 'Read / Write', 'Replication'].map((p) {
                        return DropdownMenuItem(value: p, child: Text(p));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProtocol = val);
                      },
                    ),
                  ),
                ],
                const Spacer(),
                if (_selectedNodeId != null)
                  IconButton(
                    onPressed: _deleteSelectedNode,
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    tooltip: "Delete Selected Box",
                  ),
                IconButton(
                  onPressed: _clearCanvas,
                  icon: const Icon(Icons.layers_clear_outlined, color: Colors.white54, size: 20),
                  tooltip: "Clear Canvas",
                ),
              ],
            ),
          ),

          if (_isConnectMode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5A00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _connectingSourceId == null
                    ? "👉 Tap the SOURCE component to start arrow"
                    : "👉 Tap the TARGET component to complete arrow",
                style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

          // Interactive Drag-and-Drop Canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: const Color(0xFF09090F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Stack(
                children: [
                  // Grid background
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WhiteboardGridPainter(),
                    ),
                  ),

                  // Connection Lines Painter
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WhiteboardConnectionsPainter(
                        nodes: _nodes,
                        connections: _connections,
                      ),
                    ),
                  ),

                  // Draggable Node Boxes
                  ..._nodes.map((node) {
                    final isSelected = node.id == _selectedNodeId;
                    final isConnectingSource = node.id == _connectingSourceId;

                    return Positioned(
                      left: node.position.dx,
                      top: node.position.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            node.position += details.delta;
                          });
                        },
                        onTap: () => _onNodeTapped(node.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isConnectingSource
                                  ? const Color(0xFFFF5A00)
                                  : (isSelected ? Colors.white : node.color.withValues(alpha: 0.6)),
                              width: (isSelected || isConnectingSource) ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: node.color.withValues(alpha: isSelected ? 0.35 : 0.15),
                                blurRadius: isSelected ? 12 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(node.icon, color: node.color, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                node.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Architecture Evaluation Result
          if (_analysisResult != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          "⭐ Score: ${_analysisResult!['rating'] ?? '8.0'}/10",
                          style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 11),
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
                          _analysisResult!['verdict'] ?? 'Feasible',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
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
                          "Scalability: ${_analysisResult!['scalabilityScore'] ?? 'High'}",
                          style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 11),
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
                ],
              ),
            ),

          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeArchitecture,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.psychology_rounded, size: 18),
                    label: Text(
                      _isAnalyzing ? "Analyzing Topology..." : "AI Architecture Review",
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

class WhiteboardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WhiteboardConnectionsPainter extends CustomPainter {
  final List<WhiteboardNode> nodes;
  final List<WhiteboardConnection> connections;

  WhiteboardConnectionsPainter({
    required this.nodes,
    required this.connections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFFF8A00).withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = const Color(0xFFFF8A00)
      ..style = PaintingStyle.fill;

    const nodeWidthApprox = 60.0;
    const nodeHeightApprox = 20.0;

    for (var conn in connections) {
      final fromList = nodes.where((n) => n.id == conn.fromId);
      final toList = nodes.where((n) => n.id == conn.toId);
      if (fromList.isEmpty || toList.isEmpty) continue;

      final from = fromList.first.position + const Offset(nodeWidthApprox, nodeHeightApprox);
      final to = toList.first.position + const Offset(nodeWidthApprox, nodeHeightApprox);

      // Draw line
      canvas.drawLine(from, to, linePaint);

      // Draw arrowhead at target
      final dx = to.dx - from.dx;
      final dy = to.dy - from.dy;
      final angle = math.atan2(dy, dx);
      const arrowLength = 10.0;

      final arrowP1 = to - Offset(arrowLength * math.cos(angle - 0.5), arrowLength * math.sin(angle - 0.5));
      final arrowP2 = to - Offset(arrowLength * math.cos(angle + 0.5), arrowLength * math.sin(angle + 0.5));

      final path = Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(arrowP1.dx, arrowP1.dy)
        ..lineTo(arrowP2.dx, arrowP2.dy)
        ..close();
      canvas.drawPath(path, arrowPaint);

      // Draw label badge at midpoint
      final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final textSpan = TextSpan(
        text: conn.label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xFF14141E),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, mid - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardConnectionsPainter oldDelegate) => true;
}
