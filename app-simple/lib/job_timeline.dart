import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Job progress: Posted → Accepted → Done (or Cancelled).
class JobTimeline extends StatelessWidget {
  const JobTimeline({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    const steps = ['open', 'accepted', 'completed'];
    const labels = ['Posted', 'Accepted', 'Done'];
    const icons = [
      Icons.post_add_outlined,
      Icons.handshake_outlined,
      Icons.check_circle_outline,
    ];
    if (status == 'cancelled') {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'This job was cancelled',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    final idx = steps.indexOf(status).clamp(0, 2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _StepDot(
                done: i < idx,
                current: i == idx,
                icon: icons[i],
                label: labels[i],
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i < idx ? kTeal : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.done,
    required this.current,
    required this.icon,
    required this.label,
  });
  final bool done;
  final bool current;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final color = done || current ? kTeal : Colors.grey.shade400;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: done || current
                ? kTeal.withValues(alpha: 0.12)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: current ? Border.all(color: kTeal, width: 2) : null,
          ),
          child: Icon(
            done ? Icons.check : icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            color: done || current ? kInk : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
