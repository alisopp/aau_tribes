import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:aau_tribes/edge_connector.dart';
import 'package:flutter_test/flutter_test.dart';

class MyListener implements EdgeListener {
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
    // TODO: implement onEdgeLoginSuccess
  }

  @override
  void onPlayerEdgeLoginSuccess() {
    // TODO: implement onPlayerEdgeLoginSuccess
  }
}

void main() {
  test("connect and send player login", () async {
    MyListener myListener = new MyListener();
    EdgeConnector edgeConnector =
        new EdgeConnector(myListener, 'localhost', 6666);
    await edgeConnector.connect();
    print('connected');

    // listen to the received data event stream
    await edgeConnector.sendPlayerLogin("alex");
    print('send');

    // .. and close the socket
    edgeConnector.close();
  });
}
