import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class JobCardView extends StatefulWidget {
  const JobCardView({super.key, required this.order, required this.jobSteps});

  final WorkOrder order;
  final List<JobStep> jobSteps;

  @override
  State<JobCardView> createState() => _JobCardViewState();
}

class _JobCardViewState extends State<JobCardView> {
  final Set<int> _done = {0, 1};

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        WorkOrderCard(order: widget.order, onTap: () {}),
        const SizedBox(height: 14),
        const SectionTitle('Onsite Job Card'),
        const SizedBox(height: 10),
        ...List.generate(widget.jobSteps.length, (index) {
          final step = widget.jobSteps[index];
          final isDone = _done.contains(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: CheckboxListTile(
                value: isDone,
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      _done.add(index);
                    } else {
                      _done.remove(index);
                    }
                  });
                },
                secondary: IconPill(
                  icon: step.icon,
                  color: isDone ? AppTheme.success : AppTheme.primary,
                ),
                title: Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(step.detail),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Add Photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Signature'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
