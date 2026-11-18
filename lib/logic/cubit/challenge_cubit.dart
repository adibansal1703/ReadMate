import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/resources/api_book_repository.dart';

class ChallengeCubit extends Cubit<int> {
  ApiBookRepository? _repository;

  ChallengeCubit() : super(0);

  void setRepository(ApiBookRepository repository) {
    _repository = repository;
    _fetchFromCloud();
  }

  void setGoal(int goal) {
    debugPrint("Setting yearly challenge goal to: $goal");
    emit(goal);
    _syncToCloud(goal);
  }

  Future<void> clear() async {
    emit(0);
  }

  Future<void> _syncToCloud(int goal) async {
    if (_repository == null) return;
    try {
      await _repository!.updateYearlyGoal(goal);
    } catch (e) {
      debugPrint("Cloud goal sync error: $e");
    }
  }

  Future<void> _fetchFromCloud() async {
    if (_repository == null) return;
    try {
      final userId = _repository!.uid;
      if (userId == null) return;
      
      final profile = await _repository!.getProfile(userId);
      if (profile != null && profile['yearly_goal'] != null) {
        final cloudGoal = profile['yearly_goal'] as int;
        if (cloudGoal > 0) {
          emit(cloudGoal);
        }
      }
    } catch (e) {
      debugPrint("Cloud goal fetch error: $e");
    }
  }
}
