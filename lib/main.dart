import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const OrchestratorApp());
}

enum AgentState { pending, running, complete, error }

class AgentStatus {
  AgentStatus(this.name, this.state);

  final String name;
  final AgentState state;
}

class OrchestratorApp extends StatelessWidget {
  const OrchestratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orchestrator Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const OrchestratorPage(),
    );
  }
}

class OrchestratorPage extends StatefulWidget {
  const OrchestratorPage({super.key});

  @override
  State<OrchestratorPage> createState() => _OrchestratorPageState();
}

class _OrchestratorPageState extends State<OrchestratorPage> {
  final TextEditingController _featureController = TextEditingController(
    text: 'Create a basic product CRUD API with model, routes, and tests.',
  );

  bool _isGenerating = false;
  String _statusMessage = 'Idle';
  late List<AgentStatus> _agents;
  String? _jobId;
  Timer? _pollingTimer;

  Map<String, String> _generatedFiles = <String, String>{};
  String? _selectedFile;
  String? _architecture;
  String? _review;

  @override
  void initState() {
    super.initState();
    _agents = _initialAgents();
  }

  List<AgentStatus> _initialAgents() {
    return <AgentStatus>[
      AgentStatus('Architect Agent', AgentState.pending),
      AgentStatus('Backend Agent', AgentState.pending),
      AgentStatus('Integration Agent', AgentState.pending),
      AgentStatus('Reviewer Agent', AgentState.pending),
    ];
  }

