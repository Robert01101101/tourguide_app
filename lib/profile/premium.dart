import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/ui/horizontal_scroller.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class Premium extends StatefulWidget {
  const Premium({super.key});

  @override
  State<Premium> createState() => _PremiumState();
}

class _PremiumState extends State<Premium> {
  @override
  Widget build(BuildContext context) {
    TourProvider tourProvider = Provider.of<TourProvider>(context);

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
            Text(
                "Purchase Premium to remove all ads. \n\nPremium mode is currently under development, and purchases should be available soon. Current users of Tourguide will automatically be given Premium access when it becomes available.",
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
