
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TriageApp());
}

class TriageApp extends StatelessWidget {
  const TriageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Search Term Triage',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF245B91),
        ),
      ),
      home: const TriageHome(),
    );
  }
}

class TriageHome extends StatefulWidget {
  const TriageHome({super.key});

  @override
  State<TriageHome> createState() => _TriageHomeState();
}

class _TriageHomeState extends State<TriageHome> {
  static const String apiUrl =
      'http://127.0.0.1:8000/triage/upload';

  bool loading = false;
  String message = 'Upload your Google Ads CSV to begin.';
  Map<String, dynamic>? report;
  String filter = 'all';

  Future<void> uploadCsv() async {
    final input = html.FileUploadInputElement()
      ..accept = '.csv,text/csv';

    input.click();
    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) return;

    final file = files.first;

    setState(() {
      loading = true;
      report = null;
      message = 'Analyzing search terms...';
    });

    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final result = reader.result;
      if (result == null) {
        throw Exception('Could not read the CSV file.');
      }

      final bytes = (result as List<int>);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          body is Map
              ? body['detail'] ?? 'Upload failed'
              : 'Upload failed',
        );
      }

      setState(() {
        report = Map<String, dynamic>.from(body);
        message = 'Analysis completed: ${file.name}';
        filter = 'all';
      });
    } catch (e) {
      setState(() {
        message = 'Upload error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Color decisionColor(String decision) {
    switch (decision) {
      case 'promote':
        return Colors.green;
      case 'block':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget metricCard(
      String title,
      dynamic value,
      IconData icon,
      Color color,
      ) {
    return SizedBox(
      width: 145,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  Widget resultCard(Map<String, dynamic> row) {
    final decision = row['decision'] as String;
    final color = decisionColor(decision);
    final confidence =
    ((row['confidence'] as num) * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['query']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(decision.toUpperCase()),
                  backgroundColor: color.withAlpha(35),
                  side: BorderSide(color: color),
                ),
                Chip(label: Text('$confidence% confidence')),
              ],
            ),
            Text('${row['reason']}'),
            const SizedBox(height: 10),
            Text(
              'Clicks: ${row['clicks']} | '
                  'Cost: ${row['cost']} | '
                  'Conversions: ${row['conversions']}',
            ),
            if (row['review_required'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: Colors.deepOrange,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Human review required',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = (report?['results'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
    filter == 'all' || item['decision'] == filter)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Term Triage',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF173F68),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF173F68),
                  Color(0xFF327BB7),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.query_stats,
                  color: Colors.white,
                  size: 42,
                ),
                SizedBox(height: 14),
                Text(
                  'Make smarter search decisions.',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Analyze search terms, understand decisions, '
                      'and flag uncertain cases for human review.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'PS-01 | Search Term Triage Engine',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: loading ? null : uploadCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Search-Term CSV'),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          SelectableText(message),
          if (report != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Analysis Overview',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                metricCard(
                  'Total Terms',
                  report!['total_terms'],
                  Icons.search,
                  Colors.blue,
                ),
                metricCard(
                  'Promote',
                  report!['promote'],
                  Icons.trending_up,
                  Colors.green,
                ),
                metricCard(
                  'Block',
                  report!['block'],
                  Icons.block,
                  Colors.red,
                ),
                metricCard(
                  'Ignore',
                  report!['ignore'],
                  Icons.remove_circle_outline,
                  Colors.orange,
                ),
                metricCard(
                  'Needs Review',
                  report!['review_required'],
                  Icons.rate_review_outlined,
                  Colors.deepOrange,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Search Term Decisions',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: filter,
              decoration: const InputDecoration(
                labelText: 'Filter decisions',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All decisions'),
                ),
                DropdownMenuItem(
                  value: 'promote',
                  child: Text('Promote'),
                ),
                DropdownMenuItem(
                  value: 'block',
                  child: Text('Block'),
                ),
                DropdownMenuItem(
                  value: 'ignore',
                  child: Text('Ignore'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => filter = value);
                }
              },
            ),
            const SizedBox(height: 12),
            if (results.isEmpty)
              const Text('No results match this filter.'),
            ...results.map(resultCard),
          ],
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'PS-01 Hackathon Prototype',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
