import 'dart:async';
import 'dart:convert';

import 'package:aau_tribes/rest_messages.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:user_location/user_location.dart';
import 'package:http/http.dart' as http;

import 'authentification.dart';
import 'config.dart';
import 'edge_connector.dart';
import 'game_objects.dart';

enum MapConnectionState { IsConnecting, Fail, Success, PlayerLoggedIn }
enum PositionState { IsAtResource, NoWhere, IsAtOwnCastle, IsAtAnotherCastle }

class GameScreen extends StatefulWidget {
  GameScreen({Key key, this.userService, this.user}) : super(key: key);

  final UserService userService;
  final User user;

  @override
  _GameScreenState createState() =>
      new _GameScreenState(userService: this.userService, user: this.user);
}

class _GameScreenState extends State<GameScreen> implements EdgeListener {
  _GameScreenState({this.userService, this.user});

  // AWS Gate Way API + cognito
  final UserService userService;
  final User user;

  // Game States
  Player player;

  LatLng lastPosition;
  MapConnectionState _connectionState = MapConnectionState.IsConnecting;
  PositionState _positionState = PositionState.NoWhere;
  List<Resource> resources = [];
  List<Castle> castles = [];

  // Map Markers
  MapController mapController = MapController();
  List<Marker> markers = [];
  Marker playerMarker;

  // Connection to the edge
  EdgeConnector _edgeConnector;
  String host = '10.0.0.20';
  int port = 6666;
  bool hasEdgeConnection = false;
  Castle currentVisitedCastle;
  Resource lastVisitedResource;

  // ADD THIS

  bool usePlayerPosition = true;

  @override
  Widget build(BuildContext context) {
    //TODO get player from aws gateway
    if (!hasEdgeConnection) {
      _getValues(context);
      return new Scaffold(appBar: new AppBar(title: new Text('Loading...')));
    }
    //Get the current location of marker

    if (_connectionState == MapConnectionState.IsConnecting) {
      _edgeConnector = new EdgeConnector(this, host, port);
      _edgeConnector.connect();
      return new Scaffold(appBar: new AppBar(title: new Text('Loading...')));
    } else if (_connectionState == MapConnectionState.Success) {
      _edgeConnector.sendPlayerLogin(user.name);
      return new Scaffold(
          appBar: new AppBar(title: new Text('Is Connected to the edge')));
    } else if (_connectionState == MapConnectionState.Fail) {
      return new Scaffold(
          appBar: new AppBar(
        title: new Text('Failed Connecting to edge'),
        actions: <Widget>[
          MaterialButton(
            onPressed: () {
              userService.signOut();
              Navigator.pop(context);
            },
            child: Text("Logout"),
          )
        ],
      ));
    } else if (_connectionState == MapConnectionState.PlayerLoggedIn) {
      return _buildMapWidget();
    } else {
      return new Scaffold(
          appBar: new AppBar(title: new Text('unknow error'), actions: <Widget>[
        MaterialButton(
          onPressed: () {
            userService.signOut();
            Navigator.pop(context);
          },
          child: Text("Logout"),
        )
      ]));
    }
  }

