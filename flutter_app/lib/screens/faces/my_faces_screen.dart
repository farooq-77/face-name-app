import 'package:flutter/material.dart';

import '../../models/recognition_result.dart';
import '../../services/api_service.dart';

class MyFacesScreen extends StatefulWidget {
  const MyFacesScreen({super.key});

  @override
  State<MyFacesScreen> createState() => _MyFacesScreenState();
}

class _MyFacesScreenState extends State<MyFacesScreen> {
  final _api = ApiService();
  late Future<List<SavedFace>> _faces;

  @override
  void initState() {
    super.initState();
    _faces = _api.listFaces();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _delete(SavedFace face) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${face.name}?'),
        content: const Text(
          'This permanently removes the stored facial template for this person.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.deleteFace(face.id);
      setState(() => _faces = _api.listFaces());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My saved faces')),
      body: FutureBuilder<List<SavedFace>>(
        future: _faces,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load faces: ${snapshot.error}'),
              ),
            );
          }

          final faces = snapshot.data ?? const [];
          if (faces.isEmpty) {
            return const Center(child: Text('No faces have been tagged yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _faces = _api.listFaces());
              await _faces;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: faces.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, index) {
                final face = faces[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(face.name),
                  subtitle: Text('ID: ${face.id}'),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(face),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
