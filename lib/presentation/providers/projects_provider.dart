import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/approved_project_repository.dart';
import '../../domain/models/approved_project.dart';

class ProjectsState {
  final List<ApprovedProject> projects;
  final bool isLoading;
  final String searchQuery;

  const ProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.searchQuery = '',
  });

  List<ApprovedProject> get filteredProjects {
    if (searchQuery.trim().isEmpty) return projects;
    final query = searchQuery.trim().toLowerCase();
    return projects
        .where((p) =>
            p.clientName.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query))
        .toList();
  }

  ProjectsState copyWith({
    List<ApprovedProject>? projects,
    bool? isLoading,
    String? searchQuery,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn,
    {required ProjectsState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e) {
      print('ProjectsProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e) {
      print('ProjectsProvider Error: $e');
    }
  }
}

class ProjectsNotifier extends StateNotifier<ProjectsState> {
  final ApprovedProjectRepository _repository = ApprovedProjectRepository();

  ProjectsNotifier() : super(const ProjectsState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllProjects();
        state = state.copyWith(projects: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false, projects: []),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> loadProjects() async {
    await _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllProjects();
        state = state.copyWith(projects: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false),
    );
  }

  Future<int> addProject(ApprovedProject project) async {
    final id = await _repository.insertProject(project);
    await loadProjects();
    return id;
  }

  Future<void> updateProject(ApprovedProject project) async {
    await _repository.updateProject(project);
    await loadProjects();
  }

  Future<void> deleteProject(int id) async {
    await _repository.deleteProject(id);
    await loadProjects();
  }
}

final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, ProjectsState>((ref) {
  return ProjectsNotifier();
});
