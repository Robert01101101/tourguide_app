import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tourguide_app/main.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: listPicker(context),
    );
  }


  Widget listPicker(BuildContext context) => Center(
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children: [
      ElevatedButton(onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ListViewA()),
        );
      }, child: const Text("LV A")),
      ElevatedButton(onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ListViewB()),
        );
      }, child: const Text("LV B")),
      ElevatedButton(onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ListViewC()),
        );
      }, child: const Text("LV C")),
      ElevatedButton(onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ListViewD()),
        );
      }, child: const Text("LV D")),
    ],),
  );
}



class ListViewA extends StatelessWidget {
  const ListViewA({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map - List View A'),
      ),
      body: listViewA(),
    );
  }

  Widget listViewA() => ListView.separated(
    controller: MyGlobals.scrollController,
    padding: const EdgeInsets.all(12),
    itemCount: 100,
    separatorBuilder: (context, index){
      return const SizedBox(height: 12);  //spacing
    },
    itemBuilder: (content, index){
      return buildCard(index);  //item
    },
  );
}

class ListViewB extends StatelessWidget {
  const ListViewB({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map - List View B'),
      ),
      body: listViewB(),
    );
  }

  Widget listViewB() => ListView.separated(
    controller: MyGlobals.scrollController,
    padding: const EdgeInsets.all(12),
    itemCount: 100,
    cacheExtent: 100,
    separatorBuilder: (context, index){
      return const SizedBox(height: 12);  //spacing
    },
    itemBuilder: (content, index){
      return buildCard(index);  //item
    },
  );
}


class ListViewC extends StatelessWidget {
  const ListViewC({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map - List View C'),
      ),
      body: listViewC(),
    );
  }



  Widget listViewC() => ListView(
      controller: MyGlobals.scrollController,
      padding: const EdgeInsets.all(12),
      children: List.generate(
          100,
              (index) => Column(
            children: [
              buildCard(index),
              const SizedBox(height: 12,)
            ],
          ))
  );
}



class ListViewD extends StatelessWidget {
  const ListViewD({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map - List View D'),
      ),
      body: listViewD(),
    );
  }



  Widget listViewD() => ListView(
      controller: MyGlobals.scrollController,
      padding: const EdgeInsets.all(12),
      children: List.generate(
          100,
              (index) => Column(
            children: [
              buildCardImmediate(index),
              const SizedBox(height: 12,)
            ],
          ))
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
          fadeInDuration: const Duration(milliseconds: 100),
          placeholder: (context, url) =>
              Container(
                color: Colors.grey.shade300,
                child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: CircularProgressIndicator())
                ),
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


Widget buildCardImmediate(int index) => ClipRRect(
  borderRadius: BorderRadius.circular(30.0),
  child: Stack(
    alignment: Alignment.center,
    children: <Widget>[
      Container(
        child: Image.network(
          'https://source.unsplash.com/random?sig=$index',
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