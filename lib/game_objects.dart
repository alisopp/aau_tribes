import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

abstract class MapObject {
  Marker getMarkerObject();
}

class Castle {
  final int id;
  final String owner;
  int level;
  final LatLng position;

  Castle(this.owner, this.position, this.id);

  Widget getImage() {
    String path = "assets/base.png";

    return Image(image: AssetImage(path));
  }
}

class Resource {
  final int id;
  final String resourceType;
  int amount;
  final LatLng position;

  Resource(this.resourceType, this.amount, this.id, this.position);

  Widget getImage() {
    String path = "assets/icon_" + resourceType + ".png";

    return Image(image: AssetImage(path));
  }
}

class Player {
  String name;
  int wood = 0;
  int stone = 0;
  int food = 0;
  Castle castle;
}
