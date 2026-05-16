import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/design_system/design_tokens.dart';
import '../../../shared/models/food_models.dart';

/// Callbacks for the review card.
class FoodReviewActions {
  const FoodReviewActions({
    required this.onLog,
    this.onEditItem,
    this.onDeleteItem,
    this.onAddItem,
    this.onMealTypeChanged,
  });

  /// Called with the final analysis result and selected meal type when user taps Log.
  final void Function(FoodAnalysisResult result, MealType mealType) onLog;
  final void Function(int index, FoodItem updated)? onEditItem;
  final void Function(int index)? onDeleteItem;
  final void Function(FoodItem item)? onAddItem;
  final void Function(MealType type)? onMealTypeChanged;
}

/// Displays an AI-analyzed meal for user review before logging.
class FoodReviewCard extends ConsumerStatefulWidget {
  const FoodReviewCard({
    super.key,
    required this.result,
    this.photoPath,
    required this.actions,
    this.initialMealType,
  });

  final FoodAnalysisResult result;
  final String? photoPath;
  final FoodReviewActions actions;
  final MealType? initialMealType;

  @override
  ConsumerState<FoodReviewCard> createState() => _FoodReviewCardState();
}

class _FoodReviewCardState extends ConsumerState<FoodReviewCard> {
  late MealType _mealType;
  late List<FoodItem> _items;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType ?? _inferMealType();
    _items = List.from(widget.result.items);
  }

  MealType _inferMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 15 && hour < 18) return MealType.snack;
    return MealType.dinner;
  }

  int get _totalCalories => _items.fold(0, (s, i) => s + i.calories);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.bgSurfaceDark : DesignTokens.bgSurfaceLight;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;
    final accent = isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: border, width: DesignTokens.borderWidthDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo thumbnail
          if (widget.photoPath != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.file(
                  File(widget.photoPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: bg,
                    child: Center(
                      child: Icon(LucideIcons.imageOff, color: textMuted, size: 32),
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total + confidence
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated total',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_totalCalories kcal',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ConfidenceBadge(level: widget.result.overallConfidence),
                  ],
                ),
                const SizedBox(height: 12),

                // Meal type selector
                _MealTypeSelector(
                  value: _mealType,
                  onChanged: (t) {
                    setState(() => _mealType = t);
                    widget.actions.onMealTypeChanged?.call(t);
                  },
                ),
                const SizedBox(height: 16),

                // Items list
                Text(
                  'Items identified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return _ItemRow(
                    item: item,
                    isEditing: _editingIndex == idx,
                    onTap: () => setState(() => _editingIndex = idx),
                    onCloseEdit: () => setState(() => _editingIndex = null),
                    onUpdate: (updated) {
                      setState(() {
                        _items[idx] = updated;
                        _editingIndex = null;
                      });
                      widget.actions.onEditItem?.call(idx, updated);
                    },
                    onDelete: () {
                      setState(() => _items.removeAt(idx));
                      widget.actions.onDeleteItem?.call(idx);
                    },
                  );
                }),
                const SizedBox(height: 8),

                // Add missing item
                _AddItemButton(
                  onAdd: (item) {
                    setState(() => _items.add(item));
                    widget.actions.onAddItem?.call(item);
                  },
                ),
                const SizedBox(height: 16),

                // Log button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: isDark
                          ? DesignTokens.bgBaseDark
                          : DesignTokens.bgBaseLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      final result = FoodAnalysisResult(
                        mealName: widget.result.mealName,
                        totalCalories: _totalCalories,
                        totalProteinG: _items.fold(0, (s, i) => s + i.proteinG),
                        totalCarbsG: _items.fold(0, (s, i) => s + i.carbsG),
                        totalFatG: _items.fold(0, (s, i) => s + i.fatG),
                        overallConfidence: widget.result.overallConfidence,
                        confidenceNote: widget.result.confidenceNote,
                        items: _items,
                      );
                      widget.actions.onLog(result, _mealType);
                    },
                    child: Text(
                      'Log $_totalCalories kcal',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.level});
  final ConfidenceLevel level;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (level) {
      ConfidenceLevel.high => isDark ? DesignTokens.okTextDark : const Color(0xFF2E7D32),
      ConfidenceLevel.medium => isDark ? DesignTokens.warnTextDark : const Color(0xFFF57C00),
      ConfidenceLevel.low => isDark ? DesignTokens.warnTextDark : const Color(0xFFD32F2F),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Text(
        '${level.dots} ${level.label}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _MealTypeSelector extends StatelessWidget {
  const _MealTypeSelector({required this.value, required this.onChanged});
  final MealType value;
  final ValueChanged<MealType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final activeBg = isDark
        ? DesignTokens.accentActiveDark.withValues(alpha: 0.4)
        : DesignTokens.accentActiveLight.withValues(alpha: 0.7);
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;

    return Wrap(
      spacing: 8,
      children: MealType.values.map((type) {
        final active = type == value;
        return ChoiceChip(
          label: Text(type.label),
          selected: active,
          onSelected: (_) => onChanged(type),
          selectedColor: activeBg,
          backgroundColor: isDark ? DesignTokens.bgBaseDark : DesignTokens.bgBaseLight,
          side: BorderSide(color: border),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? textPrimary : textMuted,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        );
      }).toList(),
    );
  }
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({
    required this.item,
    required this.isEditing,
    required this.onTap,
    required this.onCloseEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  final FoodItem item;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onCloseEdit;
  final ValueChanged<FoodItem> onUpdate;
  final VoidCallback onDelete;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.item.estimatedWeightG.toDouble();
  }

  @override
  void didUpdateWidget(covariant _ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.estimatedWeightG != widget.item.estimatedWeightG) {
      _sliderValue = widget.item.estimatedWeightG.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;
    final textPrimary = isDark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Column(
        children: [
          // Collapsed row
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: switch (widget.item.confidence) {
                  ConfidenceLevel.high => Colors.green,
                  ConfidenceLevel.medium => Colors.orange,
                  ConfidenceLevel.low => Colors.red,
                },
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              widget.item.name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
            ),
            subtitle: Text(
              '${widget.item.estimatedWeightG}g · ${widget.item.calories} kcal · P ${widget.item.proteinG.toStringAsFixed(0)}g',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.item.confidence.dots,
                  style: TextStyle(fontSize: 10, color: textMuted),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronDown, size: 16, color: textMuted),
              ],
            ),
            onTap: widget.onTap,
          ),

          // Expanded editor
          if (widget.isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: border),
                  const SizedBox(height: 12),

                  // Weight slider
                  Row(
                    children: [
                      Text('Weight', style: TextStyle(fontSize: 12, color: textMuted)),
                      const SizedBox(width: 8),
                      Text(
                        '${_sliderValue.round()}g',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.item.withWeight(_sliderValue.round()).calories} kcal',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _sliderValue.clamp(10.0, 1000.0),
                    min: 10,
                    max: 1000,
                    divisions: 99,
                    onChanged: (v) => setState(() => _sliderValue = v),
                  ),

                  // Quick picks
                  Wrap(
                    spacing: 8,
                    children: [
                      _QuickPick(label: 'Small', scale: 0.7, onTap: _applyScale),
                      _QuickPick(label: 'Medium', scale: 1.0, onTap: _applyScale),
                      _QuickPick(label: 'Large', scale: 1.5, onTap: _applyScale),
                      _QuickPick(label: 'Double', scale: 2.0, onTap: _applyScale),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          widget.onUpdate(widget.item.withWeight(_sliderValue.round()));
                        },
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text('Confirm'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: Icon(LucideIcons.trash2, size: 16, color: Colors.red.shade400),
                        label: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _applyScale(double scale) {
    final base = widget.item.estimatedWeightG > 0 ? widget.item.estimatedWeightG : 100;
    setState(() => _sliderValue = (base * scale).clamp(10.0, 1000.0));
  }
}

class _QuickPick extends StatelessWidget {
  const _QuickPick({required this.label, required this.scale, required this.onTap});
  final String label;
  final double scale;
  final void Function(double) onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    return OutlinedButton(
      onPressed: () => onTap(scale),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: border),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: textMuted)),
    );
  }
}

