import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:aau_tribes/edge_connector.dart';
import 'package:aau_tribes/game_objects.dart';
import 'package:flutter_test/flutter_test.dart';

class MyListener implements EdgeListener {
  bool _isConnected = false;
  bool _isLoggedIn = false;
  bool _isAtResource = false;
  bool _isAtCastle = false;
  bool _isAtOwnCastle = false;
  bool _gatheredResource = false;
  AvailableResourceMessage resourceMessage;
  Player player;
  int castleId = -1;

  @override
  void onArriveAtCastle(ArriveAtCastleMessage message) {
    _isAtOwnCastle = castleId == message.castleId;
    _isAtCastle = castleId != message.castleId;
    _isAtResource = false;
    // TODO: implement onArriveAtCastle
  }

  @override
  void onAvailableResources(AvailableResourceMessage message) {
    _isAtResource = true;
    _isAtOwnCastle = false;
    _isAtCastle = false;
    resourceMessage = message;
  }

  @override
  void onEdgeConnectedSuccess() {
    _isConnected = true;
  }

  @override
  void onPlayerEdgeLoginSuccess() {
    _isLoggedIn = true;
    player = new Player();
  }

  @override
  void onConnectionFailed() {
    // TODO: implement onConnectionFailed
  }

  @override
  void onResourceOverview(ResourcesOverview message) {
    player.wood = message.wood;
    player.food = message.food;
    player.stone = message.stone;
    _gatheredResource = true;
  }

  @override
  void onCastleBuilt(BuildCastleFeedbackMessage message) {
    castleId = message.castleId;
  }

  @override
  void onLeavingCurrentPlace() {
    _isAtOwnCastle = false;
    _isAtResource = false;
    _isAtCastle = false;
  }

  bool isConnected() {
    return _isConnected;
  }

  bool isLoggedIn() {
    return _isLoggedIn;
  }

  bool isAtResource() {
    return _isAtResource;
  }

  bool gatheredResource() {
    return _gatheredResource;
  }

  bool isNoWhere() {
    return !_isAtResource && !_isAtCastle && !_isAtOwnCastle;
  }
}

Future waitWhile(bool test(), [Duration pollInterval = Duration.zero]) {
  var completer = new Completer();
  check() {
    if (test()) {
      completer.complete();
    } else {
      new Timer(pollInterval, check);
    }
  }

  check();
  return completer.future;
}

bool check(MyListener myListener) {
  return myListener._isLoggedIn;
}

void main() {
  String host = "localhost";
  int port = 6666;
  MyListener myListener;
  EdgeConnector edgeConnector;

  EdgeConnector createConnector() {
    myListener = new MyListener();
    return new EdgeConnector(myListener, host, port);
  }

  setUp(() async {
    edgeConnector = createConnector();
    await edgeConnector.connect();
  });

  tearDown(() async {
    await edgeConnector.close();
  });

  test("connect", () async {
    expect(myListener._isConnected, true);
  });

  test("send player login", () async {
    await edgeConnector.sendPlayerLogin("alex");

    await waitWhile(myListener.isLoggedIn, Duration(milliseconds: 100));
    expect(myListener._isLoggedIn, true);
  });
  test("send at resource position", () async {
    await edgeConnector.sendPlayerLogin("alex2");
    await waitWhile(myListener.isLoggedIn, Duration(milliseconds: 100));
    await edgeConnector.sendNewPosition("alex2", 46.811471, 14.363499);
    await waitWhile(myListener.isAtResource, Duration(milliseconds: 100));
    expect(myListener._isAtResource, true);
  });
  test("send gather resources", () async {
    await edgeConnector.sendPlayerLogin("alex3");
    await waitWhile(myListener.isLoggedIn, Duration(milliseconds: 100));
    var player = myListener.player;
    int wood = player.wood;
    int food = player.food;
    int stone = player.stone;
    await edgeConnector.sendNewPosition("alex3", 46.811471, 14.363499);
    await waitWhile(myListener.isAtResource, Duration(milliseconds: 100));
    var msg = myListener.resourceMessage;
    switch(msg.resourceType) {
      case "wood":
        wood = wood + msg.amount;
        break;
      case "stone":
        stone = stone + msg.amount;
        break;
      case "food":
        food = food + msg.amount;
        break;
    }

    await edgeConnector.sendGatherResourceMessage("alex3", msg.resourceType, msg.resourceId, msg.amount);
    await waitWhile(myListener.gatheredResource, Duration(milliseconds: 100));

    expect(player.wood, wood);
    expect(player.stone, stone);
    expect(player.food, food);
  });
  test("send at noWhere position", () async {
    await edgeConnector.sendPlayerLogin("alex4");
    await waitWhile(myListener.isLoggedIn, Duration(milliseconds: 100));
    await edgeConnector.sendNewPosition("alex4", 45.811471, 14.363499);
    await waitWhile(myListener.isNoWhere, Duration(milliseconds: 100));
    expect(myListener.isNoWhere(), true);
  });
  test("send Build Castle", () async {
    await edgeConnector.sendPlayerLogin("alex5");
    await waitWhile(myListener.isLoggedIn, Duration(milliseconds: 100));
    await edgeConnector.sendNewPosition("alex5", 44.811471, 14.363499);
    await waitWhile(myListener.isNoWhere, Duration(milliseconds: 100));
    await edgeConnector.sendBuildCastleMessage("alex5", 44.811471, 14.363499);

  });
}
