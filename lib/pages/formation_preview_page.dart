import 'package:flutter/material.dart';

class FormationPreviewPage extends StatelessWidget {
  const FormationPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test – Composition'),
        backgroundColor: Colors.green[800],
      ),
      body: Container(
        color: Colors.green[700],
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'FC Barcelone vs Real Madrid\nLDC 2011',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const _FootballField(),
            const SizedBox(height: 12),
            Container(
              height: 72,
              color: Colors.green[900],
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  const Text(
                    'Remplaçants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _PlayerShirt(player: PlayerMock('12', '', false)),
                      SizedBox(width: 8),
                      _PlayerShirt(player: PlayerMock('13', '', false)),
                      SizedBox(width: 8),
                      _PlayerShirt(player: PlayerMock('14', '', false)),
                      SizedBox(width: 8),
                      _PlayerShirt(player: PlayerMock('15', '', false)),
                      SizedBox(width: 8),
                      _PlayerShirt(player: PlayerMock('16', '', false)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FootballField extends StatelessWidget {
  const _FootballField();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          _PlayerRow(players: [
            PlayerMock('9', 'GIROUD', false),
          ]),
          SizedBox(height: 14),
          _PlayerRow(players: [
            PlayerMock('10', 'MBAPPE', true),
            PlayerMock('11', 'DEMBELE', false),
            PlayerMock('7', 'GRIEZMANN', false),
          ]),
          SizedBox(height: 10),
          _PlayerRow(players: [
            PlayerMock('6', 'KANTE', true),
            PlayerMock('8', 'POGBA', false),
            PlayerMock('14', 'RABIOT', false),
          ]),
          SizedBox(height: 10),
          _PlayerRow(players: [
            PlayerMock('3', 'MENDY', false),
            PlayerMock('4', 'VARANE', true),
            PlayerMock('5', 'KOUNDE', false),
            PlayerMock('2', 'PAVARD', false),
          ]),
          SizedBox(height: 12),
          _PlayerRow(players: [
            PlayerMock('1', 'LLORIS', true),
          ]),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final List<PlayerMock> players;

  const _PlayerRow({required this.players});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: players.map((p) => _PlayerShirt(player: p)).toList(),
    );
  }
}

class _PlayerShirt extends StatelessWidget {
  final PlayerMock player;

  const _PlayerShirt({required this.player});

  @override
  Widget build(BuildContext context) {
    final isFound = player.found;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: isFound ? 1.0 : 0.35,
              child: Image.asset(
                'assets/images/shirt.png',
                width: 32,
              ),
            ),
            Positioned(
              top: 14,
              child: Text(
                player.number,
                style: TextStyle(
                  color: isFound ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (isFound)
          Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class PlayerMock {
  final String number;
  final String name;
  final bool found;

  const PlayerMock(this.number, this.name, this.found);
}