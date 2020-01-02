import 'dart:async';
import 'package:aau_tribes/confirmation_page.dart';
import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart/cognito.dart';
import 'authentification.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.email, this.gameScreen, this.userPool})
      : super(key: key);

  String email;

  final StatefulWidget gameScreen;
  final CognitoUserPool userPool;

  @override
  _LoginScreenState createState() =>
      new _LoginScreenState(userService: new UserService(userPool));
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginScreenState({this.userService});

  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  final UserService userService;
  User _user = new User();
  bool _isAuthenticated = false;

  Future<UserService> _getValues() async {
    await userService.init();
    _isAuthenticated = await userService.checkAuthenticated();
    return userService;
  }

  submit(BuildContext context) async {
    _formKey.currentState.save();
    String message;
    try {
      _user = await userService.login(_user.email, _user.password);
      message = 'User sucessfully logged in!';
      if (!_user.confirmed) {
        message = 'Please confirm user account';
      }
    } on CognitoClientException catch (e) {
      if (e.code == 'InvalidParameterException' ||
          e.code == 'NotAuthorizedException' ||
          e.code == 'UserNotFoundException' ||
          e.code == 'ResourceNotFoundException') {
        message = e.message;
      } else {
        message = 'An unknown client error occured';
      }
    } catch (e) {
      message = 'An unknown error occurred';
    }
    final snackBar = new SnackBar(
      content: new Text(message),
      action: new SnackBarAction(
        label: 'OK',
        onPressed: () async {
          if (_user.hasAccess) {
            Navigator.pop(context);
            if (!_user.confirmed) {
              Navigator.push(
                context,
                new MaterialPageRoute(
                    builder: (context) => new ConfirmationScreen(
                        key: widget.key,
                        email: _user.email,
                        userPool: widget.userPool)),
              );
            }
          }
        },
      ),
      duration: new Duration(seconds: 30),
    );

    Scaffold.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return new FutureBuilder(
        future: _getValues(),
        builder: (context, AsyncSnapshot<UserService> snapshot) {
          if (snapshot.hasData) {
            if (_isAuthenticated) {
              return widget.gameScreen;
            }
            final Size screenSize = MediaQuery.of(context).size;
            return new Scaffold(
              appBar: new AppBar(
                title: new Text('Login'),
              ),
              body: new Builder(
                builder: (BuildContext context) {
                  return new Container(
                    child: new Form(
                      key: _formKey,
                      child: new ListView(
                        children: <Widget>[
                          new ListTile(
                            leading: const Icon(Icons.email),
                            title: new TextFormField(
                              initialValue: widget.email,
                              decoration: new InputDecoration(
                                  hintText: 'example@inspire.my',
                                  labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                              onSaved: (String email) {
                                _user.email = email;
                              },
                            ),
                          ),
                          new ListTile(
                            leading: const Icon(Icons.lock),
                            title: new TextFormField(
                              decoration:
                                  new InputDecoration(labelText: 'Password'),
                              obscureText: true,
                              onSaved: (String password) {
                                _user.password = password;
                              },
                            ),
                          ),
                          new Container(
                            padding: new EdgeInsets.all(20.0),
                            width: screenSize.width,
                            child: new RaisedButton(
                              child: new Text(
                                'Login',
                                style: new TextStyle(color: Colors.white),
                              ),
                              onPressed: () {
                                submit(context);
                              },
                              color: Colors.blue,
                            ),
                            margin: new EdgeInsets.only(
                              top: 10.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }
          return new Scaffold(
              appBar: new AppBar(title: new Text('Loading...')));
        });
  }
}
