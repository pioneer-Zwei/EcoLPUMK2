import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/eco_styles.dart';
import 'minigames/firefly.dart';

class MinigamesPage extends StatelessWidget {
  const MinigamesPage({super.key});

  Widget _budujOpcje(
      BuildContext context, IconData icon, String label, VoidCallback onTapAction) {
    return InkWell(
      onTap: onTapAction,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryRed, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.bodyText.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pokazWkrotce(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName is coming soon!'),
        backgroundColor: AppTheme.primaryRed,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.bgColor,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppTheme.darkText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.primaryRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.gamepad2, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Minigames", style: AppTheme.headline1),
                Text("BAU.", style: AppTheme.subtitle),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final crossAxisCount = isWide ? 4 : 2;
            final padding = isWide ? 24.0 : 16.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "BAU BAU",
                    style: AppTheme.headline2.copyWith(color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 24),
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.0,
                    children: [
                      _budujOpcje(
                        context,
                        LucideIcons.trash2,
                        'G1',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RPSGamePage()),
                          );
                        },
                      ),
                      _budujOpcje(
                        context,
                        LucideIcons.trash2,
                        'G2',
                        () => _pokazWkrotce(context, 'G2'),
                      ),
                      _budujOpcje(
                        context,
                        LucideIcons.bookOpen,
                        'G3',
                        () => _pokazWkrotce(context, 'G3'),
                      ),
                      _budujOpcje(
                        context,
                        LucideIcons.puzzle,
                        'G4',
                        () => _pokazWkrotce(context, 'G4'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}