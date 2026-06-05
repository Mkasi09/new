enum AppRole {
  admin('Admin / Company'),
  supervisor('Supervisor / Team Leader'),
  technician('Technician');

  const AppRole(this.label);
  final String label;

  static AppRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'admin':
        return AppRole.admin;
      case 'supervisor':
        return AppRole.supervisor;
      case 'technician':
      case 'tech':
        return AppRole.technician;
      default:
        return AppRole.technician;
    }
  }
}
