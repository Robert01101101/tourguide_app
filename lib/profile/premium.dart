import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';

class Premium extends StatefulWidget {
  const Premium({super.key});

  @override
  State<Premium> createState() => _PremiumState();
}

class _PremiumState extends State<Premium> {
  void presentPaywall() async {
    final paywallResult = await RevenueCatUI.presentPaywall();
    logger.t('Paywall result: $paywallResult');
  }

  @override
  Widget build(BuildContext context) {
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
      ),
      body: Shimmer(
        linearGradient: MyGlobals.createShimmerGradient(context),
        child: StandardLayout(
          children: [
            const SizedBox(height: 0),
            Text("Premium", style: Theme.of(context).textTheme.headlineSmall),
            Visibility(
              visible: userProvider.user!.premium == false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "Purchase Premium to remove all ads. \n\nPremium mode is currently under development, and purchases should be available soon. Current users of Tourguide will automatically be given Premium access when it becomes available.",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(
                    height: 16,
                  ),
                  ElevatedButton(
                      onPressed: presentPaywall,
                      child: const Text("Purchase Premium")),
                ],
              ),
            ),
            Visibility(
              visible: userProvider.user!.premium == true,
              child: Text(
                  "You are a premium user. Contact support if you are still seeing ads, or have questions or requests related to your purchase.",
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}
