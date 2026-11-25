// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';

import '../data/public_catalog.dart';

/// Shown on the landing page: total slots and today's availability.
class SlotSummaryBanner extends StatefulWidget {
  const SlotSummaryBanner({required this.onBook, super.key});

  final VoidCallback onBook;

  @override
  State<SlotSummaryBanner> createState() => _SlotSummaryBannerState();
}

class _SlotSummaryBannerState extends State<SlotSummaryBanner> {
  late final Future<PublicCatalog> _future = PublicCatalog.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PublicCatalog>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final c = snapshot.data!;
        final s = c.summaryFor(DateTime.now());
        return Container(
          width: double.infinity,
          color: const Color(0xFFFFF1DC),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 10,
            children: [
              Text('${c.slotsPerDay} slots every day • ${s.total} total today • ${s.free} available now',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              FilledButton.icon(
                onPressed: widget.onBook,
                icon: const Icon(Icons.event_available),
                label: const Text('View & book slots'),
              ),
            ],
          ),
        );
      },
    );
  }
}
