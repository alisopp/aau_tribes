import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:user_location/user_location.dart';

import 'edge_connector.dart';
import 'game_objects.dart';

enum MapConnectionState { IsConnecting, Fail, Success }
enum PositionState { IsAtResource, NoWhere, IsAtOwnCastle, IsAtAnotherCastle }

class MapScreen extends StatefulWidget {
  MapScreen({Key key}) : super(key: key);

  @override
  _MapScreenState createState() => new _MapScreenState();
}

class _MapScreenState extends State<MapScreen> implements EdgeListener {
  // ADD THIS
  MapController mapController = MapController();
  Player player;
  EdgeConnector _edgeConnector;
  LatLng lastPosition;
  MapConnectionState _connectionState = MapConnectionState.IsConnecting;
  PositionState _positionState = PositionState.NoWhere;
  String host = '10.0.0.20';
  int port = 6666;
  Resource lastVisitedResource;

  List<Resource> resources = [];
  List<Castle> castles = [];

  // ADD THIS
  List<Marker> markers = [];
  Marker playerMarker;

  bool userPlayerPosition = true;

  //StreamController<LatLng> markerlocationStream;

  @override
  Widget build(BuildContext context) {
    //TODO get player from aws gateway
    if (player == null) {
      player = new Player();
      player.name = 'alex';
    }
    //Get the current location of marker
    print("Reconnecting");
    if (_connectionState == MapConnectionState.IsConnecting) {
      _edgeConnector = new EdgeConnector(this, host, port);
      _edgeConnector.connect();
      return new Scaffold(appBar: new AppBar(title: new Text('Loading...')));
    } else if (_connectionState == MapConnectionState.Success) {
      //markerlocationStream = new StreamController();
      /*markerlocationStream.stream.listen((onData) {
        debugPrint("hello");
        debugPrint(onData.latitude.toString());
      }); */
      _edgeConnector.sendPlayerLogin(player.name);
      return _buildMapWidget();
    } else if (_connectionState == MapConnectionState.Fail) {
      return new Scaffold(
          appBar: new AppBar(title: new Text('Failed Connecting to edge')));
    } else {
      return new Scaffold(appBar: new AppBar(title: new Text('unknow error')));
    }
  }


  Widget _buildMapWidget() {
    List<MapPlugin> plugins = [];
    if(userPlayerPosition) {
      plugins.add(UserLocationPlugin());
    }

    var map = new FlutterMap(
      options: new MapOptions(
          center: new LatLng(51.5, -0.09),
          zoom: 18.0,
          plugins: plugins,
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
            updateMapLocationOnPositionChange: true,
            showMoveToCurrentLocationFloatingActionButton: true,
            verbose: false),
      ],
      mapController: mapController,
    );

    String playerText = player.name +
        "\nwood\t" +
        player.wood.toString() +
        "\nstone\t" +
        player.stone.toString() +
        "\nfood\t" +
        player.food.toString();
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
      bottomWidget = new MaterialButton(
        onPressed: () => _deliverResources(),
        child: new Text("Deliver Resources"),
      );
    } else if (_positionState == PositionState.IsAtResource) {
      bottomWidget = new MaterialButton(
        onPressed: () => gatherResource(lastVisitedResource),
        child: new Text("Gather Resource"),
      );
    }

    return new Scaffold(
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

  Future<void> dispose() async {
    super.dispose();
    //await markerlocationStream.close();
    _edgeConnector.close();
  }

  void _buildCastle() {
    _edgeConnector.sendBuildCastleMessage(
        player.name, lastPosition.latitude, lastPosition.longitude);
  }

  void onLocationUpdate(LatLng pos) {
    lastPosition = pos;
    _edgeConnector.sendNewPosition(player.name, pos.latitude, pos.longitude);
  }

  void gatherResource(Resource res) {
    _edgeConnector.sendGatherResourceMessage(
        player.name, res.resourceType, res.id, res.amount);
  }

  void onTap(LatLng pos) {
    // TODO second movement method
  }

  void _deliverResources() {}

  @override
  void onArriveAtCastle(ArriveAtCastleMessage message) {
    if (player.castle != null && message.castleId == player.castle.id) {
      setState(() {
        _positionState = PositionState.IsAtOwnCastle;
      });
    } else {
      setState(() {
        _positionState = PositionState.IsAtAnotherCastle;
      });
    }
    print('i am at a castle');
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
  void onPlayerEdgeLoginSuccess() {
    print('i am connected');
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

  @override
  void onCastleBuilt(BuildCastleFeedbackMessage message) {
    Castle castle = new Castle(player.name,
        new LatLng(message.latitude, message.longitude), message.castleId);

    _createPlayerCastleMarker(castle);
    setState(() {
      player.castle = castle;
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
