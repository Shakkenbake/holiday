import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';

// --- Data Models ---

// Represents a single prize with its value.
class Prize {
  final int value;
  bool isClaimed;

  Prize({required this.value, this.isClaimed = false});
}

// Represents a single mystery box on the grid.
class MysteryBox {
  final int id;
  final Prize prize;
  bool isOpened = false;

  MysteryBox({required this.id, required this.prize});
}

// --- Main Application ---

void main() {
  runApp(const HolidayGiveawayApp());
}

class HolidayGiveawayApp extends StatelessWidget {
  const HolidayGiveawayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Holiday Office Giveaway',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.indigo.shade700,
        brightness: Brightness.dark,
        cardColor: Colors.indigo.shade800,
        textTheme: const TextTheme(
          displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      home: const GiveawayHomePage(),
    );
  }
}

// --- Main Game State Management ---

enum GameState { setup, playing, finished }

class GiveawayHomePage extends StatefulWidget {
  const GiveawayHomePage({super.key});

  @override
  State<GiveawayHomePage> createState() => _GiveawayHomePageState();
}

class _GiveawayHomePageState extends State<GiveawayHomePage> {
  GameState _gameState = GameState.setup;
  final _participantController = TextEditingController();

  List<MysteryBox> _mysteryBoxes = [];
  List<Prize> _fullPrizePool = [];
  int _participants = 0;
  int _prizesClaimed = 0;

  @override
  void initState() {
    super.initState();
    _initializeFullPrizePool();
  }

  // Defines the complete list of all possible prizes.
  void _initializeFullPrizePool() {
    _fullPrizePool = [
      ...List.generate(2, (index) => Prize(value: 50)),
      ...List.generate(6, (index) => Prize(value: 20)),
      ...List.generate(10, (index) => Prize(value: 10)),
      ...List.generate(12, (index) => Prize(value: 5)),
    ];
    // Sort descending to easily pick the top prizes later.
    _fullPrizePool.sort((a, b) => b.value.compareTo(a.value));
  }

  // Sets up the game based on participant count.
  void _startGame() {
    final count = int.tryParse(_participantController.text);
    if (count == null || count < 20 || count > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a number between 20 and 30.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _participants = count;
      _prizesClaimed = 0;

      // Select the top 'n' prizes for this game.
      List<Prize> gamePrizes = _fullPrizePool.sublist(0, _participants);
      gamePrizes.shuffle(); // Randomize the order of prizes.

      // Create the mystery boxes.
      _mysteryBoxes = List.generate(
        _participants,
            (index) => MysteryBox(id: index, prize: gamePrizes[index]),
      );

      _gameState = GameState.playing;
    });
  }

  // Resets the game to the setup screen.
  void _resetGame() {
    setState(() {
      _gameState = GameState.setup;
      _participantController.clear();
      _mysteryBoxes = [];
      _participants = 0;
      _prizesClaimed = 0;
      // Reset the 'claimed' status on the main prize pool
      for (var prize in _fullPrizePool) {
        prize.isClaimed = false;
      }
    });
  }

  // Handles a user tapping on a mystery box.
  void _onBoxTapped(MysteryBox box) {
    if (box.isOpened) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Selection'),
        content: const Text('Are you sure you want to open this gift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _revealPrize(box);
            },
            child: const Text('Open It!'),
          ),
        ],
      ),
    );
  }

  // Reveals the prize and updates the game state.
  void _revealPrize(MysteryBox box) {
    setState(() {
      box.isOpened = true;
      box.prize.isClaimed = true;
      _prizesClaimed++;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
            'Congratulations!',
            style: TextStyle(color: Colors.indigo),
        ),
        content: Text(
          'You won \$${box.prize.value}!',
          style: Theme.of(context).textTheme.displayMedium!,
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Check if the game is over.
              if (_prizesClaimed == _participants) {
                setState(() {
                  _gameState = GameState.finished;
                });
              }
            },
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  // Chooses which widget to build based on the current game state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_buildAppBarTitle()),
        actions: [
          if (_gameState != GameState.setup)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Game',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset Game?'),
                    content: const Text('Are you sure you want to end the current game and start over?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _resetGame();
                          },
                          child: const Text('Reset')),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _buildBody(),
      ),
      // Persistent footer showing prize information
      bottomNavigationBar: _gameState != GameState.setup ? PrizeTracker(prizePool: _fullPrizePool.sublist(0, _participants)) : null,
    );
  }

  String _buildAppBarTitle() {
    switch (_gameState) {
      case GameState.playing:
        return 'Participant ${_prizesClaimed + 1} of $_participants';
      case GameState.finished:
        return 'Giveaway Complete!';
      case GameState.setup:
      default:
        return 'Holiday Giveaway Setup';
    }
  }

  Widget _buildBody() {
    switch (_gameState) {
      case GameState.setup:
        return SetupScreen(
          controller: _participantController,
          onStart: _startGame,
        );
      case GameState.playing:
        return GameGrid(
          boxes: _mysteryBoxes,
          onBoxTapped: _onBoxTapped,
        );
      case GameState.finished:
        return FinalSummaryScreen(
          prizes: _mysteryBoxes.map((box) => box.prize).toList(),
          onReset: _resetGame,
        );
    }
  }
}