class _AddItemButton extends StatefulWidget {
  const _AddItemButton({required this.onAdd});
  final ValueChanged<FoodItem> onAdd;

  @override
  State<_AddItemButton> createState() => _AddItemButtonState();
}

class _AddItemButtonState extends State<_AddItemButton> {
  bool _expanded = false;
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? DesignTokens.borderDefaultDark : DesignTokens.borderDefaultLight;
    final textMuted = isDark ? DesignTokens.textMutedDark : DesignTokens.textMutedLight;

    if (!_expanded) {
      return TextButton.icon(
        onPressed: () => setState(() => _expanded = true),
        icon: Icon(LucideIcons.plus, size: 16, color: textMuted),
        label: Text('Add missing item', style: TextStyle(fontSize: 13, color: textMuted)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Food name',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _calCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Kcal',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: Text('Cancel', style: TextStyle(color: textMuted)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  final cal = int.tryParse(_calCtrl.text) ?? 0;
                  if (name.isEmpty || cal <= 0) return;
                  widget.onAdd(FoodItem(
                    name: name,
                    estimatedWeightG: 0,
                    calories: cal,
                    proteinG: 0,
                    carbsG: 0,
                    fatG: 0,
                    confidence: ConfidenceLevel.high,
                    cookingMethod: 'unknown',
                    portionReference: 'user-added',
                  ));
                  _nameCtrl.clear();
                  _calCtrl.clear();
                  setState(() => _expanded = false);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
