import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';

class MyBannerAdWidget extends StatefulWidget {
  /// The requested size of the banner.
  final AdSize adSize;

  /// The AdMob ad unit to show.
  final String adUnitId = 'ca-app-pub-1613093835357473/1828126609';
  //actual id: 'ca-app-pub-1613093835357473/1828126609';
  //test id: 'ca-app-pub-3940256099942544/9214589741';

  const MyBannerAdWidget({
    super.key,
    this.adSize = AdSize.mediumRectangle,
  });

  @override
  State<MyBannerAdWidget> createState() => _MyBannerAdWidgetState();
}

class _MyBannerAdWidgetState extends State<MyBannerAdWidget> {
  /// The banner ad to show. This is `null` until the ad is actually loaded.
  BannerAd? _bannerAd;

  @override
  Widget build(BuildContext context) {
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context);

    if (kIsWeb ||
        (userProvider.user != null && userProvider.user!.premium == true)) {
      return const SizedBox();
    }

    return SafeArea(
      child: SizedBox(
        width: widget.adSize.width.toDouble(),
        height: widget.adSize.height.toDouble(),
        child: _bannerAd == null
            // Nothing to render yet.
            ? const SizedBox()
            // The actual ad.
            : AdWidget(ad: _bannerAd!),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context, listen: false);
    if (!(kIsWeb ||
        (userProvider.user != null && userProvider.user!.premium == true))) {
      _loadAd();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  /// Loads a banner ad.
  void _loadAd() {
    final bannerAd = BannerAd(
      size: widget.adSize,
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        // Called when an ad is successfully received.
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (ad, error) {
          logger.w('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );

    // Start loading.
    bannerAd.load();
  }
}
