import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import '../../ui/google_places_img.dart'
    if (dart.library.html) '../../ui/google_places_img_web.dart' as gpi;
import '../main.dart';

class ParallaxImage extends StatefulWidget {
  ScrollController scrollController;
  TourguidePlaceImg currentPlaceImg;

  ParallaxImage({
    super.key,
    required this.scrollController,
    required this.currentPlaceImg,
  });

  @override
  State<ParallaxImage> createState() => _ParallaxImageState();
}

class _ParallaxImageState extends State<ParallaxImage> {
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();

    //for parallax
    widget.scrollController.addListener(_scrollListener);
  }

  //dispose
  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    setState(() {
      _scrollOffset = widget.scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    //logger.t("ParallaxImage.build()");

    double topBannerImageHeight = MediaQuery.of(context).size.height < 750
        ? MediaQuery.of(context).size.height / 2.5
        : 300;

    return Transform.translate(
      offset: Offset(0, _scrollOffset * 0.5),
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kIsWeb ? Colors.transparent : Colors.white,
              kIsWeb ? Colors.black87 : Colors.black45
            ],
          ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
        },
        blendMode: BlendMode.multiply,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ClipRect(
              child: SizedBox(
                width: constraints.maxWidth,
                height: topBannerImageHeight,
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: AbsorbPointer(
                    child: kIsWeb
                        ? gpi.GooglePlacesImg(
                            //prevents CORS error, taken from places sdk example //TODO investigate if also usable on mobile
                            photoMetadata: widget
                                .currentPlaceImg.googlePlacesImg!.photoMetadata,
                            placePhotoResponse: widget.currentPlaceImg
                                .googlePlacesImg!.placePhotoResponse,
                          )
                        : widget
                            .currentPlaceImg.googlePlacesImg!.placePhotoResponse
                            .when(
                            image: (image) => Image(
                              image: image.image,
                              gaplessPlayback: true,
                            ),
                            imageUrl: (imageUrl) => Image.network(
                              imageUrl,
                              gaplessPlayback: true,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
