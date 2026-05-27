import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vpn_service.dart';
 
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Consumer<VpnService>(
        builder: (context, vpn, _) {
          // Показываем модалку при достижении лимита
          if (vpn.isLimitReached) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showLimitDialog(context);
            });
          }
 
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildHeader(),
                const Spacer(),
                _buildStatusCard(vpn),
                const SizedBox(height: 48),
                _buildConnectButton(context, vpn),
                const SizedBox(height: 32),
                _buildTrafficStats(vpn),
                const SizedBox(height: 16),
                _buildTrafficProgress(vpn),
                const Spacer(),
                if (vpn.errorMessage != null)
                  _buildErrorBanner(vpn.errorMessage!),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
 
  void _showLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF00D4FF), size: 24),
            SizedBox(width: 10),
            Text(
              'Демо-режим',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Демонстрационный лимит трафика исчерпан.\n\n'
          'Свяжитесь с владельцем приложения для получения полного доступа.',
          style: TextStyle(color: Color(0xFF718096), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Понятно',
              style: TextStyle(color: Color(0xFF00D4FF), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
          ).createShader(bounds),
          child: const Text(
            'SAFEBOOST',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Безопасно · Быстро · Просто',
          style: TextStyle(
            color: Color(0xFF4A5568),
            fontSize: 12,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
 
  Color _statusColor(VpnStatus status) {
    if (status == VpnStatus.connected) return const Color(0xFF00FF87);
    if (status == VpnStatus.connecting || status == VpnStatus.disconnecting)
      return const Color(0xFFFFB800);
    if (status == VpnStatus.error) return const Color(0xFFFF4757);
    if (status == VpnStatus.limitReached) return const Color(0xFFFF4757);
    return const Color(0xFF4A5568);
  }
 
  IconData _statusIcon(VpnStatus status) {
    if (status == VpnStatus.connected) return Icons.shield_rounded;
    if (status == VpnStatus.limitReached) return Icons.block_rounded;
    return Icons.shield_outlined;
  }
 
  Widget _buildStatusCard(VpnService vpn) {
    final color = _statusColor(vpn.status);
 
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_statusIcon(vpn.status), color: color, size: 18),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              vpn.statusMessage,
              key: ValueKey<String>(vpn.statusMessage),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildConnectButton(BuildContext context, VpnService vpn) {
    final isConnected = vpn.isConnected;
    final isBusy = vpn.isBusy;
    final isLimited = vpn.isLimitReached;
 
    List<Color> gradientColors;
    if (isLimited) {
      gradientColors = [const Color(0xFF2D1515), const Color(0xFF1A0F0F)];
    } else if (isConnected) {
      gradientColors = [const Color(0xFF00FF87), const Color(0xFF00C9A7)];
    } else if (isBusy) {
      gradientColors = [const Color(0xFF00D4FF), const Color(0xFF7B2FFF)];
    } else {
      gradientColors = [const Color(0xFF1A2035), const Color(0xFF0F1525)];
    }
 
    return GestureDetector(
      onTap: (isBusy || isLimited) ? null : () => vpn.toggleConnection(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isConnected)
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF87).withOpacity(0.15),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          if (isBusy)
            _RotatingRing(
              size: 180,
              color: const Color(0xFF00D4FF).withOpacity(0.3),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              border: Border.all(
                color: isConnected
                    ? const Color(0xFF00FF87).withOpacity(0.4)
                    : const Color(0xFF2D3748),
                width: 2,
              ),
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00FF87).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLimited
                      ? Icons.block_rounded
                      : isConnected
                          ? Icons.power_settings_new_rounded
                          : Icons.power_settings_new_outlined,
                  size: 52,
                  color: isConnected
                      ? Colors.black87
                      : isLimited
                          ? const Color(0xFFFF4757).withOpacity(0.5)
                          : const Color(0xFF718096),
                ),
                const SizedBox(height: 6),
                Text(
                  isLimited ? 'ДЕМО' : isConnected ? 'СТОП' : isBusy ? '...' : 'СТАРТ',
                  style: TextStyle(
                    color: isConnected
                        ? Colors.black87
                        : const Color(0xFF4A5568),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildTrafficStats(VpnService vpn) {
    if (!vpn.isConnected) return const SizedBox(height: 60);
 
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatChip(
          icon: Icons.arrow_upward_rounded,
          label: 'Отправка',
          value: vpn.upload,
          color: const Color(0xFF00D4FF),
        ),
        const SizedBox(width: 24),
        _StatChip(
          icon: Icons.arrow_downward_rounded,
          label: 'Загрузка',
          value: vpn.download,
          color: const Color(0xFF00FF87),
        ),
      ],
    );
  }
 
  Widget _buildTrafficProgress(VpnService vpn) {
    if (!vpn.isConnected && !vpn.isLimitReached) return const SizedBox.shrink();
 
    final color = vpn.isLimitReached
        ? const Color(0xFFFF4757)
        : vpn.trafficProgress > 0.8
            ? const Color(0xFFFFB800)
            : const Color(0xFF00D4FF);
 
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Демо трафик',
                style: TextStyle(
                  color: const Color(0xFF4A5568),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${vpn.trafficUsed} / ${vpn.trafficLimit}',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: vpn.trafficProgress,
              backgroundColor: const Color(0xFF1A2035),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF4757), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
 
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
 
  const _StatChip({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);
 
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
 
class _RotatingRing extends StatefulWidget {
  final double size;
  final Color color;
 
  const _RotatingRing({Key? key, required this.size, required this.color})
      : super(key: key);
 
  @override
  State<_RotatingRing> createState() => _RotatingRingState();
}
 
class _RotatingRingState extends State<_RotatingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
 
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }
 
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _ArcPainter(color: widget.color),
            ),
          ),
        );
      },
    );
  }
}
 
class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});
 
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
 
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      0,
      math.pi * 1.5,
      false,
      paint,
    );
  }
 
  @override
  bool shouldRepaint(_ArcPainter old) => false;
}