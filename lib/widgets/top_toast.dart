import 'package:flutter/material.dart';

/// Cele 4 tipuri de stări pentru Toast
enum ToastType { success, warning, error, info }

class TopToast {
  static OverlayEntry? _currentEntry;

  /// Metoda publică principală. Dacă nu pui [type], el va fi implicit 'success'.
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
  }) {
    // Închidem toast-ul vechi dacă există, ca să nu se suprapună culorile
    dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => _TopToastWidget(
        message: message,
        type: type,
        onDismiss: () => dismiss(),
      ),
    );

    overlay.insert(_currentEntry!);
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

// --- PRIVATE WIDGET: TOP TOAST ---
class _TopToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  /// 🎨 CONFIGURAȚIA DE UX PENTRU FIECARE STARE
  /// Returnează: [CuloareFundal, CuloareBordură, CuloareIconiță, IconData]
  List<dynamic> _getStyleConfig() {
    switch (widget.type) {
      case ToastType.success:
        return [
          const Color(0xFF0F5132), // Verde închis mat
          const Color(0xFF198754), // Verde intens bordură
          const Color(0xFF25D366), // Verde deschis iconiță
          Icons.check_circle_rounded,
        ];
      case ToastType.warning:
        return [
          const Color(
              0xFF332701), // Galben-maroniu închis (să nu spargă tema dark)
          const Color(0xFFFFC107), // Galben bordură
          const Color(0xFFFFD166), // Galben deschis iconiță
          Icons.warning_rounded,
        ];
      case ToastType.error:
        return [
          const Color(0xFF431418), // Roșu-grena închis
          const Color(0xFFDC3545), // Roșu aprins bordură
          const Color(0xFFFF6B6B), // Roșu deschis iconiță
          Icons.error_rounded,
        ];
      case ToastType.info:
        return [
          const Color(0xFF052C3E), // Albastru închis mat
          const Color(0xFF0D6EFD), // Albastru intens bordură
          const Color(0xFF64DFDF), // Cyan iconiță
          Icons.info_rounded,
        ];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extragem configurația vizuală în funcție de tipul trimis
    final config = _getStyleConfig();
    final Color bgColor = config[0];
    final Color borderColor = config[1];
    final Color iconColor = config[2];
    final IconData iconData = config[3];

    return SafeArea(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconData, color: iconColor, size: 22),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
