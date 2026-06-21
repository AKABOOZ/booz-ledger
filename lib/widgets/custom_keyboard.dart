import 'package:flutter/material.dart';
import 'package:ledger_app/models/enums.dart';

class CustomKeyboard extends StatelessWidget {
  const CustomKeyboard({
    required this.onKeyPressed,
    required this.currentType,
    required this.onTypeChanged,
    required this.isCalculated,
    super.key,
  });

  final void Function(String key) onKeyPressed;
  final LedgerEntryType currentType;
  final void Function(LedgerEntryType type) onTypeChanged;
  final bool isCalculated;

  // Figma colors
  static const _teal = Color(0xFF00696D);
  static const _sidebarBg = Color(0xFFF8F8F8);
  static const _selectedBg = Color(0xFFE2F3EB);
  static const _unselectedText = Color(0xFF666666);
  static const _keyText = Color(0xFF000000);
  static const _deleteColor = Color(0xFF333333);
  static const _dividerColor = Color(0xFFD9D9D9);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 44,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTopBar(),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 44,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => onKeyPressed('collapse'),
        child: const Icon(
          Icons.keyboard_arrow_down,
          size: 22,
          color: Color(0xFF999999),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        _buildSidebar(),
        Expanded(child: _buildNumberPad()),
        _buildOperatorColumn(),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 59,
      color: _sidebarBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypeButton('支出', LedgerEntryType.expense),
          Container(height: 1, color: _dividerColor),
          _buildTypeButton('收入', LedgerEntryType.income),
          Container(height: 1, color: _dividerColor),
          _buildTypeButton('转账', LedgerEntryType.transfer),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, LedgerEntryType type) {
    final isSelected = currentType == type;
    return GestureDetector(
      onTap: () => onTypeChanged(type),
      child: Container(
        height: 87,
        alignment: Alignment.center,
        color: isSelected ? _selectedBg : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? _teal : _unselectedText,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNumberRow(['7', '8', '9']),
        _buildNumberRow(['4', '5', '6']),
        _buildNumberRow(['1', '2', '3']),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildNumberRow(List<String> keys) {
    return Row(
      children: keys.map((key) => _buildKey(key, 65)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        _buildKey('.', 72),
        _buildKey('0', 72),
        _buildDeleteKey(72),
      ],
    );
  }

  Widget _buildKey(String key, double height) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onKeyPressed(key),
        child: Container(
          height: height,
          alignment: Alignment.center,
          color: Colors.white,
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w400,
              color: _keyText,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey(double height) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onKeyPressed('⌫'),
        child: Container(
          height: height,
          alignment: Alignment.center,
          color: Colors.white,
          child: const Icon(
            Icons.keyboard_backspace_outlined,
            size: 28,
            color: _deleteColor,
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOperatorButton('-', 65),
        _buildOperatorButton('+', 65),
        _buildEqualsButton(65 + 72),
      ],
    );
  }

  Widget _buildOperatorButton(String op, double height) {
    return GestureDetector(
      onTap: () => onKeyPressed(op),
      child: Container(
        height: height,
        width: 72,
        alignment: Alignment.center,
        color: Colors.white,
        child: Text(
          op,
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w400,
            color: _keyText,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEqualsButton(double height) {
    return GestureDetector(
      onTap: () => onKeyPressed(isCalculated ? 'confirm' : '='),
      child: Container(
        height: height,
        width: 72,
        alignment: Alignment.center,
        color: _teal,
        child: Text(
          isCalculated ? '确定' : '=',
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
