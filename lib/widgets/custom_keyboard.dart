import 'package:flutter/material.dart';
import 'package:ledger_app/models/enums.dart';

class CustomKeyboard extends StatelessWidget {
  const CustomKeyboard({
    required this.onKeyPressed,
    required this.currentType,
    required this.onTypeChanged,
    required this.isCalculated,
    required this.hasExpression,
    super.key,
  });

  final void Function(String key) onKeyPressed;
  final LedgerEntryType currentType;
  final void Function(LedgerEntryType type) onTypeChanged;
  final bool isCalculated;
  final bool hasExpression;

  static const _teal = Color(0xFF00696D);
  static const _sidebarBg = Color(0xFFF8F8F8);
  static const _selectedBg = Color(0xFFE2F3EB);
  static const _unselectedText = Color(0xFF666666);
  static const _keyText = Color(0xFF000000);
  static const _deleteColor = Color(0xFF333333);
  static const _dividerColor = Color(0xFFD9D9D9);

  bool get _showEquals => hasExpression && !isCalculated;

  @override
  Widget build(BuildContext context) {
    // 按钮宽度与运算符列一致
    const btnWidth = 60.0;

    return Container(
      child: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SizedBox(
      height: 280,
      child: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildNumberPad()),
          _buildOperatorColumn(),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 55,
      color: _sidebarBg,
      child: Column(
        children: [
          _buildTypeButton('支\n出', LedgerEntryType.expense),
          Container(height: 1, color: _dividerColor),
          _buildTypeButton('收\n入', LedgerEntryType.income),
          Container(height: 1, color: _dividerColor),
          _buildTypeButton('转\n账', LedgerEntryType.transfer),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, LedgerEntryType type) {
    final isSelected = currentType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTypeChanged(type),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: isSelected ? _selectedBg : Colors.transparent,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? _teal : _unselectedText,
                decoration: TextDecoration.none,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Expanded(child: _buildNumberRow(['7', '8', '9'])),
        Container(height: 1, color: _dividerColor),
        Expanded(child: _buildNumberRow(['4', '5', '6'])),
        Container(height: 1, color: _dividerColor),
        Expanded(child: _buildNumberRow(['1', '2', '3'])),
        Container(height: 1, color: _dividerColor),
        Expanded(child: _buildBottomRow()),
      ],
    );
  }

  Widget _buildNumberRow(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onKeyPressed(keys[i]),
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  keys[i],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _keyText,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          if (i < keys.length - 1)
            Container(width: 1, color: _dividerColor),
        ],
      ],
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onKeyPressed('.'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              child: const Text(
                '.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _keyText,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        Container(width: 1, color: _dividerColor),
        Expanded(
          child: GestureDetector(
            onTap: () => onKeyPressed('0'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              child: const Text(
                '0',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _keyText,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        Container(width: 1, color: _dividerColor),
        Expanded(
          child: GestureDetector(
            onTap: () => onKeyPressed('⌫'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              child: Image.asset(
                'assets/icons/delete_icon.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorColumn() {
    return Container(
      width: 60,
      height: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 1, color: _dividerColor),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onKeyPressed('-'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        '-',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: _keyText,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(height: 1, color: _dividerColor),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onKeyPressed('+'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        '+',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: _keyText,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(height: 1, color: _dividerColor),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => onKeyPressed(_showEquals ? '=' : 'confirm'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        _showEquals ? '=' : '确定',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const hw = 10.0;
    const hh = 7.0;

    // Left part of the arrow (backspace triangle)
    final path = Path()
      ..moveTo(centerX + hw * 0.3, centerY - hh)
      ..lineTo(centerX - hw * 0.3, centerY)
      ..lineTo(centerX + hw * 0.3, centerY + hh);
    canvas.drawPath(path, paint);

    // Right lines
    paint..strokeWidth = 1.8;
    canvas.drawLine(Offset(centerX - hw * 0.15, centerY - hh * 0.5), Offset(centerX + hw * 0.6, centerY + hh * 0.5), paint);
    canvas.drawLine(Offset(centerX + hw * 0.6, centerY - hh * 0.5), Offset(centerX - hw * 0.15, centerY + hh * 0.5), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
