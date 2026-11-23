import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/widgets.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) => Standalone(
    title: 'Credits and licenses',
    body: PageScroll(
      children: [
        const PageHeading('PlateWise contributors'),
        const SizedBox(height: 10),
        const Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mahdeen Mannaf · Product design and UX'),
              Text('Tanvir Mahmud Hossain · Flutter development'),
              Text('Juhan Ahmed · AI and backend'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionTitle('Assets and data'),
        const SizedBox(height: 5),
        const Text(
          'Inter and Noto Sans Bengali are licensed under the SIL Open Font License. The introductory meal image was generated for PlateWise. Suggested nearby meals and venues are fictional. Optional map tiles are © OpenStreetMap contributors.',
        ),
        const SizedBox(height: 10),
        const Text(
          'Live deployments can configure OpenAI models for structured meal estimates and transcription. The source repository includes the model, data and library attribution inventory.',
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          'Open-source notices',
          onPressed: () =>
              showLicensePage(context: context, applicationName: 'PlateWise'),
        ),
      ],
    ),
  );
}
