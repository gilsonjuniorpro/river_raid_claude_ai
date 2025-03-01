import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'River Raid',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'RIVER RAID',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlue,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const GameScreen(),
                  ),
                );
              },
              child: const Text(
                'START GAME',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  // Keyboard focus
  final FocusNode _focusNode = FocusNode();

  // Game state
  bool gameOver = false;
  bool gamePaused = false;
  int score = 0;
  int lives = 3;
  double fuel = 100.0;

  // Game objects
  Player player = Player(
    position: const Offset(0, 0),  // Will be properly positioned in initializeGame
    size: const Size(50, 60),
  );
  List<Enemy> enemies = [];
  List<Fuel> fuelTanks = [];
  List<Bullet> bullets = [];
  List<Explosion> explosions = [];

  // Terrain
  List<TerrainSection> terrainSections = [];

  // Game timers and controllers
  late Timer gameLoop;
  late ScrollController terrainScrollController;
  double scrollPosition = 0.0;
  double scrollSpeed = 2.0;

  // Screen dimensions
  late double screenWidth;
  late double screenHeight;

  // Random generator
  final Random random = Random();

  @override
  void initState() {
    super.initState();

    // Provide initial dimensions to avoid null issues
    screenWidth = 400;  // Default fallback width
    screenHeight = 800; // Default fallback height

    initializeGame();
  }

  void initializeGame() {
    // Initialize game timers
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!gamePaused && !gameOver) {
        updateGame();
      }
    });

    // Terrain scroll controller
    terrainScrollController = ScrollController();

    // Queue the setup to happen after the layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get actual screen dimensions
      screenWidth = MediaQuery.of(context).size.width;
      screenHeight = MediaQuery.of(context).size.height;

      // Update player position with actual dimensions
      player.position = Offset(screenWidth / 2, screenHeight - 100);

      // Clear any existing objects before generating new ones
      enemies.clear();
      fuelTanks.clear();
      terrainSections.clear();

      // Initialize terrain with actual dimensions
      generateInitialTerrain();

      // Force a rebuild
      setState(() {});
    });
  }

  void generateInitialTerrain() {
    // Generate initial river sections
    const sectionHeight = 200.0;
    final sectionsNeeded = (screenHeight / sectionHeight).ceil() + 2;

    // Fixed river position in the center
    final riverWidth = screenWidth * 0.6;
    final riverLeft = (screenWidth - riverWidth) / 2;

    for (int i = 0; i < sectionsNeeded; i++) {
      terrainSections.add(TerrainSection(
        top: -sectionHeight * i,
        left: riverLeft,
        riverWidth: riverWidth,
        sectionHeight: sectionHeight,
        screenWidth: screenWidth,
      ));

      // Add random enemies (more of them to ensure visibility)
      if (i > 0) {
        // Add 1-3 enemies per section
        final enemyCount = 1 + random.nextInt(3);

        for (int j = 0; j < enemyCount; j++) {
          final enemyX = riverLeft + riverWidth * random.nextDouble() * 0.8 + riverWidth * 0.1;
          final enemyY = -sectionHeight * i + random.nextDouble() * sectionHeight * 0.8;

          final enemyType = random.nextInt(3); // 0 = boat, 1 = helicopter, 2 = jet

          enemies.add(Enemy(
            position: Offset(enemyX, enemyY),
            size: const Size(40, 40),
            type: enemyType,
            speed: (enemyType == 0) ? 1.0 : ((enemyType == 1) ? 2.0 : 3.0),
          ));
        }
      }

      // Add fuel tanks (guaranteed at least one fuel tank in the first few sections)
      if (i > 0) {
        // Always add a fuel tank in the second section to ensure the player sees one
        if (i == 1 || random.nextDouble() < 0.7) {
          final fuelX = riverLeft + riverWidth * random.nextDouble() * 0.8 + riverWidth * 0.1;
          final fuelY = -sectionHeight * i + random.nextDouble() * sectionHeight * 0.8;

          fuelTanks.add(Fuel(
            position: Offset(fuelX, fuelY),
            size: const Size(30, 30),
          ));
        }
      }
    }
  }

  void updateGame() {
    if (gameOver) return;

    // Debug info in a safe location
    if (random.nextDouble() < 0.01) {  // Only print occasionally
      print("Game state: Enemies: ${enemies.length}, Fuel: ${fuelTanks.length}, Terrain: ${terrainSections.length}");
    }

    // Update scroll position
    scrollPosition += scrollSpeed;

    // Update terrain
    for (final section in terrainSections) {
      section.top += scrollSpeed;
    }

    // Update enemies and fuel to move along with the terrain
    for (final enemy in enemies) {
      enemy.position = Offset(enemy.position.dx, enemy.position.dy + scrollSpeed);
      enemy.update();
    }

    for (final fuel in fuelTanks) {
      fuel.position = Offset(fuel.position.dx, fuel.position.dy + scrollSpeed);
    }

    // Create new terrain sections when needed
    if (terrainSections.isNotEmpty && terrainSections.last.top > -200) {
      double lastRiverPosition = terrainSections.last.left + terrainSections.last.riverWidth / 2;
      double riverWidth = terrainSections.last.riverWidth;

      // Create a new river section with slight meandering
      final newLeft = max(20.0, min(screenWidth - riverWidth - 20,
          lastRiverPosition + random.nextDouble() * 40 - 20));

      terrainSections.add(TerrainSection(
        top: terrainSections.last.top - terrainSections.last.sectionHeight,
        left: newLeft,
        riverWidth: riverWidth,
        sectionHeight: terrainSections.last.sectionHeight,
        screenWidth: screenWidth,
      ));

      // Add random enemies (1-2 per section)
      final enemyCount = 1 + random.nextInt(2);
      for (int j = 0; j < enemyCount; j++) {
        final enemyX = newLeft + riverWidth * random.nextDouble() * 0.8 + riverWidth * 0.1;
        final enemyY = terrainSections.last.top + random.nextDouble() * terrainSections.last.sectionHeight * 0.8;

        final enemyType = random.nextInt(3); // 0 = boat, 1 = helicopter, 2 = jet

        enemies.add(Enemy(
          position: Offset(enemyX, enemyY),
          size: const Size(40, 40),
          type: enemyType,
          speed: (enemyType == 0) ? 1.0 : ((enemyType == 1) ? 2.0 : 3.0),
        ));
      }

      // Add random fuel tanks (50% chance per section)
      if (random.nextDouble() < 0.5) {
        final fuelX = newLeft + riverWidth * random.nextDouble() * 0.8 + riverWidth * 0.1;
        final fuelY = terrainSections.last.top + random.nextDouble() * terrainSections.last.sectionHeight * 0.8;

        fuelTanks.add(Fuel(
          position: Offset(fuelX, fuelY),
          size: const Size(30, 30),
        ));
      }
    }

    // Remove terrain sections, enemies and fuel tanks that are off screen
    terrainSections.removeWhere((section) => section.top > screenHeight + 200);
    enemies.removeWhere((enemy) => enemy.position.dy > screenHeight + 100);
    fuelTanks.removeWhere((fuel) => fuel.position.dy > screenHeight + 100);

    // Update player
    player.update();

    // Update enemies
    for (final enemy in enemies) {
      enemy.update();
    }

    // Update bullets
    for (final bullet in bullets) {
      bullet.update();
    }

    // Remove bullets that are off screen
    bullets.removeWhere((bullet) => bullet.position.dy < -50);

    // Update explosions
    for (final explosion in explosions) {
      explosion.update();
    }

    // Remove finished explosions
    explosions.removeWhere((explosion) => explosion.isDone);

    // Update fuel
    fuel -= 0.05; // Fuel decreases over time
    if (fuel <= 0) {
      gameOver = true;
    }

    // Check collisions
    checkCollisions();

    setState(() {});
  }

  void checkCollisions() {
    // Current terrain section that contains the player
    TerrainSection? currentSection;
    for (final section in terrainSections) {
      if (player.position.dy >= section.top &&
          player.position.dy < section.top + section.sectionHeight) {
        currentSection = section;
        break;
      }
    }

    // Check terrain collision
    if (currentSection != null) {
      final riverLeft = currentSection.left;
      final riverRight = currentSection.left + currentSection.riverWidth;

      // If player outside river boundaries
      if (player.position.dx - player.size.width / 2 < riverLeft ||
          player.position.dx + player.size.width / 2 > riverRight) {
        playerCrash();
      }
    }

    // Check player-enemy collision
    for (int i = enemies.length - 1; i >= 0; i--) {
      if (checkObjectCollision(player, enemies[i])) {
        playerCrash();
        createExplosion(enemies[i].position);
        enemies.removeAt(i);
      }
    }

    // Check player-fuel collision
    for (int i = fuelTanks.length - 1; i >= 0; i--) {
      if (checkObjectCollision(player, fuelTanks[i])) {
        collectFuel(fuelTanks[i]);
        fuelTanks.removeAt(i);
      }
    }

    // Check bullet-enemy collision
    for (int i = bullets.length - 1; i >= 0; i--) {
      bool bulletHit = false;

      for (int j = enemies.length - 1; j >= 0; j--) {
        if (checkObjectCollision(bullets[i], enemies[j])) {
          createExplosion(enemies[j].position);
          score += 100;
          enemies.removeAt(j);
          bulletHit = true;
          break;
        }
      }

      // Check bullet-fuel collision
      if (!bulletHit) {
        for (int j = fuelTanks.length - 1; j >= 0; j--) {
          if (checkObjectCollision(bullets[i], fuelTanks[j])) {
            createExplosion(fuelTanks[j].position);
            score += 50;
            fuelTanks.removeAt(j);
            bulletHit = true;
            break;
          }
        }
      }

      if (bulletHit) {
        bullets.removeAt(i);
      }
    }
  }

  bool checkObjectCollision(GameObject obj1, GameObject obj2) {
    return (obj1.position.dx - obj1.size.width / 2 < obj2.position.dx + obj2.size.width / 2 &&
        obj1.position.dx + obj1.size.width / 2 > obj2.position.dx - obj2.size.width / 2 &&
        obj1.position.dy - obj1.size.height / 2 < obj2.position.dy + obj2.size.height / 2 &&
        obj1.position.dy + obj1.size.height / 2 > obj2.position.dy - obj2.size.height / 2);
  }

  void createExplosion(Offset position) {
    explosions.add(Explosion(
      position: position,
      size: const Size(60, 60),
    ));
  }

  void collectFuel(Fuel fuelTank) {
    fuel = min(100.0, fuel + 20.0);
    score += 25;
  }

  void playerCrash() {
    createExplosion(player.position);
    lives--;

    if (lives <= 0) {
      gameOver = true;
    } else {
      // Reset player position
      player.position = Offset(screenWidth / 2, screenHeight - 100);
    }
  }

  void fireBullet() {
    if (!gamePaused && !gameOver) {
      bullets.add(Bullet(
        position: Offset(player.position.dx, player.position.dy - player.size.height / 2),
        size: const Size(5, 15),
      ));
    }
  }

  void movePlayer(double dx) {
    if (!gamePaused && !gameOver) {
      player.velocity = Offset(dx * 6, 0);
    }
  }

  void resetGame() {
    setState(() {
      gameOver = false;
      score = 0;
      lives = 3;
      fuel = 100.0;
      scrollPosition = 0.0;

      // Reset game objects
      player.position = Offset(screenWidth / 2, screenHeight - 100);
      player.velocity = Offset.zero;

      enemies.clear();
      fuelTanks.clear();
      bullets.clear();
      explosions.clear();
      terrainSections.clear();

      generateInitialTerrain();
    });
  }

  @override
  void dispose() {
    gameLoop.cancel();
    terrainScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Optional: cap game width to 600 for a more "phone-like" width on tablets
    final gameWidth = screenWidth.clamp(300.0, 600.0); // Adjust 600 to your preference

    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              movePlayer(-1.0);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              movePlayer(1.0);
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              if (!gamePaused && !gameOver) {
                fireBullet();
              }
            } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
              setState(() {
                gamePaused = !gamePaused;
              });
            }
          }
        },
        child: Center(
          child: SizedBox(
            width: gameWidth,
            height: screenHeight,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (!gamePaused && !gameOver) {
                  movePlayer(details.delta.dx / 10);
                }
              },
              onTap: () {
                if (!gamePaused && !gameOver) {
                  fireBullet();
                }
              },
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(gameWidth, screenHeight),
                    painter: TerrainPainter(terrainSections),
                  ),

                  // Game objects - enemies, player, bullets, etc.
                  ...enemies.map((enemy) => Positioned(
                    left: enemy.position.dx - enemy.size.width / 2,
                    top: enemy.position.dy - enemy.size.height / 2,
                    child: enemy.build(),
                  )),
                  ...fuelTanks.map((fuel) => Positioned(
                    left: fuel.position.dx - fuel.size.width / 2,
                    top: fuel.position.dy - fuel.size.height / 2,
                    child: fuel.build(),
                  )),
                  ...bullets.map((bullet) => Positioned(
                    left: bullet.position.dx - bullet.size.width / 2,
                    top: bullet.position.dy - bullet.size.height / 2,
                    child: Container(
                      width: bullet.size.width,
                      height: bullet.size.height,
                      color: Colors.yellow,
                    ),
                  )),
                  ...explosions.map((explosion) => Positioned(
                    left: explosion.position.dx - explosion.size.width / 2,
                    top: explosion.position.dy - explosion.size.height / 2,
                    child: AnimatedOpacity(
                      opacity: explosion.opacity,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: explosion.size.width,
                        height: explosion.size.height,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.8),
                              blurRadius: 10,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),

                  // Player
                  Positioned(
                    left: player.position.dx - player.size.width / 2,
                    top: player.position.dy - player.size.height / 2,
                    child: Container(
                      width: player.size.width,
                      height: player.size.height,
                      child: const Center(
                        child: Icon(
                          Icons.flight,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  // UI elements (score, lives, fuel, etc.)
                  Positioned(
                    top: 40,
                    left: 20,
                    child: Text(
                      'Score: $score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: Row(
                      children: List.generate(
                        lives,
                            (index) => const Icon(Icons.favorite, color: Colors.red, size: 30),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      width: 200,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            width: 200 * (fuel / 100),
                            decoration: BoxDecoration(
                              color: fuel > 30 ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          const Center(
                            child: Text(
                              'FUEL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (gameOver)
                    Container(
                      color: Colors.black.withOpacity(0.8),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'GAME OVER',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 50,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Score: $score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                              ),
                            ),
                            const SizedBox(height: 40),
                            ElevatedButton(
                              onPressed: resetGame,
                              child: const Text('PLAY AGAIN', style: TextStyle(fontSize: 24)),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => const MainMenu()),
                                );
                              },
                              child: const Text('MAIN MENU', style: TextStyle(fontSize: 24)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// Game objects
abstract class GameObject {
  Offset position;
  Offset velocity = Offset.zero;
  Size size;

  GameObject({required this.position, required this.size});

  void update() {
    position += velocity;
  }
}

class Player extends GameObject {
  Player({required Offset position, required Size size})
      : super(position: position, size: size);

  @override
  void update() {
    super.update();
    // Apply drag to slow down
    velocity = velocity * 0.9;
  }
}

class Enemy extends GameObject {
  final int type; // 0 = boat, 1 = helicopter, 2 = jet
  final double speed;
  Color color;

  Enemy({required Offset position, required Size size, required this.type, required this.speed})
      : color = type == 0 ? Colors.brown : (type == 1 ? Colors.lightBlue : Colors.purple),
        super(position: position, size: size);

  @override
  void update() {
    // Add side to side movement for certain enemies
    if (type == 1) { // Helicopter moves side to side
      position = Offset(
          position.dx + sin(position.dy / 30) * speed,
          position.dy
      );
    } else if (type == 2) { // Jet moves more randomly
      position = Offset(
          position.dx + sin(position.dy / 20) * speed * 1.5,
          position.dy
      );
    }

    super.update();
  }

  Widget build() {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Icon(
          type == 0 ? Icons.directions_boat :
          (type == 1 ? Icons.air : Icons.airplanemode_active),
          color: Colors.white,
          size: size.width * 0.6,
        ),
      ),
    );
  }
}

class Bullet extends GameObject {
  Bullet({required Offset position, required Size size})
      : super(position: position, size: size) {
    velocity = const Offset(0, -10); // Bullets move upward
  }
}

class Fuel extends GameObject {
  Fuel({required Offset position, required Size size})
      : super(position: position, size: size);

  Widget build() {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.yellow, width: 2),
      ),
      child: const Icon(
          Icons.local_gas_station,
          color: Colors.white,
          size: 20
      ),
    );
  }
}

class Explosion extends GameObject {
  double opacity = 1.0;
  int lifetime = 0;
  bool isDone = false;

  Explosion({required Offset position, required Size size})
      : super(position: position, size: size);

  @override
  void update() {
    lifetime++;
    if (lifetime > 10) {
      opacity -= 0.1;
    }

    if (opacity <= 0) {
      isDone = true;
    }

    // Expand the explosion
    size = Size(size.width + 1, size.height + 1);
  }
}

class TerrainSection {
  double top;
  double left;
  double riverWidth;
  double sectionHeight;
  double screenWidth;

  TerrainSection({
    required this.top,
    required this.left,
    required this.riverWidth,
    required this.sectionHeight,
    required this.screenWidth,
  });

  Widget build() {
    return Positioned(
      top: top,
      left: 0,
      child: Container(
        width: screenWidth,
        height: sectionHeight,
        color: Colors.transparent,
      ),
    );
  }
}

class TerrainPainter extends CustomPainter {
  final List<TerrainSection> terrainSections;

  TerrainPainter(this.terrainSections);

  @override
  void paint(Canvas canvas, Size size) {
    final terrainPaint = Paint()
      ..color = Colors.green[800]!
      ..style = PaintingStyle.fill;

    final riverPaint = Paint()
      ..color = Colors.blue[800]!
      ..style = PaintingStyle.fill;

    for (final section in terrainSections) {
      // Draw river
      canvas.drawRect(
        Rect.fromLTWH(section.left, section.top, section.riverWidth, section.sectionHeight),
        riverPaint,
      );

      // Draw left bank
      canvas.drawRect(
        Rect.fromLTWH(0, section.top, section.left, section.sectionHeight),
        terrainPaint,
      );

      // Draw right bank
      canvas.drawRect(
        Rect.fromLTWH(section.left + section.riverWidth, section.top,
            size.width - (section.left + section.riverWidth), section.sectionHeight),
        terrainPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}