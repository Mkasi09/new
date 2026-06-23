import 'package:flutter/material.dart';

import '../../../core/domain/app_role.dart';

class EmptyJobsView extends StatelessWidget {
  const EmptyJobsView({
    super.key,
    required this.role,
    required this.onCreateJob,
    this.onOpenReviewQueue,
    this.onOpenAnalytics,
    this.onAddUser,
  });

  final AppRole role;
  final VoidCallback onCreateJob;
  final VoidCallback? onOpenReviewQueue;
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onAddUser;

  @override
  Widget build(BuildContext context) {
    final canCreate = role == AppRole.admin;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No jobs yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    canCreate
                        ? 'Create the first Firebase job to start the workflow.'
                        : 'Jobs assigned to your team will appear here.',
                    textAlign: TextAlign.center,
                  ),
                  if (canCreate) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('empty-create-job-button'),
                      onPressed: onCreateJob,
                      icon: const Icon(Icons.add_task),
                      label: const Text('Create Job'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (onOpenReviewQueue != null)
                          OutlinedButton.icon(
                            onPressed: onOpenReviewQueue,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Review'),
                          ),
                        if (onOpenAnalytics != null)
                          OutlinedButton.icon(
                            onPressed: onOpenAnalytics,
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('Analytics'),
                          ),
                        if (onAddUser != null)
                          OutlinedButton.icon(
                            onPressed: onAddUser,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Add User'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
