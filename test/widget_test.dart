import 'package:flutter_test/flutter_test.dart';
import 'package:isdp/app/isdp_app.dart';
import 'package:isdp/core/domain/app_role.dart';
import 'package:isdp/features/isdp/presentation/isdp_shell.dart';

void main() {
  testWidgets('technician sees on-site workflow', (tester) async {
    await tester.pumpWidget(const IsdpApp(home: IsdpShell()));

    expect(find.text('Commit ISDP'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('On-site Steps'), findsOneWidget);
    expect(find.text('Scan site QR'), findsOneWidget);
    expect(find.text('Matsapha Industrial Site 03'), findsWidgets);
  });

  testWidgets('admin sees approval queue', (tester) async {
    await tester.pumpWidget(
      const IsdpApp(home: IsdpShell(initialRole: AppRole.admin)),
    );

    expect(find.text('Admin Review'), findsOneWidget);
    expect(find.text('Needs Approval'), findsOneWidget);
    expect(find.text('Admin Tools'), findsOneWidget);
  });

  testWidgets('supervisor sees team board', (tester) async {
    await tester.pumpWidget(
      const IsdpApp(home: IsdpShell(initialRole: AppRole.supervisor)),
    );

    expect(find.text('Team Board'), findsOneWidget);
    expect(find.text('Deadline Watch'), findsOneWidget);
    expect(find.text('Assign Tech'), findsOneWidget);
  });
}
