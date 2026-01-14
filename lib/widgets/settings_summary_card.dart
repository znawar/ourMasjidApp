import 'package:flutter/material.dart';

class SettingsSummaryCard extends StatelessWidget {
  final String title;
  final String? description;

  /// Optional custom body content. When provided, it replaces the default 2-column value blocks.
  final Widget? body;

  final String leftLabel;
  final String leftValue;

  final String rightLabel;
  final String rightValue;

  final String actionLabel;
  final VoidCallback? onAction;

  const SettingsSummaryCard({
    super.key,
    required this.title,
    this.description,
    this.body,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                  if (body != null) ...[
                    const SizedBox(height: 16),
                    body!,
                  ] else if (description != null && leftLabel.trim().isEmpty && rightLabel.trim().isEmpty) ...[
                    // Description-only cards (no value blocks)
                  ] else ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ValueBlock(
                            label: leftLabel,
                            value: leftValue,
                            align: CrossAxisAlignment.start,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ValueBlock(
                            label: rightLabel,
                            value: rightValue,
                            align: CrossAxisAlignment.start,
                          ),
                        ),
                      ],
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  final String label;
  final String value;
  final CrossAxisAlignment align;

  const _ValueBlock({
    required this.label,
    required this.value,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
