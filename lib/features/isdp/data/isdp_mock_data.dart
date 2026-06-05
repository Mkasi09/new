import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';

const workOrders = [
  WorkOrder(
    id: 'WO-CMT-ESW-1048',
    site: 'Matsapha Industrial Site 03',
    scope: 'Replace RRU and align sector antenna',
    sla: '11h left',
    siteCode: 'SITE-MAT-03',
    status: 'Onsite',
    priority: Priority.critical,
  ),
  WorkOrder(
    id: 'WO-CMT-ESW-1049',
    site: 'Mbabane Hilltop BTS',
    scope: 'Power alarm fault isolation and battery check',
    sla: '22h left',
    siteCode: 'SITE-MBB-HT',
    status: 'Dispatched',
    priority: Priority.high,
  ),
  WorkOrder(
    id: 'WO-CMT-ESW-1050',
    site: 'Manzini Central Rooftop',
    scope: 'Upload KPIs and as-built photo pack',
    sla: 'Accepted',
    siteCode: 'SITE-MNZ-CR',
    status: 'Complete',
    priority: Priority.low,
  ),
];

const dashboardMetrics = [
  Metric('Open WOs', '18', Icons.assignment_late, AppTheme.primary),
  Metric('High SLA', '5', Icons.timer, AppTheme.warning),
  Metric('Accepted', '42', Icons.verified, AppTheme.success),
  Metric('Blocked Pay', '3', Icons.payments_outlined, AppTheme.danger),
];

const jobSteps = [
  JobStep(
    'Accept dispatch',
    Icons.outbound,
    'ETA submitted to the operations dispatcher.',
  ),
  JobStep(
    'Scan site QR',
    Icons.qr_code_scanner,
    'Scan the site QR code to confirm arrival.',
  ),
  JobStep(
    'Toolbox talk',
    Icons.health_and_safety,
    'PPE photo and safety checklist required.',
  ),
  JobStep(
    'Execute scope',
    Icons.build,
    'Replace RRU, align antenna, capture before/after photos.',
  ),
  JobStep(
    'Scan material SN',
    Icons.qr_code_scanner,
    'Consume issued RRU and return faulty unit.',
  ),
  JobStep(
    'Submit closure',
    Icons.task_alt,
    'Send the completed job to Admin for approval.',
  ),
];

const materials = [
  MaterialLine(
    'RRU 5909',
    'SN: CMT-RRU-874332',
    'Issued to WO-CMT-ESW-1048',
    'Consume',
    AppTheme.primary,
  ),
  MaterialLine(
    'Faulty RRU',
    'SN: OLD-RRU-192840',
    'Return to logistics',
    'Pending',
    AppTheme.warning,
  ),
  MaterialLine(
    'Antenna clamp kit',
    'BOM: CLAMP-KIT-4',
    'Consumed onsite',
    'Matched',
    AppTheme.success,
  ),
];
