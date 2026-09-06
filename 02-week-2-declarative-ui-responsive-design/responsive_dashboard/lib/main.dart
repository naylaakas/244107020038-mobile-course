import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';

const kWideBreakpoint = 700.0;
void main() => runApp(const DashboardApp());

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key});

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: Colors.indigo),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: DashboardPage(
        isDark: isDark,
        onDarkChanged: (value) => setState(() => isDark = value),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.isDark,
    required this.onDarkChanged,
    super.key,
  });

  final bool isDark;
  final ValueChanged<bool> onDarkChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Overview'),
        actions: [
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
              ),
              const SizedBox(width: 4),
              Semantics(
                label: 'Dark mode',
                toggled: isDark,
                child: CupertinoSwitch(
                  value: isDark,
                  onChanged: onDarkChanged,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= kWideBreakpoint ? 2 : 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // HEADER PROFIL
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        child: Icon(Icons.person, size: 32),
                      ),
                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student Profile',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: 4),
                            Text('Nama: Nayla Akas Oktavia'),
                            Text('NIM: 244107020038'),
                            Text('Teknik Informatika'),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),

                // KARTU INFORMASI
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.6,
                      children: const [
                        InfoCard(
                          title: 'Assignments',
                          value: '8',
                        ),
                        InfoCard(
                          title: 'Attendance',
                          value: '92%',
                        ),
                        InfoCard(
                          title: 'Portfolio',
                          value: 'Ready',
                        ),
                        InfoCard(
                          title: 'Current Week',
                          value: '02',
                        ),
                      ],
                    ),   
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.title,
    required this.value,
    super.key,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $value',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge,
              ),
            ),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}