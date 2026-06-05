import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import 'qr_arrival_scan_screen.dart';
import 'widgets/common.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.role,
    required this.selectedOrder,
    required this.workOrders,
    required this.jobSteps,
    required this.materials,
    required this.onOpenOrder,
  });

  final AppRole role;
  final WorkOrder selectedOrder;
  final List<WorkOrder> workOrders;
  final List<JobStep> jobSteps;
  final List<MaterialLine> materials;
  final ValueChanged<WorkOrder> onOpenOrder;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _arrivalVerified = false;

  @override
  Widget build(BuildContext context) {
    return switch (widget.role) {
      AppRole.admin => _AdminHome(
        workOrders: widget.workOrders,
        onOpenOrder: widget.onOpenOrder,
      ),
      AppRole.supervisor => _SupervisorHome(
        workOrders: widget.workOrders,
        selectedOrder: widget.selectedOrder,
        onOpenOrder: widget.onOpenOrder,
      ),
      AppRole.technician => _TechnicianHome(
        order: widget.selectedOrder,
        jobSteps: widget.jobSteps,
        materials: widget.materials,
        arrivalVerified: _arrivalVerified,
        onScanSiteQr: _scanSiteQr,
        onOpenOrder: widget.onOpenOrder,
      ),
    };
  }

  Future<void> _scanSiteQr(BuildContext context) async {
    final matched = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => QrArrivalScanScreen(order: widget.selectedOrder),
      ),
    );

    if (!context.mounted || matched == null) return;

    setState(() => _arrivalVerified = matched);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          matched
              ? 'Arrival verified for ${widget.selectedOrder.site}.'
              : 'QR code does not match this work order.',
        ),
      ),
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({required this.workOrders, required this.onOpenOrder});

  final List<WorkOrder> workOrders;
  final ValueChanged<WorkOrder> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final open = workOrders.where((order) => order.status != 'Complete').length;
    final done = workOrders.where((order) => order.status == 'Complete').length;
    final approvalQueue = workOrders
        .where((order) => order.status == 'Complete')
        .toList();

    return AppScrollView(
      children: [
        const _RoleHero(
          icon: Icons.approval_outlined,
          title: 'Admin Review',
          subtitle: 'Create jobs, check progress, and approve completed work.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricTile(value: '$open', label: 'Open jobs'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(value: '$done', label: 'Ready'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Needs Approval'),
        const SizedBox(height: 10),
        if (approvalQueue.isEmpty)
          const _EmptyRoleCard(
            icon: Icons.verified_outlined,
            title: 'No jobs waiting',
            detail: 'Completed work from technicians will appear here.',
          )
        else
          ...approvalQueue.map(
            (order) =>
                _ApprovalCard(order: order, onTap: () => onOpenOrder(order)),
          ),
        const SizedBox(height: 18),
        const SectionTitle('Admin Tools'),
        const SizedBox(height: 10),
        const _ActionGrid(
          actions: [
            _RoleAction(Icons.add_task, 'Create job'),
            _RoleAction(Icons.fact_check_outlined, 'Approve'),
            _RoleAction(Icons.analytics_outlined, 'Reports'),
          ],
        ),
      ],
    );
  }
}

class _SupervisorHome extends StatelessWidget {
  const _SupervisorHome({
    required this.workOrders,
    required this.selectedOrder,
    required this.onOpenOrder,
  });

  final List<WorkOrder> workOrders;
  final WorkOrder selectedOrder;
  final ValueChanged<WorkOrder> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final activeJobs = workOrders
        .where((order) => order.status != 'Complete')
        .toList();

    return AppScrollView(
      children: [
        const _RoleHero(
          icon: Icons.groups_2_outlined,
          title: 'Team Board',
          subtitle: 'Assign technicians and keep site work inside deadline.',
        ),
        const SizedBox(height: 14),
        _AssignmentPanel(order: selectedOrder),
        const SizedBox(height: 18),
        const SectionTitle('Deadline Watch'),
        const SizedBox(height: 10),
        ...activeJobs.map(
          (order) =>
              _DeadlineCard(order: order, onTap: () => onOpenOrder(order)),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Supervisor Actions'),
        const SizedBox(height: 10),
        const _ActionGrid(
          actions: [
            _RoleAction(Icons.person_add_alt, 'Assign'),
            _RoleAction(Icons.timer_outlined, 'SLA'),
            _RoleAction(Icons.call_outlined, 'Follow up'),
          ],
        ),
      ],
    );
  }
}