  Future<void> _startGeneration() async {
    if (_isGenerating) {
      return;
    }

    _stopPolling();

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Starting...';
      _agents = _initialAgents();
      _jobId = null;
      _generatedFiles = <String, String>{};
      _selectedFile = null;
      _architecture = null;
      _review = null;
    });

    try {
      final Uri url = Uri.parse('http://localhost:8000/generate-feature');
      final http.Response response = await http.post(
        url,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'description': _featureController.text.trim(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to start generation: ${response.body}');
      }

      final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final String? jobId = decoded['jobId'] as String?;

      if (jobId == null) {
        throw Exception('Missing jobId in response');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _jobId = jobId;
        _statusMessage = 'Working...';
      });

      _startPolling();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isGenerating = false;
        _statusMessage = 'Failed to start: $error';
      });
    }
  }

  @override
  void dispose() {
    _featureController.dispose();
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    if (_jobId == null) {
      return;
    }

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchStatus());
    _fetchStatus();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchStatus() async {
    if (_jobId == null) {
      return;
    }

    try {
      final Uri url = Uri.parse('http://localhost:8000/status/$_jobId');
      final http.Response response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch status: ${response.body}');
      }

      final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      _applyStatus(decoded);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Error polling: $error';
        _isGenerating = false;
      });
      _stopPolling();
    }
  }

  void _applyStatus(Map<String, dynamic> status) {
    final Map<String, dynamic> steps =
        (status['steps'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<AgentStatus> updatedAgents = _workflowOrder
        .map(
          (MapEntry<String, String> step) => AgentStatus(
            step.value,
            _mapState(steps[step.key] as String?),
          ),
        )
        .toList();

    final Map<String, String> files = <String, String>{};
    final List<dynamic>? returnedFiles = status['files'] as List<dynamic>?;
    if (returnedFiles != null) {
      for (final dynamic file in returnedFiles) {
        if (file is Map<String, dynamic>) {
          final String? path = file['path'] as String?;
          final String? content = file['content'] as String?;
          if (path != null && content != null) {
            files[path] = content;
          }
        }
      }
    }

    final Map<String, dynamic>? architecture = status['architecture'] as Map<String, dynamic>?;
    final String? review = status['review'] as String?;

    setState(() {
      _agents = updatedAgents;
      _statusMessage = status['status'] == 'complete' ? 'Complete' : 'Working...';
      _architecture = architecture == null
          ? null
          : const JsonEncoder.withIndent('  ').convert(architecture);
      _review = review;

      if (files.isNotEmpty) {
        _generatedFiles = files;
        if (_selectedFile == null || !_generatedFiles.containsKey(_selectedFile)) {
          _selectedFile = _generatedFiles.keys.first;
        }
      }

      if (status['status'] == 'complete') {
        _isGenerating = false;
        _stopPolling();
      }
    });
  }

  AgentState _mapState(String? value) {
    switch (value) {
      case 'running':
        return AgentState.running;
      case 'complete':
        return AgentState.complete;
      case 'error':
        return AgentState.error;
      default:
        return AgentState.pending;
    }
  }

  static const List<MapEntry<String, String>> _workflowOrder = <MapEntry<String, String>>[
    MapEntry<String, String>('architect', 'Architect Agent'),
    MapEntry<String, String>('backend', 'Backend Agent'),
    MapEntry<String, String>('integration', 'Integration Agent'),
    MapEntry<String, String>('review', 'Reviewer Agent'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              _buildHeader(context),
              const SizedBox(height: 16),
              Expanded(child: _buildMainArea(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Generate a New Feature',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _featureController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Describe the feature, e.g. "Create a basic product CRUD API with model, routes, and tests."',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _startGeneration,
                  icon: const Icon(Icons.bolt_outlined),
                  label: const Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: <Widget>[
                    Icon(
                      _isGenerating
                          ? Icons.autorenew_rounded
                          : Icons.pause_circle_outline,
                      size: 20,
                      color: _isGenerating
                          ? Colors.amber.shade700
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isGenerating
                            ? Colors.amber.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainArea(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 1,
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Workflow Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ..._agents.map(_buildAgentRow),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      tabs: const <Widget>[
                        Tab(text: 'Architecture'),
                        Tab(text: 'Code'),
                        Tab(text: 'Review'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: <Widget>[
                          _buildArchitectureTab(context),
                          _buildCodeTab(context),
                          _buildReviewTab(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentRow(AgentStatus agent) {
    final Map<AgentState, IconData> icons = <AgentState, IconData>{
      AgentState.pending: Icons.circle_outlined,
      AgentState.running: Icons.circle,
      AgentState.complete: Icons.check_circle,
      AgentState.error: Icons.cancel,
    };

    final Map<AgentState, Color> colors = <AgentState, Color>{
      AgentState.pending: Colors.grey,
      AgentState.running: Colors.blueAccent,
      AgentState.complete: Colors.green,
      AgentState.error: Colors.red,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icons[agent.state], color: colors[agent.state]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              agent.name,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(_statusLabel(agent.state), style: TextStyle(color: colors[agent.state])),
        ],
      ),
    );
  }

  String _statusLabel(AgentState state) {
    switch (state) {
      case AgentState.complete:
        return 'Complete';
      case AgentState.running:
        return 'Running';
      case AgentState.pending:
        return 'Pending';
      case AgentState.error:
        return 'Error';
    }
  }

  Widget _buildArchitectureTab(BuildContext context) {
    return _PanelContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _architecture == null
            ? const Text('Architecture will appear here once available.')
            : SelectableText(
                _architecture!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
              ),
      ),
    );
  }

  Widget _buildCodeTab(BuildContext context) {
    final bool hasFiles = _generatedFiles.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Generated files',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: hasFiles ? _selectedFile : null,
          hint: const Text('No files yet'),
          onChanged: hasFiles
              ? (String? value) {
                  if (value == null) return;
                  setState(() => _selectedFile = value);
                }
              : null,
          items: _generatedFiles.keys
              .map(
                (String path) => DropdownMenuItem<String>(
                  value: path,
                  child: Text(path),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _PanelContainer(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: hasFiles
                  ? SelectableText(
                      _generatedFiles[_selectedFile] ?? '',
                      style: const TextStyle(fontFamily: 'monospace'),
                    )
                  : const Text('Files will be shown when the run is complete.'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTab(BuildContext context) {
    return _PanelContainer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _review == null
            ? const Text('Reviewer feedback will appear here once available.')
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.comment, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_review!)),
                ],
              ),
      ),
    );
  }
}

class _PanelContainer extends StatelessWidget {
  const _PanelContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }
}
