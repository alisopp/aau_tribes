import 'package:amazon_cognito_identity_dart/cognito.dart';
import 'package:amazon_cognito_identity_dart/sig_v4.dart';
import 'package:flutter/material.dart';
import 'authentification.dart';
import 'login_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';



class Counter {
  int count;
  Counter(this.count);

  factory Counter.fromJson(json) {
    return new Counter(json['count']);
  }
}

class CounterService {
  AwsSigV4Client awsSigV4Client;
  CounterService(this.awsSigV4Client);

  /// Retrieve user's previous count from Lambda + DynamoDB
  Future<Counter> getCounter() async {
    final signedRequest =
    new SigV4Request(awsSigV4Client, method: 'GET', path: '/counter');
    final response =
    await http.get(signedRequest.url, headers: signedRequest.headers);
    return new Counter.fromJson(json.decode(response.body));
  }

  /// Increment user's count in DynamoDB
  Future<Counter> incrementCounter() async {
    final signedRequest =
    new SigV4Request(awsSigV4Client, method: 'PUT', path: '/counter');
    final response =
    await http.put(signedRequest.url, headers: signedRequest.headers);
    return new Counter.fromJson(json.decode(response.body));
  }
}

class SecureCounterScreen extends StatefulWidget {
  SecureCounterScreen({Key key}) : super(key: key);

  @override
  _SecureCounterScreenState createState() => new _SecureCounterScreenState();
}

class _SecureCounterScreenState extends State<SecureCounterScreen> {
  final _userService = new UserService(userPool);
  CounterService _counterService;
  AwsSigV4Client _awsSigV4Client;
  User _user = new User();
  Counter _counter = new Counter(0);
  bool _isAuthenticated = false;

  void _incrementCounter() async {
    final counter = await _counterService.incrementCounter();
    setState(() {
      _counter = counter;
    });
  }

  Future<UserService> _getValues(BuildContext context) async {
    try {
      await _userService.init();
      _isAuthenticated = await _userService.checkAuthenticated();
      if (_isAuthenticated) {
        // get user attributes from cognito
        _user = await _userService.getCurrentUser();

        // get session credentials
        final credentials = await _userService.getCredentials();
        _awsSigV4Client = new AwsSigV4Client(
            credentials.accessKeyId, credentials.secretAccessKey, endpoint,
            region: region, sessionToken: credentials.sessionToken);

        // get previous count
        _counterService = new CounterService(_awsSigV4Client);
        _counter = await _counterService.getCounter();
      }
      return _userService;
    } on CognitoClientException catch (e) {
      if (e.code == 'NotAuthorizedException') {
        await _userService.signOut();
        Navigator.pop(context);
      }
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return new FutureBuilder(
        future: _getValues(context),
        builder: (context, AsyncSnapshot<UserService> snapshot) {
          if (snapshot.hasData) {
            if (!_isAuthenticated) {
              return new LoginScreen();
            }

            return new Scaffold(
              appBar: new AppBar(
                title: new Text('Secure Counter'),
              ),
              body: new Center(
                child: new Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Text(
                      'Welcome ${_user.name}!',
                      style: Theme.of(context).textTheme.display1,
                    ),
                    new Divider(),
                    new Text(
                      'You have pushed the button this many times:',
                    ),
                    new Text(
                      '${_counter.count}',
                      style: Theme.of(context).textTheme.display1,
                    ),
                    new Divider(),
                    new Center(
                      child: new InkWell(
                        child: new Text(
                          'Logout',
                          style: new TextStyle(color: Colors.blueAccent),
                        ),
                        onTap: () {
                          _userService.signOut();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: new FloatingActionButton(
                onPressed: () {
                  if (snapshot.hasData) {
                    _incrementCounter();
                  }
                },
                tooltip: 'Increment',
                child: new Icon(Icons.add),
              ),
            );
          }
          return new Scaffold(
              appBar: new AppBar(title: new Text('Loading...')));
        });
  }
}