// --- UI Widgets ---

// Screen for initial game setup.
class SetupScreen extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onStart;

  const SetupScreen({super.key, required this.controller, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Welcome to the Giveaway!', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              const Text('Enter the number of participants:'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 40.0),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    hintText: '20-30',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Game'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  textStyle: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The main grid of mystery boxes.
class GameGrid extends StatelessWidget {
  final List<MysteryBox> boxes;
  final Function(MysteryBox) onBoxTapped;

  const GameGrid({super.key, required this.boxes, required this.onBoxTapped});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200, // Max width for each gift box
        childAspectRatio: 1, // Make them square
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: boxes.length,
      itemBuilder: (context, index) {
        final box = boxes[index];
        return MysteryBoxWidget(
          box: box,
          onTap: () => onBoxTapped(box),
        );
      },
    );
  }
}

// A single mystery box widget.
class MysteryBoxWidget extends StatelessWidget {
  final MysteryBox box;
  final VoidCallback onTap;

  const MysteryBoxWidget({super.key, required this.box, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child:
      Stack(
        alignment: Alignment.center,
        children: [
          Animate(
            // This makes the gift shake when tapped.
            effects: const [ShakeEffect(duration: Duration(milliseconds: 400), hz: 4)],
            target: box.isOpened ? 0 : 1, // Only animate if not opened
            child: Container(
              child: Card(
              shadowColor: box.isOpened ? Colors.black : Colors.white,
                clipBehavior: Clip.antiAlias,
                elevation: box.isOpened ? 2 : 8,
                child: GridTile(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: box.isOpened
                        ? Image.asset('assets/images/gift_open.png', key: const ValueKey('open'))
                        : Image.asset('assets/images/gift_closed.png', key: const ValueKey('closed')),
                  ),
                ),
              ),
            ),
          ),

          if(box.isOpened)...{
            Text("\$${box.prize.value}",
              style: Theme.of(context).textTheme.displayLarge!.copyWith(color: Colors.green,fontSize: 72,fontWeight: FontWeight.bold),
            ),
          }
      ],
      ),
    );
  }
}

// The footer that tracks available and claimed prizes.
class PrizeTracker extends StatelessWidget {
  final List<Prize> prizePool;

  const PrizeTracker({super.key, required this.prizePool});

  @override
  Widget build(BuildContext context) {
    // Group prizes by value to count them.
    Map<int, int> availableCounts = {};
    Map<int, int> claimedCounts = {};

    for (var prize in prizePool) {
      if (prize.isClaimed) {
        claimedCounts[prize.value] = (claimedCounts[prize.value] ?? 0) + 1;
      } else {
        availableCounts[prize.value] = (availableCounts[prize.value] ?? 0) + 1;
      }
    }

    // Get a sorted list of unique prize values.
    final prizeValues = prizePool.map((p) => p.value).toSet().toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black.withOpacity(0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Prizes Available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: prizeValues.map((value) {
              final available = availableCounts[value] ?? 0;
              final claimed = claimedCounts[value] ?? 0;
              final total = available + claimed;
              return Column(
                children: [
                  Text('\$$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('$available / $total', style: TextStyle(color: available > 0 ? Colors.white : Colors.grey)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// The final summary screen shown at the end of the game.
class FinalSummaryScreen extends StatelessWidget {
  final List<Prize> prizes;
  final VoidCallback onReset;

  const FinalSummaryScreen({super.key, required this.prizes, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Giveaway Over!', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 16),
              const Text('Thanks for playing!'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text('Play Again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  textStyle: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}