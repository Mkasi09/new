import 'package:flutter/material.dart';

import '../domain/entities.dart';
import 'widgets/common.dart';

class MaterialsView extends StatelessWidget {
  const MaterialsView({super.key, required this.materials});

  final List<MaterialLine> materials;

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        const SectionTitle('Material Reconciliation'),
        const SizedBox(height: 10),
        ...materials.map(
          (material) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: IconPill(icon: Icons.memory, color: material.color),
                title: Text(
                  material.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${material.serial} - ${material.action}'),
                trailing: StatusChip(
                  label: material.state,
                  color: material.color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan Equipment Barcode'),
        ),
      ],
    );
  }
}
