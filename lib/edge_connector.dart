import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';

abstract class EdgeListener {
  void onEdgeConnectedSuccess();

  void onConnectionFailed();

  void onPlayerUpdate(PlayerUpdateMessage message);

  void onAvailableResources(AvailableResourceMessage message);

  void onCastleBuilt(BuildCastleFeedbackMessage message);

  void onArriveAtCastle(ArriveAtCastleMessage message);

  void onResourceOverview(ResourcesOverview message);

  void onLeavingCurrentPlace();
}

class EdgeConnector {
  final EdgeListener _edgeListener;
  final String _host;
  final int _port;

  Socket _socket;

  EdgeConnector(this._edgeListener, this._host, this._port);

  Future<void> connect() async {
    try {
      _socket =
          await Socket.connect(_host, _port, timeout: Duration(seconds: 10))
              .then((socket) {
        socket.setOption(SocketOption.tcpNoDelay, true);
        socket.listen((data) {
          String response = new String.fromCharCodes(data).trim();
          _onResponse(response);
        });

        return socket;
      });
      _edgeListener.onEdgeConnectedSuccess();
    } catch (exception) {
      print(exception);
      _edgeListener.onConnectionFailed();
    }
  }

  Future<void> sendPlayerLogin(String playerName) async {
    LoginMessage message = new LoginMessage(playerName);

    await _sendMessage(message);
  }

  Future<void> sendNewPosition(
      String playerName, double latitude, double longitude) async {
    NewLocationMessage message =
        new NewLocationMessage(playerName, latitude, longitude);

    await _sendMessage(message);
  }

  Future<void> sendDeliverResourceMessage(
      String playerName, int castleId) async {
    DeliverResourcesToCastleMessage message =
        new DeliverResourcesToCastleMessage(playerName, castleId);

    await _sendMessage(message);
  }

  Future<void> sendUpgradeCastleMessage(String playerName, int castleId) async {
    UpgradeCastleMessage message =
        new UpgradeCastleMessage(playerName, castleId);

    await _sendMessage(message);
  }

  Future<void> sendBuildCastleMessage(
      String playerName, double latitude, double longitude) async {
    BuildCastleMessage message =
        new BuildCastleMessage(playerName, latitude, longitude);

    await _sendMessage(message);
  }

  Future<void> sendGatherResourceMessage(String playerName, String resourceType,
      int resourceId, int resourceAmount) async {
    GatherResourceMessage message = new GatherResourceMessage(
        playerName, resourceType, resourceId, resourceAmount);

    await _sendMessage(message);
  }

  void _onResponse(String response) {
    Map map = null;
    try {
      map = jsonDecode(response);
    } catch (e) {
      debugPrint('misformed message arrived:\n' + response);
      return;
    }

    if (map == null || !map.containsKey('action')) {
      debugPrint('misformed message arrived:\n' + response);
      return;
    }
    print(response);
    String action = map['action'];
    switch (action) {
      case 'AvailableResources':
        _edgeListener
            .onAvailableResources(AvailableResourceMessage.fromJson(map));
        break;
      case 'ResourcesOverview':
        _edgeListener.onResourceOverview(ResourcesOverview.fromJson(map));
        break;
      case 'CastleArrived':
        _edgeListener.onArriveAtCastle(ArriveAtCastleMessage.fromJson(map));
        break;
      case 'GetPlayerInformation':
        _edgeListener.onPlayerUpdate(PlayerUpdateMessage.fromJson(map));
        break;
      case 'CastleBuilt':
        _edgeListener.onCastleBuilt(BuildCastleFeedbackMessage.fromJson(map));
        break;
      case 'Nowhere':
        _edgeListener.onLeavingCurrentPlace();
        break;
    }
  }

  Future<void> _sendMessage(Object message) async {
    String json = jsonEncode(message);
    _socket.writeln(json);
    await _socket.flush();
  }

  Future<void> close() async {
    await _socket.close();
  }
}

//---------------------------------------------------------------------------------------
//------------------------------- Messages ----------------------------------------------
//---------------------------------------------------------------------------------------

// to edge
class LoginMessage {
  final String username;

  LoginMessage(this.username);

  LoginMessage.fromJson(Map<String, dynamic> json) : username = json['player'];

  Map<String, dynamic> toJson() => {
        'action': 'PlayerLogin',
        'player': username,
      };
}

// from Edge
class PlayerUpdateMessage {
  final String username;
  final int castleLevel;
  final int castleId;
  final double castleLatitude;
  final double castleLongitude;
  final int wood;
  final int stone;
  final int food;

  PlayerUpdateMessage(
      this.username,
      this.castleLevel,
      this.castleLatitude,
      this.castleLongitude,
      this.wood,
      this.stone,
      this.food,
      this.castleId);

  PlayerUpdateMessage.fromJson(Map<String, dynamic> json)
      : username = json['playerName'],
        castleLevel = json['baseSize'],
        castleLatitude = json['baseLatitude'].toDouble(),
        castleLongitude = json['baseLongitude'].toDouble(),
        wood = json['woodCount'],
        stone = json['stoneCount'],
        food = json['foodCount'],
        castleId = json['baseId'];

  Map<String, dynamic> toJson() => {
        'action': 'GetPlayerInformation',
        'playerName': username,
        'baseSize': castleLevel,
        'baseLatitude': castleLatitude,
        'baseLongitude': castleLongitude,
        'woodCount': wood,
        'stoneCount': stone,
        'foodCount': food,
        'baseId': castleId
      };
}

// to edge
class NewLocationMessage {
  final String username;
  final double latitude;
  final double longitude;

