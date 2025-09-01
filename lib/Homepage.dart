import 'package:flutter/material.dart';

const tomatoRed = Color(0xFFE53935);

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top tomato and notification
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/Homepage/tiny tomato.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                  const Icon(Icons.notifications_none, color: Colors.black, size: 32),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                'Hi there, User',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/Homepage/goal.png',
                        width: 56,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Welcome! Ready to start your first goal?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tasks (0)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // create new task
                    },
                    child: const Text(
                      'Add Task',
                      style: TextStyle(
                        color: tomatoRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Bottom Navigation with custom assets
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/Homepage/Rectangle.png"),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Image.asset("assets/Homepage/Home icon.png", width: 28),
            Image.asset("assets/Homepage/calendar icon.png", width: 28),
            
            // Center floating tomato icon
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                "assets/Homepage/pomodoro timer icon.png",
                width: 40,
              ),
            ),
            
            Image.asset("assets/Homepage/stats icon.png", width: 28),
            Image.asset("assets/Homepage/profile icon.png", width: 28),
          ],
        ),
      ),
    );
  }
}
