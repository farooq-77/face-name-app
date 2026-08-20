import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../models/recognition_result.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../faces/my_faces_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _api = ApiService();
  final _auth = AuthService();

  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _camera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (picked != null) await _processFiles([File(picked.path)]);
  }

  Future<void> _gallery() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (picked.isNotEmpty) {
      await _processFiles(picked.map((e) => File(e.path)).toList());
    }
  }

  Future<void> _processFiles(List<File> files) async {
    if (!AppConfig.apiConfigured) {
      _message('Backend API URL is not configured.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Processing ${files.length} image(s)…';
    });

    try {
      for (var i = 0; i < files.length; i++) {
        if (!mounted) return;
        setState(() => _status = 'Recognizing image ${i + 1}/${files.length}…');
        final result = await _api.recognize(files[i]);
        if (!mounted) return;
        await _showResult(files[i], result);
      }
    } on ApiException catch (e) {
      _message(e.message);
    } catch (e) {
      _message('Could not process image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _showResult(File file, RecognitionResponse result) async {
    if (result.faces.isEmpty) {
      _message('No face was detected in this image.');
      return;
    }

    final mutable = List<RecognizedFace>.from(result.faces);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> tagFace(int listIndex) async {
              final face = mutable[listIndex];
              final name = await _askTag(sheetContext);
              if (name == null || name.trim().isEmpty) return;

              try {
                final saved = await _api.enroll(
                  image: file,
                  faceIndex: face.index,
                  name: name,
                );
                setSheetState(() {
                  mutable[listIndex] = face.tagged(saved.name, saved.id);
                });
              } on ApiException catch (e) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mutable.length} face${mutable.length == 1 ? '' : 's'} detected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: mutable.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, index) {
                            final face = mutable[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text('${face.index + 1}'),
                              ),
                              title: Text(
                                face.matched
                                    ? (face.name ?? 'Matched face')
                                    : 'Unknown face',
                              ),
                              subtitle: face.matched
                                  ? Text(
                                      face.similarity == null
                                          ? 'Saved face'
                                          : 'Similarity ${(face.similarity! * 100).toStringAsFixed(1)}%',
                                    )
                                  : const Text('Add a name to remember this person'),
                              trailing: face.matched
                                  ? const Icon(Icons.check_circle_outline)
                                  : FilledButton(
                                      onPressed: () => tagFace(index),
                                      child: const Text('Tag'),
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
          },
        );
      },
    );
  }

  Future<String?> _askTag(BuildContext dialogContext) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Name this face'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Ali, Sara, Farooq',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final display = user?.displayName?.trim();
    final greeting = user?.isAnonymous == true
        ? 'Hello, Guest'
        : 'Hello, ${display?.isNotEmpty == true ? display : user?.email ?? 'there'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Name'),
        actions: [
          IconButton(
            tooltip: 'My saved faces',
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MyFacesScreen(),
                      ),
                    ),
            icon: const Icon(Icons.people_outline),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') await _auth.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text(
              'Take a photo or choose images. Known faces are identified automatically; unknown faces can be tagged.',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.face, size: 72),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _camera,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take a photo'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _gallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose from gallery'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              Text(_status ?? 'Processing…', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            const Card(
              child: ListTile(
                leading: Icon(Icons.privacy_tip_outlined),
                title: Text('Private by user account'),
                subtitle: Text(
                  'Face templates are compared only against the signed-in user’s private database.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
