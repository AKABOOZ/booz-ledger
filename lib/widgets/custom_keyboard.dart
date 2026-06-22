import 'package:flutter/material.dart';
import 'package:ledger_app/models/enums.dart';

class CustomKeyboard extends StatelessWidget {
  const CustomKeyboard({
    required this.onKeyPressed,
    required this.currentType,
    required this.onTypeChanged,
    required this.isCalculated,
    this.hasExpression = false,
    super.key,
  });

  final void Function(String key) onKeyPressed;
  final LedgerEntryType currentType;
  final void Function(LedgerEntryType type) onTypeChanged;
  final bool isCalculated;
  final bool hasExpression;

  // ── Design tokens ──────────────────────────────────
  static const _teal = Color(0xFF00696D);
  static const _confirmDark = Color(0xFF004C4F);
  static const _keyBg = Color(0xFFFFFFFF);
  static const _keyText = Color(0xFF000000);
  static const _deleteIcon = Color(0xFF333333);
  static const _pressedBg = Color(0xFFB6BDC5);
  static const _unselectedText = Color(0xFF666666);

  // Layout constants
  static const double _radius = 12;
  static const double _gap = 5;
  static const double _sidebarW = 44;
  static const double _operatorW = 54;
  static const double _topPad = 10;
  static const double _botPad = 12;
  static const double _sidePad = 8;
  static const double _rowH = 60; // each key row height

  @override
  Widget build(BuildContext context) {
    // Total content height = 4 rows + 3 gaps
    final contentH = _rowH * 4 + _gap * 3; // 252

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_sidePad, _topPad, _sidePad, _botPad),
        child: SizedBox(
          height: contentH,
          child: Stack(
            children: [
              // ── Sidebar (left, full height) ──
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _sidebarW,
                child: _buildSidebar(),
              ),
              // ── Number pad (center) ──
              Positioned(
                left: _sidebarW + _gap,
                right: _operatorW + _gap,
                top: 0,
                bottom: 0,
                child: _buildNumberPad(),
              ),
              // ── Operator column (right) ──
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _operatorW,
                child: _buildOperatorColumn(contentH),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sidebar ────────────────────────────────────────
  Widget _buildSidebar() {
    return Material(
      color: _keyBg,
      borderRadius: BorderRadius.circular(_radius),
      elevation: 0.5,
      child: Column(
        children: [
          _buildTypeButton('支\n出', LedgerEntryType.expense),
          const SizedBox(height: 4),
          _buildTypeButton('收\n入', LedgerEntryType.income),
          const SizedBox(height: 4),
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
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400,
              color: isSelected ? _teal : _unselectedText,
              decoration: TextDecoration.none,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }

  // ── Number pad ─────────────────────────────────────
  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildKeyRow(['7', '8', '9']),
        SizedBox(height: _gap),
        _buildKeyRow(['4', '5', '6']),
        SizedBox(height: _gap),
        _buildKeyRow(['1', '2', '3']),
        SizedBox(height: _gap),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return SizedBox(
      height: _rowH,
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: _gap),
            Expanded(child: _buildKey(keys[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return SizedBox(
      height: _rowH,
      child: Row(
        children: [
          Expanded(child: _buildKey('.')),
          SizedBox(width: _gap),
          Expanded(child: _buildKey('0')),
          SizedBox(width: _gap),
          Expanded(child: _buildDeleteKey()),
        ],
      ),
    );
  }

  // ── Single key ─────────────────────────────────────
  Widget _buildKey(String label) {
    return Material(
      color: _keyBg,
      borderRadius: BorderRadius.circular(_radius),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        splashColor: Colors.transparent,
        highlightColor: _pressedBg,
        onTap: () => onKeyPressed(label),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _keyText,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return Material(
      color: _keyBg,
      borderRadius: BorderRadius.circular(_radius),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        splashColor: Colors.transparent,
        highlightColor: _pressedBg,
        onTap: () => onKeyPressed('⌫'),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            size: 22,
            color: _deleteIcon,
          ),
        ),
      ),
    );
  }

  // ── Operator column (precise Y positioning) ────────
  Widget _buildOperatorColumn(double totalH) {
    // Y positions matching number pad rows:
    // Row 1 (-):  y = 0
    // Row 2 (+):  y = rowH + gap = 64
    // Row 3+4 (confirm): y = 2*(rowH + gap) = 128
    final row2Y = _rowH + _gap;
    final row3Y = (_rowH + _gap) * 2;
    final confirmH = totalH - row3Y;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _rowH,
          child: _buildOperatorButton('-'),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: row2Y,
          height: _rowH,
          child: _buildOperatorButton('+'),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: row3Y,
          height: confirmH,
          child: _buildConfirmButton(),
        ),
      ],
    );
  }

  Widget _buildOperatorButton(String label) {
    return Material(
      color: _keyBg,
      borderRadius: BorderRadius.circular(_radius),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        splashColor: Colors.transparent,
        highlightColor: _pressedBg,
        onTap: () => onKeyPressed(label),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _teal,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Material(
      color: _teal,
      borderRadius: BorderRadius.circular(_radius),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        splashColor: Colors.transparent,
        highlightColor: _confirmDark,
        onTap: () => onKeyPressed(isCalculated ? 'confirm' : (hasExpression ? '=' : 'confirm')),
        child: Center(
          child: Text(
            isCalculated ? '确\n定' : (hasExpression ? '=' : '确\n定'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
