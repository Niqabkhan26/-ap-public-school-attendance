import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AttendanceStatusToggle extends StatelessWidget {
  final String currentStatus; // 'P', 'A', 'L', 'E'
  final ValueChanged<String> onStatusChanged;

  const AttendanceStatusToggle({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            context,
            code: 'P',
            label: 'P',
            activeColor: AppTheme.present,
            activeTextColor: Colors.white,
          ),
          const SizedBox(width: 2),
          _buildButton(
            context,
            code: 'A',
            label: 'A',
            activeColor: AppTheme.absent,
            activeTextColor: Colors.white,
          ),
          const SizedBox(width: 2),
          _buildButton(
            context,
            code: 'L',
            label: 'L',
            activeColor: AppTheme.late,
            activeTextColor: Colors.white,
          ),
          const SizedBox(width: 2),
          _buildButton(
            context,
            code: 'E',
            label: 'E',
            activeColor: AppTheme.excused,
            activeTextColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String code,
    required String label,
    required Color activeColor,
    required Color activeTextColor,
  }) {
    final bool isSelected = currentStatus == code;

    return InkWell(
      onTap: () => onStatusChanged(code),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? activeTextColor
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
