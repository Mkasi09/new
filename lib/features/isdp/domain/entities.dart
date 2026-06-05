import 'package:flutter/material.dart';

enum Priority {
  critical('Critical'),
  high('High'),
  low('Low');

  const Priority(this.label);
  final String label;
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.site,
    required this.scope,
    required this.sla,
    required this.siteCode,
    required this.status,
    required this.priority,
  });

  final String id;
  final String site;
  final String scope;
  final String sla;
  final String siteCode;
  final String status;
  final Priority priority;
}

class Metric {
  const Metric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class JobStep {
  const JobStep(this.title, this.icon, this.detail);

  final String title;
  final IconData icon;
  final String detail;
}

class MaterialLine {
  const MaterialLine(
    this.name,
    this.serial,
    this.action,
    this.state,
    this.color,
  );

  final String name;
  final String serial;
  final String action;
  final String state;
  final Color color;
}
