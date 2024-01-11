import 'package:tourguide_app/debugScreen.dart';
import 'package:tourguide_app/signIn.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

//because I update the login status dynamically, the Explore screen needs to be a stateful widget (from Chat GPT)
class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => ExploreState();
}

class ExploreState extends State<Explore> {

  @override
  void initState() {

    //Firebase auth
    FirebaseAuth.instance
        .userChanges()
        .listen((User? user) {
      if (user == null) {
        print('FIREBASE AUTH (EXPLORE) - User is currently signed out!');
      } else {
        print('FIREBASE AUTH (EXPLORE) - User is signed in!');
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
      ),
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DebugScreen()),
                  );
                },
                child: const Text('Debug Screen'),
              ),
              //Text('User is signed in!!  :)\n\nUsername: ${FirebaseAuth.instance.currentUser!.displayName}\nEmail: ${FirebaseAuth.instance.currentUser!.email}'),
              const ElevatedButton(
                onPressed: null,//handleSignOut,
                child: Text('Sign Out'),
              ),
            ],
          ),
      ),
    );
  }
}