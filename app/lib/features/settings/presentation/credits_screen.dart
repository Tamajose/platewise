import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/widgets.dart';
import '../../../core/l10n/l10n.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) => Standalone(
    title: context.tr('Credits and licenses'),
    body: PageScroll(
      children: [
        PageHeading(context.tr('PlateWise contributors')),
        const SizedBox(height: 10),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Mahdeen Mannaf · Product design and UX')),
              Text(context.tr('Tanvir Mahmud Hossain · Flutter development')),
              Text(context.tr('Juhan Ahmed · AI and backend')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionTitle(context.tr('Assets and data')),
        const SizedBox(height: 5),
        Text(
          context.tr(
            'Inter and Noto Sans Bengali are licensed under the SIL Open Font License. The introductory meal image was generated for PlateWise. Suggested nearby meals and venues are fictional. Optional map tiles are © OpenStreetMap contributors.',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr(
            'Live deployments can configure OpenAI models for structured meal estimates and transcription. The source repository includes the model, data and library attribution inventory.',
          ),
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          context.tr('Open-source notices'),
          onPressed: () =>
              showLicensePage(context: context, applicationName: 'PlateWise'),
        ),
      ],
    ),
  );
}
