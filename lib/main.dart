import 'package:aau_tribes/register_page.dart';
import 'package:flutter/material.dart';
import 'authentification.dart';
import 'confirmation_page.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'login_page.dart';
import 'game_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: HomePage(title: "Test Demo"),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UserService _userService = new UserService(userPool);

  bool _isAuthenticated = false;
  User _user;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return new FutureBuilder(
        future: _getValues(context),
        builder: (context, AsyncSnapshot<UserService> snapshot) {
          if (snapshot.hasData) {
            if (!_isAuthenticated) {
              return new Scaffold(
                appBar: new AppBar(
                  title: new Text(widget.title),
                ),
                body: new Center(
                  child: new Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      new Container(
                        padding: new EdgeInsets.only(
                            left: 20.0, right: 20.0, bottom: 20.0),
                        width: screenSize.width,
                        child: new RaisedButton(
                          child: new Text(
                            'Sign Up',
                            style: new TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              new MaterialPageRoute(
                                  builder: (context) =>
                                      new SignUpScreen(userPool: userPool)),
                            );
                          },
                          color: Colors.blue,
                        ),
                      ),
                      new Container(
                        padding: new EdgeInsets.only(
                            left: 20.0, right: 20.0, bottom: 20.0),
                        width: screenSize.width,
                        child: new RaisedButton(
                          child: new Text(
                            'Login',
                            style: new TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              new MaterialPageRoute(
                                  builder: (context) =>
                                      new LoginScreen(userPool: userPool)),
                            );
                          },
                          color: Colors.blue,
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
            return new Scaffold(
              appBar: new AppBar(
                title: new Text(widget.title),
              ),
              body: new Center(
                child: new Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Container(
                      padding: new EdgeInsets.only(
                          left: 20.0, right: 20.0, bottom: 20.0),
                      width: screenSize.width,
                      child: new RaisedButton(
                        child: new Text(
                          'Start Game',
                          style: new TextStyle(color: Colors.white),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            new MaterialPageRoute(
                                builder: (context) =>
                                new GameScreen(userService: _userService, user : _user)),
                          );
                        },
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return new Scaffold(
              appBar: new AppBar(title: new Text('Loading...')));
        });
  }

  Future<UserService> _getValues(BuildContext context) async {
    try {
      await _userService.init();
      _isAuthenticated = await _userService.checkAuthenticated();
      if (_isAuthenticated) {
        // get user attributes from cognito
        _user = await _userService.getCurrentUser();
      }
      return _userService;
    } on CognitoClientException catch (e) {
      if (e.code == 'NotAuthorizedException') {
        await _userService.signOut();
      }
      throw e;
    }
  }
}
