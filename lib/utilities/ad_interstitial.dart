// import 'dart:io' show Platform;
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/widgets.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
//
// import '../main.dart';
//
// class MyInterstitialAdWidget {
//   InterstitialAd? _interstitialAd;
//
//   /// The AdMob ad unit to show.
//   final String adUnitId = 'ca-app-pub-1613093835357473/5212133573';
//   //actual id: 'ca-app-pub-1613093835357473/5212133573';
//   //test id: 'ca-app-pub-3940256099942544/9214589741';
//
//   /// Loads an interstitial ad.
//   void loadInterstitialAd() {
//     if (kIsWeb) {
//       return;
//     }
//     logger.t('loadInterstitialAd()');
//     InterstitialAd.load(
//       adUnitId: adUnitId,
//       request: const AdRequest(),
//       adLoadCallback: InterstitialAdLoadCallback(
//         onAdLoaded: (InterstitialAd ad) {
//           _interstitialAd = ad;
//         },
//         onAdFailedToLoad: (LoadAdError error) {
//           logger.w('InterstitialAd failed to load: $error');
//         },
//       ),
//     );
//   }
//
//   /// Shows the interstitial ad if it is loaded.
//   void showInterstitialAd(BuildContext context) {
//     if (kIsWeb) {
//       return;
//     }
//     logger.t('showInterstitialAd()');
//     if (_interstitialAd != null) {
//       _interstitialAd!.show();
//       _interstitialAd = null; // Set to null after showing
//     } else {
//       logger.w('Interstitial ad is not ready yet.');
//     }
//   }
//
//   /// Disposes of the interstitial ad.
//   void dispose() {
//     _interstitialAd?.dispose();
//   }
// }
