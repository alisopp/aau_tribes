class PlayerStatesResponseMessage {
  final String edgeHost;
  final int edgePort;
  final String playerName;

  PlayerStatesResponseMessage(this.edgeHost, this.edgePort, this.playerName);

  PlayerStatesResponseMessage.fromJson(Map<String, dynamic> json)
      : edgeHost = json['edgeHost'],
        edgePort = json['edgePort'],
        playerName = json['playerName'];

  Map<String, dynamic> toJson() =>
      {'edgeHost': edgeHost, 'edgePort': edgePort, 'playerName': playerName};
}

class PlayerStatesRequestMessage {

}
