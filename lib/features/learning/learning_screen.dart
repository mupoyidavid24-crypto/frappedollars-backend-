import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/constants.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  List<Map<String, dynamic>> _contents = [];

  @override
  void initState() {
    super.initState();
    _loadContent();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadContent(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContent({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    try {
      final response = await _client
          .from('learning_content')
          .select('id, title, description, category, created_at')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _contents = List<Map<String, dynamic>>.from(response as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Learning content refresh error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centre d\'Apprentissage')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contents.isEmpty
              ? const Center(child: Text('Aucun tutoriel disponible pour le moment.'))
              : RefreshIndicator(
                  onRefresh: () => _loadContent(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contents.length,
                    itemBuilder: (context, index) {
                      final item = _contents[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 150,
                              width: double.infinity,
                              color: const Color(AppConstants.primaryColor).withValues(red: 255, green: 255, blue: 255, alpha: 100),
                              child: const Icon(Icons.play_circle_fill, size: 60, color: Colors.white),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(AppConstants.primaryColor),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['category']?.toString() ?? 'TUTO',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item['title']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['description']?.toString() ?? '',
                                    style: const TextStyle(color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}