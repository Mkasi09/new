import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';

const dashboardMetrics = [
  Metric('Open Jobs', '18', Icons.assignment_late, AppTheme.primary),
  Metric('Due Soon', '5', Icons.timer, AppTheme.warning),
  Metric('Accepted', '42', Icons.verified, AppTheme.success),
  Metric('Blocked Pay', '3', Icons.payments_outlined, AppTheme.danger),
];

const jobSteps = [
  JobStep(
    'Review job details',
    Icons.assignment_turned_in_outlined,
    'Check the customer request, location, contact person, and expected outcome.',
  ),
  JobStep(
    'Confirm arrival',
    Icons.qr_code_scanner,
    'Confirm that the technician has arrived at the correct site.',
  ),
  JobStep(
    'Complete safety check',
    Icons.health_and_safety,
    'Record access notes, hazards, and any safety checks before work starts.',
  ),
  JobStep(
    'Perform the service work',
    Icons.build,
    'Fix the issue, test the result, and record what was done.',
  ),
  JobStep(
    'Record parts and notes',
    Icons.qr_code_scanner,
    'Log any parts used, returned items, customer notes, or follow-up work.',
  ),
  JobStep(
    'Submit service report',
    Icons.task_alt,
    'Upload photos, notes, customer sign-off, and submit for admin approval.',
  ),
];

const materials = [
  MaterialLine(
    'Wi-Fi router',
    'SN: RTR-874332',
    'Issued to active job',
    'Install',
    AppTheme.primary,
  ),
  MaterialLine(
    'Faulty router',
    'SN: OLD-RTR-192840',
    'Return to logistics',
    'Pending',
    AppTheme.warning,
  ),
  MaterialLine(
    'Network cable kit',
    'BOM: CABLE-KIT-4',
    'Used onsite',
    'Matched',
    AppTheme.success,
  ),
];
