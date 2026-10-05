import 'dart:io';

import 'package:flutter/material.dart';

enum ReviewChoice { use, retake }

/// Lets the user check a photo or PDF before it is sent to be read.
/// Pops with a [ReviewChoice]; going back pops with null, which means cancel.
class ReviewScreen extends StatelessWidget {
  final File file;
  final bool isPdf;

  const ReviewScreen({super.key, required this.file, required this.isPdf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = file.path.split(RegExp(r'[\\/]')).last;
    return Scaffold(
      appBar: AppBar(title: const Text('Check your report')),
      body: Column(
        children: [
          Expanded(
            child: isPdf
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(name, textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  )
                : InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: Image.file(
                        file,
                        errorBuilder: (_, _, _) =>
                            const Text('This image cannot be shown.'),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isPdf
                        ? 'Is this the right file?'
                        : 'Is the whole report in view and easy to read?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, ReviewChoice.use),
                    child: Text(isPdf ? 'Use this file' : 'Use this photo'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, ReviewChoice.retake),
                    child: Text(isPdf ? 'Choose another' : 'Retake'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