  NewLocationMessage(this.username, this.latitude, this.longitude);

  NewLocationMessage.fromJson(Map<String, dynamic> json)
      : username = json['player'],
        latitude = json['latitude'],
        longitude = json['longitude'];

  Map<String, dynamic> toJson() => {
        'action': 'NewLocation',
        'player': username,
        'latitude': latitude,
        'longitude': longitude,
      };
}

// from edge
class AvailableResourceMessage {
  final String resourceType;
  final double latitude;
  final double longitude;
  final int amount;
  final int resourceId;

  AvailableResourceMessage(this.resourceType, this.resourceId, this.latitude,
      this.longitude, this.amount);

  AvailableResourceMessage.fromJson(Map<String, dynamic> json)
      : resourceId = json['resourceId'],
        resourceType = json['resourceType'],
        latitude = json['latitude'],
        longitude = json['longitude'],
        amount = json['resourceAmount'];

  Map<String, dynamic> toJson() => {
        'action': 'AvailableResources',
        'resourceType': resourceType,
        'resourceId': resourceId,
        'latitude': latitude,
        'longitude': longitude,
        'resourceAmount': amount
      };
}

// to edge
class GatherResourceMessage {
  final String username;
  final String resourceType;
  final int resourceId;
  final int resourceAmount;

  GatherResourceMessage(
      this.username, this.resourceType, this.resourceId, this.resourceAmount);

  GatherResourceMessage.fromJson(Map<String, dynamic> json)
      : username = json['player'],
        resourceId = json['resourceId'],
        resourceType = json['resourceType'],
        resourceAmount = json['resourceAmount'];

  Map<String, dynamic> toJson() => {
        'action': 'GatherResources',
        'player': username,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'resourceAmount': resourceAmount
      };
}

// from edge
class ResourcesOverview {
  final String username;
  final int wood;
  final int stone;
  final int food;

  ResourcesOverview(this.username, this.wood, this.stone, this.food);

  ResourcesOverview.fromJson(Map<String, dynamic> json)
      : username = json['player'],
        wood = json['wood'],
        stone = json['stone'],
        food = json['food'];

  Map<String, dynamic> toJson() => {
        'action': 'ResourcesOverview',
        'player': username,
        'wood': wood,
        'stone': stone,
        'food': food
      };
}

// to edge
class BuildCastleMessage {
  final String username;
  final double latitude;
  final double longitude;

  BuildCastleMessage(this.username, this.latitude, this.longitude);

  BuildCastleMessage.fromJson(Map<String, dynamic> json)
      : username = json['player'],
        latitude = json['latitude'],
        longitude = json['longitude'];

  Map<String, dynamic> toJson() => {
        'action': 'BuildCastle',
        'player': username,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class BuildCastleFeedbackMessage {
  final String username;
  final int castleId;
  final double latitude;
  final double longitude;
  final bool success;
  final int wood;
  final int stone;
  final int food;
  final int level;

  BuildCastleFeedbackMessage(
      this.username,
      this.latitude,
      this.longitude,
      this.success,
      this.castleId,
      this.wood,
      this.stone,
      this.food,
      this.level);

  BuildCastleFeedbackMessage.fromJson(Map<String, dynamic> json)
      : username = json['playerName'],
        latitude = json['baseLatitude'],
        longitude = json['baseLongitude'],
        success = json['success'],
        castleId = json['castleId'],
        wood = json['wood'],
        stone = json['stone'],
        food = json['food'],
        level = json['level'];

  Map<String, dynamic> toJson() => {
        'action': 'CastleBuilt',
        'player': username,
        'latitude': latitude,
        'longitude': longitude,
        'success': success,
        'castleId': castleId,
        'wood': wood,
        'stone': stone,
        'food': food,
        'level': level
      };
}

// from edge
class ArriveAtCastleMessage {
  final String owner;
  final int castleId;
  final double latitude;
  final double longitude;
  final int wood;
  final int stone;
  final int food;
  final int level;

  ArriveAtCastleMessage(this.owner, this.castleId, this.latitude,
      this.longitude, this.wood, this.stone, this.food, this.level);

  ArriveAtCastleMessage.fromJson(Map<String, dynamic> json)
      : owner = json['owner'],
        castleId = json['castleId'],
        latitude = json['latitude'],
        longitude = json['longitude'],
        wood = json['wood'],
        stone = json['stone'],
        food = json['food'],
        level = json['level'];

  Map<String, dynamic> toJson() => {
        'action': 'CastleArrived',
        'owner': owner,
        'castleId': castleId,
        'latitude': latitude,
        'longitude': longitude,
        'wood': wood,
        'stone': stone,
        'food': food,
        'level': level
      };
}

class UpgradeCastleMessage {
  final String username;
  final int castleId;

  UpgradeCastleMessage(this.username, this.castleId);

  UpgradeCastleMessage.fromJson(Map<String, dynamic> json)
      : username = json['player'],
        castleId = json['castleId'];

  Map<String, dynamic> toJson() =>
      {'action': 'UpgradeCastle', 'player': username, 'castleId': castleId};
}

class DeliverResourcesToCastleMessage {
  final String username;
  final int castleId;

  DeliverResourcesToCastleMessage(this.username, this.castleId);

  DeliverResourcesToCastleMessage.fromJson(Map<String, dynamic> json)
      : username = json['player'],
        castleId = json['castleId'];

  Map<String, dynamic> toJson() =>
      {'action': 'DeliverResources', 'player': username, 'castleId': castleId};
}

class ArriveNowhereMessage {
  Map<String, dynamic> toJson() => {'action': 'Nowhere'};
}
