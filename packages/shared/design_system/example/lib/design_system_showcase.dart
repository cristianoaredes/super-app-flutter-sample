import 'package:flutter/material.dart';


class DesignSystemShowcase extends StatelessWidget {
  const DesignSystemShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design System Showcase'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Typography',
              _buildTypographyShowcase(context),
            ),
            _buildSection(
              'Colors',
              _buildColorsShowcase(context),
            ),
            _buildSection(
              'Buttons',
              _buildButtonsShowcase(context),
            ),
            _buildSection(
              'Inputs',
              _buildInputsShowcase(context),
            ),
            _buildSection(
              'Cards',
              _buildCardsShowcase(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16.0),
        content,
        const SizedBox(height: 32.0),
        const Divider(),
        const SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildTypographyShowcase(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Display Large', style: textTheme.displayLarge),
        Text('Display Medium', style: textTheme.displayMedium),
        Text('Display Small', style: textTheme.displaySmall),
        Text('Headline Large', style: textTheme.headlineLarge),
        Text('Headline Medium', style: textTheme.headlineMedium),
        Text('Headline Small', style: textTheme.headlineSmall),
        Text('Title Large', style: textTheme.titleLarge),
        Text('Title Medium', style: textTheme.titleMedium),
        Text('Title Small', style: textTheme.titleSmall),
        Text('Body Large', style: textTheme.bodyLarge),
        Text('Body Medium', style: textTheme.bodyMedium),
        Text('Body Small', style: textTheme.bodySmall),
        Text('Label Large', style: textTheme.labelLarge),
        Text('Label Medium', style: textTheme.labelMedium),
        Text('Label Small', style: textTheme.labelSmall),
      ],
    );
  }

  Widget _buildColorsShowcase(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 16.0,
      runSpacing: 16.0,
      children: [
        _buildColorItem('Primary', colorScheme.primary),
        _buildColorItem('On Primary', colorScheme.onPrimary),
        _buildColorItem('Primary Container', colorScheme.primaryContainer),
        _buildColorItem('On Primary Container', colorScheme.onPrimaryContainer),
        _buildColorItem('Secondary', colorScheme.secondary),
        _buildColorItem('On Secondary', colorScheme.onSecondary),
        _buildColorItem('Secondary Container', colorScheme.secondaryContainer),
        _buildColorItem(
            'On Secondary Container', colorScheme.onSecondaryContainer),
        _buildColorItem('Tertiary', colorScheme.tertiary),
        _buildColorItem('On Tertiary', colorScheme.onTertiary),
        _buildColorItem('Tertiary Container', colorScheme.tertiaryContainer),
        _buildColorItem(
            'On Tertiary Container', colorScheme.onTertiaryContainer),
        _buildColorItem('Error', colorScheme.error),
        _buildColorItem('On Error', colorScheme.onError),
        _buildColorItem('Error Container', colorScheme.errorContainer),
        _buildColorItem('On Error Container', colorScheme.onErrorContainer),
        _buildColorItem('Background', colorScheme.background),
        _buildColorItem('On Background', colorScheme.onBackground),
        _buildColorItem('Surface', colorScheme.surface),
        _buildColorItem('On Surface', colorScheme.onSurface),
        _buildColorItem('Surface Variant', colorScheme.surfaceVariant),
        _buildColorItem('On Surface Variant', colorScheme.onSurfaceVariant),
        _buildColorItem('Outline', colorScheme.outline),
        _buildColorItem('Shadow', colorScheme.shadow),
        _buildColorItem('Inverse Surface', colorScheme.inverseSurface),
        _buildColorItem('On Inverse Surface', colorScheme.onInverseSurface),
        _buildColorItem('Inverse Primary', colorScheme.inversePrimary),
      ],
    );
  }

  Widget _buildColorItem(String name, Color color) {
    return Column(
      children: [
        Container(
          width: 80.0,
          height: 80.0,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          name,
          style: const TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
          style: const TextStyle(
            fontSize: 10.0,
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildButtonsShowcase(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            ElevatedButton(
              onPressed: () {},
              child: const Text('Elevated Button'),
            ),
            FilledButton(
              onPressed: () {},
              child: const Text('Filled Button'),
            ),
            FilledButton.tonal(
              onPressed: () {},
              child: const Text('Filled Tonal Button'),
            ),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Outlined Button'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Text Button'),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Elevated Icon Button'),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Filled Icon Button'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Filled Tonal Icon Button'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Outlined Icon Button'),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Text Icon Button'),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.favorite),
            ),
            IconButton.filled(
              onPressed: () {},
              icon: const Icon(Icons.favorite),
            ),
            IconButton.filledTonal(
              onPressed: () {},
              icon: const Icon(Icons.favorite),
            ),
            IconButton.outlined(
              onPressed: () {},
              icon: const Icon(Icons.favorite),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputsShowcase(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Text Field',
            hintText: 'Enter text',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16.0),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Text Field with Icon',
            hintText: 'Enter text',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
            suffixIcon: Icon(Icons.clear),
          ),
        ),
        const SizedBox(height: 16.0),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Text Field with Helper Text',
            hintText: 'Enter text',
            border: OutlineInputBorder(),
            helperText: 'Helper text',
          ),
        ),
        const SizedBox(height: 16.0),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Text Field with Error',
            hintText: 'Enter text',
            border: OutlineInputBorder(),
            errorText: 'Error text',
          ),
        ),
        const SizedBox(height: 16.0),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Disabled Text Field',
            hintText: 'Enter text',
            border: OutlineInputBorder(),
          ),
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildCardsShowcase(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Basic Card',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                const Text(
                  'This is a basic card with some content.',
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Action 1'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Action 2'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Card(
          elevation: 4.0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.album),
                title: const Text('Card with ListTile'),
                subtitle: const Text('This is a card with a ListTile'),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Action 1'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Action 2'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(
                height: 200.0,
                width: double.infinity,
                child: ColoredBox(
                  color: Colors.blue,
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 64.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Card with Image',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    const Text(
                      'This is a card with an image and some content.',
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Action 1'),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Action 2'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
