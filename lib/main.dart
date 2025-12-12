import 'package:flutter/material.dart';

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

  final Map<String, String> _generatedFiles = <String, String>{
    '/products/ProductController.cs': '''using Microsoft.AspNetCore.Mvc;\n\n[ApiController]\n[Route("api/[controller]")]\npublic class ProductController : ControllerBase {\n    // CRUD endpoints go here\n}''',
    '/products/ProductModel.cs': '''public class Product {\n    public int Id { get; set; }\n    public string Name { get; set; } = string.Empty;\n    public decimal Price { get; set; }\n;}''',
    '/products/README.md': '''# Products Feature\n\nGenerated API feature for managing products including routes and tests.''',
  };

  late String _selectedFile;

  @override
  void initState() {
    super.initState();
    _agents = _initialAgents();
    _selectedFile = _generatedFiles.keys.first;
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

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Working...';
      _agents = _initialAgents();
    });

    await _runWorkflow();

    if (!mounted) {
      return;
    }

    setState(() {
      _isGenerating = false;
      _statusMessage = 'Idle';
    });
  }

  Future<void> _runWorkflow() async {
    const Duration stepDelay = Duration(milliseconds: 900);
    await _updateAgent(0, AgentState.running);
    await Future<void>.delayed(stepDelay);
    await _updateAgent(0, AgentState.complete);
    await _updateAgent(1, AgentState.running);

    await Future<void>.delayed(stepDelay);
    await _updateAgent(1, AgentState.complete);
    await _updateAgent(2, AgentState.running);

    await Future<void>.delayed(stepDelay);
    await _updateAgent(2, AgentState.complete);
    await _updateAgent(3, AgentState.running);

    await Future<void>.delayed(stepDelay);
    await _updateAgent(3, AgentState.complete);
  }

  Future<void> _updateAgent(int index, AgentState state) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _agents[index] = AgentStatus(_agents[index].name, state);
    });
  }

  @override
  void dispose() {
    _featureController.dispose();
    super.dispose();
  }

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
    const String architectureSummary = '''Feature: Products\nModel: Product (id, name, price)\nAPI: GET /products, POST /products, PUT /products/{id}, DELETE /products/{id}''';

    return _PanelContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          architectureSummary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
        ),
      ),
    );
  }

  Widget _buildCodeTab(BuildContext context) {
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
          value: _selectedFile,
          onChanged: (String? value) {
            if (value == null) return;
            setState(() => _selectedFile = value);
          },
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
              child: SelectableText(
                _generatedFiles[_selectedFile] ?? '',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTab(BuildContext context) {
    const List<String> comments = <String>[
      'Code structure looks clean.',
      'API endpoints correctly match the spec.',
      'Consider adding validation to the POST endpoint.',
    ];

    return _PanelContainer(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (BuildContext context, int index) {
          final bool isWarning = index == 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                isWarning ? Icons.warning_amber : Icons.check_circle,
                color: isWarning ? Colors.amber[700] : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(comments[index])),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: comments.length,
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
