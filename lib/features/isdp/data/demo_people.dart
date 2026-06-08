import '../../../core/domain/app_role.dart';

class DemoPerson {
  const DemoPerson({
    required this.name,
    required this.email,
    required this.team,
    required this.role,
  });

  final String name;
  final String email;
  final String team;
  final AppRole role;
}

const demoAdmin = DemoPerson(
  name: 'Admin Control',
  email: 'admin@commit.co.sz',
  team: 'Operations',
  role: AppRole.admin,
);

const demoSupervisors = [
  DemoPerson(
    name: 'Mandla Dlamini',
    email: 'mandla@commit.co.sz',
    team: 'North Region',
    role: AppRole.supervisor,
  ),
];

const demoTechnicians = [
  DemoPerson(
    name: 'Sibusiso M.',
    email: 'sibusiso@commit.co.sz',
    team: 'Field Team A',
    role: AppRole.technician,
  ),
  DemoPerson(
    name: 'Thabo M.',
    email: 'thabo.tech@commit.co.sz',
    team: 'Field Team B',
    role: AppRole.technician,
  ),
  DemoPerson(
    name: 'Lindiwe S.',
    email: 'lindiwe.tech@commit.co.sz',
    team: 'Field Team C',
    role: AppRole.technician,
  ),
];

List<DemoPerson> demoPeopleForRole(AppRole role) {
  return switch (role) {
    AppRole.admin => const [demoAdmin],
    AppRole.supervisor => demoSupervisors,
    AppRole.technician => demoTechnicians,
  };
}

DemoPerson defaultDemoPersonForRole(AppRole role) {
  return demoPeopleForRole(role).first;
}
