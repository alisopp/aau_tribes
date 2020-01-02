import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:user_location/user_location.dart';

import 'edge_connector.dart';

class MapScreen extends StatefulWidget {
  MapScreen({Key key}) : super(key: key);

  @override
  _MapScreenState createState() => new _MapScreenState();
}

class _MapScreenState extends State<MapScreen> implements EdgeListener {
  // ADD THIS
  MapController mapController = MapController();

  EdgeConnector _edgeConnector;
  LatLng lastPosition;

  // ADD THIS
  List<Marker> markers = [];
  StreamController<LatLng> markerlocationStream = StreamController();

  @override
  Widget build(BuildContext context) {
    //Get the current location of marker
    markerlocationStream.stream.listen((onData) {
      //debugPrint(onData.latitude.toString());
    });
    _edgeConnector = new EdgeConnector(this, '10.0.0.20', 6666);
    _edgeConnector.connect();
    return new FlutterMap(
      options: new MapOptions(
        center: new LatLng(51.5, -0.09),
        zoom: 25.0,
        plugins: [
          // ADD THIS
          UserLocationPlugin(),
        ],
      ),
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
  }

  void dispose() {
    super.dispose();
    markerlocationStream.close();
    _edgeConnector.close();
  }

  void onLocationUpdate(LatLng pos) {
    lastPosition = pos;
  }

  @override
  void onArriveAtCastle(ArriveAtCastleMessage message) {
    // TODO: implement onArriveAtCastle
  }

  @override
  void onAvailableResources(AvailableResourceMessage message) {
    // TODO: implement onAvailableResources
  }

  @override
  void onEdgeConnectedSuccess() {
    _edgeConnector.sendPlayerLogin('alex');
  }

  @override
  void onPlayerEdgeLoginSuccess() {
    print('i am connected');
  }
}
