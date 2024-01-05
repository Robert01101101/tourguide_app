import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tourguide_app/main.dart';

class MyTours extends StatelessWidget {
  const MyTours({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tours'),
      ),
      body: ListView.separated(
        controller: MyGlobals.scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: 100,
        separatorBuilder: (context, index){
          return const SizedBox(height: 12);  //spacing
        },
        itemBuilder: (content, index){
          return buildCard(index);  //item
        },
      ),
    );
  }



  Widget buildCard(int index) => ClipRRect(
    borderRadius: BorderRadius.circular(30.0),
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          child: CachedNetworkImage(
            imageUrl: 'https://source.unsplash.com/random?sig=$index',
            fadeInDuration: const Duration(milliseconds: 300),
            placeholder: (context, url) => const SizedBox(
                width: 32,
                height: 32,
                child: Center(child: CircularProgressIndicator())
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
        Text(
          'Card $index',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            shadows: <Shadow>[
              Shadow(
                blurRadius: 20.0,
                color: Color.fromARGB(200, 0, 0, 0),
              ),
              Shadow(
                blurRadius: 80.0,
                color: Color.fromARGB(200, 0, 0, 0),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}



