import 'package:flutter/material.dart';
import '../services/rest_timer_service.dart';

class RestTimerBanner extends StatefulWidget {
  const RestTimerBanner({super.key});

  @override
  State<RestTimerBanner> createState() => _RestTimerBannerState();
}

class _RestTimerBannerState extends State<RestTimerBanner> {
  // Starea care controlează dacă bannerul este mutat în partea de sus
  bool _isAtTop = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: RestTimerService(),
      builder: (context, child) {
        final timerService = RestTimerService();
        
        if (timerService.state == TimerState.idle || timerService.state == TimerState.finished) {
          return const SizedBox.shrink();
        }

        // Widget-ul principal (Bannerul tău existent)
        final bannerContent = Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rest Time',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    timerService.formattedRemainingTime,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: () => timerService.subtractTime(10),
                color: theme.colorScheme.onPrimaryContainer,
              ),
              IconButton(
                icon: Icon(
                  timerService.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 24,
                ),
                onPressed: () {
                  if (timerService.isRunning) {
                    timerService.pauseTimer();
                  } else {
                    timerService.resumeTimer();
                  }
                },
                color: theme.colorScheme.onPrimaryContainer,
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => timerService.addTime(10),
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => timerService.stopTimer(),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.onPrimaryContainer.withOpacity(0.1),
                  child: Icon(Icons.close, size: 16, color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        );

        // Folosim un GestureDetector ca să prindem mișcarea de glisare (drag)
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            // Dacă userul trage în sus (sens negativ pe axa Y)
            if (details.primaryDelta! < -7 && !_isAtTop) {
              setState(() => _isAtTop = true);
            }
            // Dacă userul trage în jos (sens pozitiv pe axa Y)
            if (details.primaryDelta! > 7 && _isAtTop) {
              setState(() => _isAtTop = false);
            }
          },
          // Folosim AnimatedInformer/AnimatedContainer ca mutarea să aibă un efect fluid (Smooth CSS-like transition)
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            // Trimitem widget-ul în layout-ul global printr-un mic truc de cheie globală sau stocare locală
            child: bannerContent,
          ),
        );
      },
    );
  }
}