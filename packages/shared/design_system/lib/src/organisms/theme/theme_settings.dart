import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../atoms/colors.dart';
import '../../atoms/spacing.dart';
import '../../molecules/buttons/bank_button.dart';
import '../../themes/theme_cubit.dart';

class ThemeSettings extends StatelessWidget {
  const ThemeSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(builder: (context, state) {
      return Padding(
        padding: EdgeInsets.all(BankSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações de Tema',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: BankSpacing.md),

            
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(BankSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo de Tema',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: BankSpacing.sm),
                    _buildThemeModeSelection(context, state),
                  ],
                ),
              ),
            ),

            SizedBox(height: BankSpacing.md),

            
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(BankSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cor do Tema',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: BankSpacing.sm),
                    _buildColorSelection(context, state),
                  ],
                ),
              ),
            ),

            SizedBox(height: BankSpacing.lg),

            
            BankButton(
              label: 'Restaurar Tema Padrão',
              importance: BankButtonImportance.secondary,
              onPressed: () {
                context.read<ThemeCubit>().resetToDefaultTheme();
              },
              isFullWidth: true,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildThemeModeSelection(BuildContext context, ThemeState state) {
    return Wrap(
      spacing: BankSpacing.sm,
      children: [
        _buildThemeModeOption(
          context: context,
          title: 'Sistema',
          icon: Icons.brightness_auto,
          isSelected: state.themeMode == ThemeMode.system,
          onTap: () =>
              context.read<ThemeCubit>().setThemeMode(ThemeMode.system),
        ),
        _buildThemeModeOption(
          context: context,
          title: 'Claro',
          icon: Icons.brightness_5,
          isSelected: state.themeMode == ThemeMode.light,
          onTap: () => context.read<ThemeCubit>().setThemeMode(ThemeMode.light),
        ),
        _buildThemeModeOption(
          context: context,
          title: 'Escuro',
          icon: Icons.brightness_3,
          isSelected: state.themeMode == ThemeMode.dark,
          onTap: () => context.read<ThemeCubit>().setThemeMode(ThemeMode.dark),
        ),
      ],
    );
  }

  Widget _buildThemeModeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(BankSpacing.sm),
        decoration: BoxDecoration(
          color:
              isSelected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 24,
            ),
            SizedBox(height: BankSpacing.xs),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelection(BuildContext context, ThemeState state) {
    final List<Color> colorOptions = [
      BankColors.brandPrimary,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.teal,
      Colors.blue,
    ];

    return Wrap(
      spacing: BankSpacing.sm,
      runSpacing: BankSpacing.sm,
      children: colorOptions.map((color) {
        final isSelected = state.seedColor.value == color.value;

        return InkWell(
          onTap: () => context.read<ThemeCubit>().setSeedColor(color),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onBackground
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