class _TechnicianHome extends StatelessWidget {
  const _TechnicianHome({
    required this.order,
    required this.jobSteps,
    required this.materials,
    required this.arrivalVerified,
    required this.onScanSiteQr,
    required this.onOpenOrder,
  });

  final WorkOrder order;
  final List<JobStep> jobSteps;
  final List<MaterialLine> materials;
  final bool arrivalVerified;
  final ValueChanged<BuildContext> onScanSiteQr;
  final ValueChanged<WorkOrder> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final nextSteps = jobSteps.take(4).toList();

    return AppScrollView(
      children: [
        _TechnicianHero(order: order),
        const SizedBox(height: 14),
        WorkOrderCard(order: order, onTap: () => onOpenOrder(order)),
        const SizedBox(height: 14),
        const SectionTitle('On-site Steps'),
        const SizedBox(height: 10),
        ...List.generate(nextSteps.length, (index) {
          final step = nextSteps[index];
          return _StepRow(
            step: step,
            complete: _isStepComplete(index),
            onTap: step.title == 'Scan site QR'
                ? () => onScanSiteQr(context)
                : null,
          );
        }),
        const SizedBox(height: 14),
        const SectionTitle('Before Submit'),
        const SizedBox(height: 10),
        _CloseChecklist(
          arrivalVerified: arrivalVerified,
          materialsPending: materials.length,
        ),
      ],
    );
  }

  bool _isStepComplete(int index) {
    if (index == 0) return true;
    if (jobSteps[index].title == 'Scan site QR') return arrivalVerified;
    return false;
  }
}

class _RoleHero extends StatelessWidget {
  const _RoleHero({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianHero extends StatelessWidget {
  const _TechnicianHero({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.site} - ${order.sla}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.order, required this.onTap});

  final WorkOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: const IconPill(
            icon: Icons.verified_outlined,
            color: AppTheme.success,
          ),
          title: Text(
            order.site,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${order.id} - Review photos, materials, and sign-off',
          ),
          trailing: FilledButton(
            onPressed: () {},
            child: const Text('Approve'),
          ),
        ),
      ),
    );
  }
}

class _AssignmentPanel extends StatelessWidget {
  const _AssignmentPanel({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Job',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              order.site,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(order.scope, style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Assign Tech'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.message_outlined),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({required this.order, required this.onTap});

  final WorkOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: IconPill(icon: Icons.timer_outlined, color: _slaColor),
          title: Text(
            order.site,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text('${order.status} - ${order.scope}'),
          trailing: StatusChip(label: order.sla, color: _slaColor),
        ),
      ),
    );
  }

  Color get _slaColor {
    return order.priority == Priority.critical
        ? AppTheme.danger
        : AppTheme.warning;
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_RoleAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      child: Column(
                        children: [
                          Icon(action.icon, color: AppTheme.primary),
                          const SizedBox(height: 6),
                          Text(
                            action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RoleAction {
  const _RoleAction(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _EmptyRoleCard extends StatelessWidget {
  const _EmptyRoleCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            IconPill(icon: icon, color: AppTheme.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(detail, style: const TextStyle(color: AppTheme.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.complete, this.onTap});

  final JobStep step;
  final bool complete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.success : AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: IconPill(
            icon: complete ? Icons.check_circle : step.icon,
            color: color,
          ),
          title: Text(
            step.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(step.detail),
          trailing: complete
              ? const Text(
                  'Done',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : onTap == null
              ? null
              : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _CloseChecklist extends StatelessWidget {
  const _CloseChecklist({
    required this.arrivalVerified,
    required this.materialsPending,
  });

  final bool arrivalVerified;
  final int materialsPending;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ChecklistLine(
              icon: Icons.qr_code_scanner,
              title: 'Site QR verified',
              detail: 'Technician arrival confirmed onsite',
              complete: arrivalVerified,
            ),
            const Divider(),
            _ChecklistLine(
              icon: Icons.camera_alt_outlined,
              title: 'Photos captured',
              detail: 'Before, after, safety, and site evidence',
              complete: true,
            ),
            const Divider(),
            _ChecklistLine(
              icon: Icons.inventory_2_outlined,
              title: 'Materials checked',
              detail: '$materialsPending stock lines to confirm',
              complete: false,
            ),
            const Divider(),
            _ChecklistLine(
              icon: Icons.verified_outlined,
              title: 'Admin approval',
              detail: 'Required before finance invoices',
              complete: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({
    required this.icon,
    required this.title,
    required this.detail,
    required this.complete,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.success : AppTheme.warning;
    return Row(
      children: [
        IconPill(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(color: AppTheme.muted)),
            ],
          ),
        ),
        Icon(
          complete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
        ),
      ],
    );
  }
}
