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

  late final List<T> _initialOrder;

  T? _draggedItem;

  /// Index of the item being dragged, or null if no item is being dragged.
  final ValueNotifier<int?> _draggingIndexNotifier = ValueNotifier<int?>(null);

  /// Index where the item is being hovered.
  final ValueNotifier<int?> _hoverIndexNotifier = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _initialOrder = List<T>.from(widget.items);
    _itemsNotifier = ValueNotifier<List<T>>(List<T>.from(_initialOrder));
  }

  @override
  void dispose() {
    /// Cancel active timers and dispose of the notifiers to prevent data leaks.
    _itemsNotifier.dispose();
    _draggingIndexNotifier.dispose();
    _hoverIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
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
                final item = entry.value;
                final index = entry.key;

                return DraggableItemWidget<T>(
                  item: item,
                  index: index,
                  builder: widget.builder,
                  hoverIndexNotifier: _hoverIndexNotifier,
                  draggingIndexNotifier: _draggingIndexNotifier,
                  onDragStarted: () => _onDragStarted(index),
                  onDragEnd: _resetDrag,
                  reorderItems: _reorderItems,
                  itemsNotifier: _itemsNotifier,
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  /// Called when a drag operation starts.
  void _onDragStarted(int index) {
    if (_draggingIndexNotifier.value == null) {
      /// Ensures the item at the specified index is removed only once
      _draggedItem = _itemsNotifier.value[index];
      _itemsNotifier.value = List<T>.from(_itemsNotifier.value)
        ..removeAt(index);
      _draggingIndexNotifier.value = index;
    }
  }

  /// Reorders items in the dock.
  void _reorderItems(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || _draggedItem == null) return;
    if (_itemsNotifier.value.length < 5 && _itemsNotifier.value.length == 4) {
      final updatedItems = List<T>.from(_itemsNotifier.value);

      updatedItems.removeWhere((item) => item == _draggedItem);

      updatedItems.insert(newIndex, _draggedItem!);

      _initialOrder
        ..clear()
        ..addAll(updatedItems);

      _itemsNotifier.value = updatedItems;
      _hoverIndexNotifier.value = newIndex;
    }
  }

  /// Resets the dragging state.
  void _resetDrag() {
    if (_draggedItem != null && _itemsNotifier.value.length == 5) {
      final currentItems = List<T>.from(_itemsNotifier.value);
      if (!currentItems.contains(_draggedItem)) {
        currentItems.insert(_draggingIndexNotifier.value!, _draggedItem!);
      }
      _itemsNotifier.value = currentItems;
    }
    _draggedItem = null;
    _draggingIndexNotifier.value = null;
    _hoverIndexNotifier.value = null;
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

  /// Callback for when dragging Starts.
  final VoidCallback onDragStarted;

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
              onLongPress: onDragStarted,
              child: LongPressDraggable<T>(
                data: item,
                onDragStarted: onDragStarted,
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
                        ? const Offstage()
                        : AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: draggingIndex == index ? 0.0 : 1.0,
                            child: builder(item),
                          );
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
}