  Future<void> _getValues(BuildContext context) async {
    try {
      await userService.init();
      bool _isAuthenticated = await userService.checkAuthenticated();
      if (_isAuthenticated) {
        final url = endpoint + "/user";
        Map<String, String> headers = {
          "Content-Type": "application/json",
          "Authorization": userService.getJwtToken(),
          "Content-Length": "0",
          "Connection": "keep-alive"
        };
        final response = await http.post(url, headers: headers);
        print(json.decode(response.body));
        var message =
            PlayerStatesResponseMessage.fromJson(json.decode(response.body));
        print(message.edgeHost + " " + message.edgePort.toString());
        setState(() {
          hasEdgeConnection = true;
          host = message.edgeHost;
          port = message.edgePort;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Widget _buildMapWidget() {
    var map = _buildGpsMap();
    String playerText = "";

    playerText = player.name +
        "\nwood\t" +
        player.wood.toString() +
        "\nstone\t" +
        player.stone.toString() +
        "\nfood\t" +
        player.food.toString();
    if (_positionState == PositionState.IsAtOwnCastle) {
      playerText += "\nCastle" +
          "\nwood\t" +
          player.castle.wood.toString() +
          "\nstone\t" +
          player.castle.stone.toString() +
          "\nfood\t" +
          player.castle.food.toString() +
          "\nlevel\t" +
          player.castle.level.toString();
    }

    Widget bottomWidget;
    if (_positionState == PositionState.NoWhere) {
      if (player.castle == null) {
        bottomWidget = new MaterialButton(
          onPressed: () => _buildCastle(),
          child: new Text("Build new castle on your position"),
        );
      } else {
        bottomWidget = new Text('Status: Ok');
      }
    } else if (_positionState == PositionState.IsAtOwnCastle) {
      bottomWidget = Row(
        children: <Widget>[
          new MaterialButton(
              onPressed: () => _deliverResources(),
              child: new Text("Deliver Resources")),
          new MaterialButton(
              onPressed: () => _upgradeCastle(),
              child: new Text("Upgrade Castle"))
        ],
      );
    } else if (_positionState == PositionState.IsAtResource) {
      bottomWidget = new MaterialButton(
        onPressed: () => gatherResource(lastVisitedResource),
        child: new Text("Gather Resource"),
      );
    }

    return new Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            MaterialButton(
              onPressed: () => swapMovementMode(),
              child: Text(usePlayerPosition ? "Use Gps" : "Use Tap"),
            ),
            MaterialButton(
              onPressed: () {
                userService.signOut();
                Navigator.pop(context);
              },
              child: Text("Logout"),
            )
          ],
        ),
        body: Center(
          child: Stack(
            children: <Widget>[
              Container(child: map),
              Container(
                  alignment: Alignment.centerRight,
                  child: Container(
                      child: new Text(playerText,
                          style:
                              TextStyle(color: Colors.white, fontSize: 14.0)),
                      color: Colors.brown,
                      padding: EdgeInsets.all(20.0)))
            ],
          ),
        ),
        bottomNavigationBar: bottomWidget);
  }

  Widget _buildGpsMap() {
    if (playerMarker == null) {
      playerMarker = playerMarker = new Marker(
          point: new LatLng(0, 0),
          width: 10,
          height: 10,
          builder: (ctx) => new Container(
                  child: Icon(
                Icons.favorite,
                color: Colors.pink,
                size: 24.0,
                semanticLabel: 'Text to announce in accessibility modes',
              )));
      markers.add(playerMarker);
    }
    return FlutterMap(
      options: new MapOptions(
          center: new LatLng(51.5, -0.09),
          zoom: 18.0,
          plugins: [UserLocationPlugin()],
          onTap: (LatLng pos) => onTap(pos)),
      layers: [
        new TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c']),
        new MarkerLayerOptions(markers: markers),
        UserLocationOptions(
            context: context,
            mapController: mapController,
            markers: markers,
            onLocationUpdate: (LatLng pos) => onLocationUpdate(pos),
            updateMapLocationOnPositionChange: usePlayerPosition,
            showMoveToCurrentLocationFloatingActionButton: true,
            verbose: false),
      ],
      mapController: mapController,
    );
  }

  void swapMovementMode() {
    setState(() {
      usePlayerPosition = !usePlayerPosition;
    });
  }

  Future<void> dispose() async {
    super.dispose();
    //await markerlocationStream.close();
    _edgeConnector.close();
  }

  void _upgradeCastle() {
    _edgeConnector.sendUpgradeCastleMessage(
        player.name, currentVisitedCastle.id);
  }

  void _buildCastle() {
    _edgeConnector.sendBuildCastleMessage(
        player.name, lastPosition.latitude, lastPosition.longitude);
  }

  void onLocationUpdate(LatLng pos) {
    if (usePlayerPosition) {
      lastPosition = pos;
      _edgeConnector.sendNewPosition(player.name, pos.latitude, pos.longitude);
    }
  }

  void gatherResource(Resource res) {
    _edgeConnector.sendGatherResourceMessage(
        player.name, res.resourceType, res.id, res.amount);
  }

  void onTap(LatLng pos) {
    if (!usePlayerPosition) {
      playerMarker.point.latitude = pos.latitude;
      playerMarker.point.longitude = pos.longitude;
      lastPosition = pos;
      _edgeConnector.sendNewPosition(player.name, pos.latitude, pos.longitude);
      setState(() {});
    }
  }

  void _deliverResources() {
    _edgeConnector.sendDeliverResourceMessage(
        player.name, currentVisitedCastle.id);
  }

  @override
  void onArriveAtCastle(ArriveAtCastleMessage message) {
    if (player.castle != null && message.castleId == player.castle.id) {
      setState(() {
        _positionState = PositionState.IsAtOwnCastle;
        Castle playerCastle = player.castle;
        playerCastle.food = message.food;
        playerCastle.wood = message.wood;
        playerCastle.stone = message.stone;
        playerCastle.level = message.level;
        currentVisitedCastle = playerCastle;
      });
    } else {
      bool containsCastle = false;
      for (var castle in castles) {
        if (castle.id == message.castleId) {
          containsCastle = true;
          castle.wood = message.wood;
          castle.food = message.food;
          castle.stone = message.stone;
          castle.level = message.level;
          currentVisitedCastle = castle;
          break;
        }
      }

      if (!containsCastle) {
        Castle castle = new Castle(message.owner,
            new LatLng(message.latitude, message.longitude), message.castleId);
        castle.wood = message.wood;
        castle.food = message.food;
        castle.stone = message.stone;
        castle.level = message.level;
        castles.add(castle);
        currentVisitedCastle = castle;
        _createPlayerCastleMarker(castle);
      }
      setState(() {
        _positionState = PositionState.IsAtAnotherCastle;
      });
    }
  }

  @override
  void onAvailableResources(AvailableResourceMessage message) {
    // Check if we show already this resource
    for (var res in resources) {
      if (res.id == message.resourceId) {
        res.amount = message.amount;
        lastVisitedResource = res;
        setState(() {
          _positionState = PositionState.IsAtResource;
        });
        return;
      }
    }
    print('i am at resource ' + message.resourceType);
    Resource resource = new Resource(message.resourceType, message.amount,
        message.resourceId, new LatLng(message.latitude, message.longitude));
    lastVisitedResource = resource;
    resources.add(resource);
    Marker marker = new Marker(
        point: resource.position,
        width: 20,
        height: 20,
        builder: (ctx) => new Container(child: resource.getImage()));
    markers.add(marker);
    setState(() {
      _positionState = PositionState.IsAtResource;
    });
  }

  @override
  void onEdgeConnectedSuccess() {
    setState(() {
      _connectionState = MapConnectionState.Success;
    });
  }

  @override
  void onPlayerUpdate(PlayerUpdateMessage message) {
    if (player == null) {
      setState(() {
        _connectionState = MapConnectionState.PlayerLoggedIn;
        player = new Player();
        player.name = message.username;
        if (message.castleLevel > 0) {
          player.castle = _onCreatePlayerCastle(
              message.castleLatitude,
              message.castleLongitude,
              message.castleId,
              message.castleLevel,
              message.wood,
              message.stone,
              message.food);
          _createPlayerCastleMarker(player.castle);
        }
      });
    } else if (player.castle == null) {
      if (message.castleLevel > 0) {
        Castle castle = _onCreatePlayerCastle(
            message.castleLatitude,
            message.castleLongitude,
            message.castleId,
            message.castleLevel,
            message.wood,
            message.stone,
            message.food);
        _createPlayerCastleMarker(castle);
        setState(() {
          player.castle = castle;
        });
      }
    } else {
      setState(() {
        var castle = player.castle;
        // my castle got upgraded
        if (castle.level < message.castleLevel) {
          castle.level = message.castleLevel;
          castle.wood = message.wood;
          castle.stone = message.stone;
          castle.food = message.food;
        }
        // else there should be message
      });
    }
  }

  @override
  void onConnectionFailed() {
    print('i am not connected');
    setState(() {
      _connectionState = MapConnectionState.Fail;
    });
  }

  @override
  void onResourceOverview(ResourcesOverview message) {
    setState(() {
      player.food = message.food;
      player.stone = message.stone;
      player.wood = message.wood;
    });
    print('on gather resources');
  }

  Castle _onCreatePlayerCastle(double latitude, double longitude, int castleId,
      int level, int wood, int stone, int food) {
    Castle castle =
        new Castle(player.name, new LatLng(latitude, longitude), castleId);
    castle.wood = wood;
    castle.stone = stone;
    castle.food = food;
    castle.level = level;

    return castle;
  }

  @override
  void onCastleBuilt(BuildCastleFeedbackMessage message) {
    Castle castle = new Castle(player.name,
        new LatLng(message.latitude, message.longitude), message.castleId);
    castle.wood = message.wood;
    castle.stone = message.stone;
    castle.food = message.food;
    castle.level = message.level;

    _createPlayerCastleMarker(castle);
    setState(() {
      player.castle = castle;
      currentVisitedCastle = castle;
      _positionState = PositionState.IsAtOwnCastle;
    });
  }

  void _createPlayerCastleMarker(Castle castle) {
    Marker marker = new Marker(
        point: castle.position,
        width: 20,
        height: 20,
        builder: (ctx) => new Container(child: castle.getImage()));
    markers.add(marker);
  }

  @override
  void onLeavingCurrentPlace() {
    setState(() {
      _positionState = PositionState.NoWhere;
    });
  }
}
