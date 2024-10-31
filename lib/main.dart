import 'dart:async';
import 'package:flutter/material.dart';

// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// A widget that builds the [MaterialApp].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (icon) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[icon.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(icon, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A dock of reorderable [items].
/// Convert T to T extends Object for LongPressDraggable and DragTarget
class Dock<T extends Object> extends StatefulWidget {
  /// Creates a [Dock] widget.
  const Dock({
    super.key,
    required this.items,
    required this.builder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}
/// State of the [Dock] used to manipulate the [_items].
class _DockState<T extends Object> extends State<Dock<T>> {
  /// The items in the dock, managed by a [ValueNotifier] to enable reactivity.
  late final ValueNotifier<List<T>> _itemsNotifier;

  /// Index of the item being dragged, or null if no item is being dragged.
  final ValueNotifier<int?> _draggingIndexNotifier = ValueNotifier<int?>(null);

  /// Index where the item is being hovered.
  final ValueNotifier<int?> _hoverIndexNotifier = ValueNotifier<int?>(null);

  /// Timer for controlling the delay for long-press actions.
  Timer? _longPressTimer;

  /// Long press duration before initiating a drag.
  static const Duration _longPressDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    /// Initializes the notifier with a copy of the items.
    _itemsNotifier = ValueNotifier<List<T>>(widget.items.toList());
  }

  @override
  void dispose() {
    /// Cancel active timers and dispose of the notifiers to prevent data leaks.
    _longPressTimer?.cancel();
    _itemsNotifier.dispose();
    _draggingIndexNotifier.dispose();
    _hoverIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      child: ValueListenableBuilder<List<T>>(
        valueListenable: _itemsNotifier,
        builder: (context, items, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: items.asMap().entries.map((entry) {
              return DraggableItemWidget<T>(
                item: entry.value,
                index: entry.key,
                builder: widget.builder,
                hoverIndexNotifier: _hoverIndexNotifier,
                draggingIndexNotifier: _draggingIndexNotifier,
                onLongPress: _startLongPress,
                onDragStarted: _onDragStarted,
                onDragEnd: _resetDrag,
                reorderItems: _reorderItems,
                itemsNotifier: _itemsNotifier,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  /// Called when a drag operation starts.
  void _onDragStarted(int index) {
    _longPressTimer?.cancel();
    _draggingIndexNotifier.value = index;
  }

  /// Reorders items in the dock.
  void _reorderItems(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final updatedItems = List<T>.from(_itemsNotifier.value);
    final item = updatedItems.removeAt(oldIndex);
    updatedItems.insert(newIndex, item);

    _itemsNotifier.value = updatedItems;
    _hoverIndexNotifier.value = newIndex;
  }

  /// Resets the dragging state.
  void _resetDrag() {
    _longPressTimer?.cancel();
    _draggingIndexNotifier.value = null;
    _hoverIndexNotifier.value = null;
  }

  /// Initiates a long press timer for the given index.
  void _startLongPress(int index) {
    _longPressTimer = Timer(_longPressDuration, () {
      _draggingIndexNotifier.value = index;
    });
  }
}

/// Widget for each draggable item.
class DraggableItemWidget<T extends Object> extends StatelessWidget {
  /// Creates a [DraggableItemWidget].
  const DraggableItemWidget({
    super.key,
    required this.item,
    required this.index,
    required this.builder,
    required this.hoverIndexNotifier,
    required this.draggingIndexNotifier,
    required this.onLongPress,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.reorderItems,
    required this.itemsNotifier,
  });

  /// The item represented by this widget.
  final T item;

  /// The index of the item in the dock.
  final int index;

  /// A builder function that creates a widget for this item.
  final Widget Function(T) builder;

  /// Notifier for the index being hovered over.
  final ValueNotifier<int?> hoverIndexNotifier;

  /// Notifier for the index being dragged.
  final ValueNotifier<int?> draggingIndexNotifier;

  /// Callback for long press actions.
  final void Function(int) onLongPress;

  /// Callback for when dragging starts.
  final void Function(int) onDragStarted;

  /// Callback for when dragging ends.
  final VoidCallback onDragEnd;

  /// Callback for reordering items in the dock.
  final void Function(int oldIndex, int newIndex) reorderItems;

  /// Notifier for the list of items in the dock.
  final ValueNotifier<List<T>> itemsNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: hoverIndexNotifier,
      builder: (context, hoverIndex, child) {
        return DragTarget<T>(
          onWillAcceptWithDetails: (details) {
            hoverIndexNotifier.value = index;
            if (details.data != item) {
              final draggedIndex = itemsNotifier.value.indexOf(details.data);
              reorderItems(draggedIndex, index);
            }
            return true;
          },
          onAcceptWithDetails: (details) => _onItemAccepted(details.data),
          onLeave: (_) => _clearHover(),
          builder: (context, candidateData, rejectedData) {
            return GestureDetector(
              onLongPress: () => onLongPress(index),
              onLongPressUp: _cancelLongPress,
              child: LongPressDraggable<T>(
                data: item,
                onDragStarted: () => onDragStarted(index),
                onDragCompleted: onDragEnd,
                onDraggableCanceled: (_, __) => onDragEnd(),
                feedback: Opacity(
                  opacity: 0.7,
                  child: builder(item),
                ),
                child: ValueListenableBuilder<int?>(
                  valueListenable: draggingIndexNotifier,
                  builder: (context, draggingIndex, child) {
                    return hoverIndex == index
                        ? Opacity(opacity: 0.5, child: builder(item))
                        : builder(item);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Reorders items when an item is accepted at a new index.
  void _onItemAccepted(T receivedItem) {
    final currentIndex = itemsNotifier.value.indexOf(receivedItem);
    if (currentIndex != index) {
      final updatedItems = List<T>.from(itemsNotifier.value);
      updatedItems.removeAt(currentIndex);
      updatedItems.insert(index, receivedItem);
      itemsNotifier.value = updatedItems;
    }
  }

  /// Clears the hover state.
  void _clearHover() {
    hoverIndexNotifier.value = null;
  }

  /// Stops the draggable action.
  void _cancelLongPress() {
    onDragEnd();
  }
}
