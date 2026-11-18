import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:readmate/core/constants/enums/enums.dart';

class DisplayCubit extends HydratedCubit<DisplayState> {
  DisplayCubit() : super(DisplayState.initial());

  void setDisplayType(DisplayType type) {
    emit(state.copyWith(type: type));
  }

  void setGridSize(int value) {
    emit(state.copyWith(gridSize: value));
  }

  @override
  DisplayState? fromJson(Map<String, dynamic> json) =>
      DisplayState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(DisplayState state) => state.toJson();
}

class DisplayState extends Equatable {
  final DisplayType type;
  final int gridSize;

  const DisplayState({
    required this.type,
    required this.gridSize,
  });

  factory DisplayState.initial() {
    return const DisplayState(
      type: DisplayType.list,
      gridSize: 3,
    );
  }

  DisplayState copyWith({
    DisplayType? type,
    int? gridSize,
  }) {
    return DisplayState(
      type: type ?? this.type,
      gridSize: gridSize ?? this.gridSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_state': _displayTypeToString(type),
        'grid_size': gridSize,
      };

  static DisplayState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final displayStateStr = json['display_state'] as String?;
    final gridSize = json['grid_size'] as int? ?? 3;

    final type = _displayTypeFromString(displayStateStr);
    if (type == null) return null;

    return DisplayState(
      type: type,
      gridSize: gridSize,
    );
  }

  static String _displayTypeToString(DisplayType type) {
    switch (type) {
      case DisplayType.list:
        return 'list';
      case DisplayType.grid:
        return 'grid';
    }
  }

  static DisplayType? _displayTypeFromString(String? string) {
    switch (string) {
      case 'list':
        return DisplayType.list;
      case 'grid':
        return DisplayType.grid;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        type,
        gridSize,
      ];
}
