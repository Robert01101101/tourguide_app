import 'package:tourguide_app/debugScreen.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

//because I update the login status dynamically, the Explore screen needs to be a stateful widget (from Chat GPT)
class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => SignInState();
}

class SignInState extends State<SignIn> {
  String loginStatus = "no login status";

  @override
  void initState() {
    super.initState();

    //FIREBASE AUTH
    FirebaseAuth.instance
        .userChanges()
        .listen((User? user) {
      if (user == null) {
        print('User is currently signed out :(');
        loginStatus = 'User is currently signed out :(';
        CustomNavigationHelper.router.go(
          CustomNavigationHelper.signInPath,
        );
      } else {
        print('User is signed in! :)');
        loginStatus = 'User is signed in! :)';
        CustomNavigationHelper.router.go(
          CustomNavigationHelper.explorePath,
        );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(loginStatus),
            ElevatedButton(
              onPressed: () {
                signInWithGoogle();
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}