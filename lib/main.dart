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
  int? _lastOpenedBoxId;

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
      _lastOpenedBoxId = null;
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
      _lastOpenedBoxId = box.id;
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
      bottomNavigationBar: _gameState != GameState.setup
          ? PrizeTracker(
              prizePool: _fullPrizePool.sublist(0, _participants),
              prizesClaimed: _prizesClaimed,
      )   : null,
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
          lastOpenedId: _lastOpenedBoxId,
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
  final int? lastOpenedId;

  const GameGrid({
    super.key,
    required this.boxes,
    required this.onBoxTapped,
    this.lastOpenedId,
  });

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
          isMostRecent: box.id == lastOpenedId,
        );
      },
    );
  }
}

// A single mystery box widget.
class MysteryBoxWidget extends StatelessWidget {
  final MysteryBox box;
  final VoidCallback onTap;
  final bool isMostRecent;

  const MysteryBoxWidget({
    super.key,
    required this.box,
    required this.onTap,
    required this.isMostRecent,
  });

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
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), // Match Card's default border radius
                border: isMostRecent
                    ? Border.all(color: Colors.yellow.shade600, width: 4) // The indicator!
                    : null,
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: !box.isOpened ? 1 : .7,
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
          ),

          if(box.isOpened)...{
            Text("\$${box.prize.value}",
              style: Theme.of(context).textTheme.displayLarge!.copyWith(color: Colors.green.shade800,fontSize: 78,fontWeight: FontWeight.bold),
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
  final int prizesClaimed;

  const PrizeTracker({super.key, required this.prizePool, required this.prizesClaimed});

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
    int totalAvailableSum = 0;
    for(var entry in availableCounts.entries){
      totalAvailableSum += entry.value * entry.key;
    }

    // List<Widget> children = prizeValues.map((value) {
    //   final available = availableCounts[value] ?? 0;
    //   final claimed = claimedCounts[value] ?? 0;
    //   final total = available + claimed;
    //   return Column(
    //     children: [
    //       Text('\$$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    //       Text('$available / $total', style: TextStyle(color: available > 0 ? Colors.white : Colors.grey)),
    //     ],
    //   );
    // }).toList();
    // children.insert(2,
    //     Column(
    //       children: [
    //         Text('Average Value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    //         Text('\$${(totalAvailableSum / (prizePool.length - prizesClaimed)).toStringAsFixed(2)}', style: TextStyle(color: Colors.white)),
    //       ],
    //     )
    // );

    // That is a fantastic question, and it gets to the heart of probability and game design. For the holiday giveaway game we designed, the answer is: No, there is no advantage to the order in which people play. The expected outcome is independent of your play order. Every player has the exact same statistical chance of receiving any given prize, regardless of whether they go first, last, or somewhere in the middle. Here’s a breakdown of why this is the case.
    // The Key Concept: A Single, Fair Lottery
    // The most important design choice we made that ensures fairness is this: All prizes are randomly assigned to the mystery boxes before the first player makes their choice. Think of the entire process not as 30 individual events, but as one single lottery draw where all 30 tickets (the prizes) are placed into 30 envelopes (the mystery boxes) at the same time. The game is just a fun way of revealing the results of that pre-run lottery. Let's illustrate with a simpler example:
    // Imagine 3 people (A, B, C) and 3 prizes ($100, $20, $5).
    // The prizes are randomly put into 3 boxes (Box 1, Box 2, Box 3).
    // Each person has a 1/3 chance of getting the $100 prize. Scenario 1: Player A goes first.
    // Player A picks a box. Their chance of picking the box with $100 is 1 in 3. Scenario 2: Player B goes second. Let's analyze Player B's chances before the game starts.
    // For Player B to get the $100, two things must happen:
    // Player A must not pick the $100 box (a 2/3 probability).
    // Player B must then pick the $100 box from the remaining two boxes (a 1/2 probability).
    // To find the total probability, we multiply these chances: (2/3) * (1/2) = 2/6 = 1 in 3. Scenario 3: Player C goes last. For Player C to get the $100, three things must happen:
    // Player A must not pick the $100 box (2/3 probability).
    // Player B must not pick the $100 box from the remaining two (1/2 probability).
    // Player C must then pick the single remaining box, which must be the $100 (1/1 probability).
    // Multiply the chances: (2/3) * (1/2) * (1/1) = 2/6 = 1 in 3. As you can see, every single player has the exact same 1-in-3 chance of winning the top prize from the outset. This same logic scales up perfectly to your game with 30 players and 30 prizes. The first player has a 1/30 chance of getting a $50 prize, and so does the last player.
    // The Psychology vs. The Math
    // The game feels like the odds are changing.
    // When you go early, it feels like you have more choices, which is exciting.
    // When you go late, you can see what prizes are left. If a $50 is still on the board, it feels like your odds are better (e.g., "a 1 in 5 chance!"). However, this is a psychological illusion. The only reason the $50 prize is still available is because all the players before you missed it. The probabilities of those misses were already factored into your initial 1/30 chance. The game is a classic example of a fair, zero-sum lottery. The distribution of prizes is fixed, and the game is just the process of revealing that distribution. Your position in the revealing order doesn't change your fundamental odds.
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
            // children: children,
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