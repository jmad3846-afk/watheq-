import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/client_repository.dart';
import '../../domain/models/client.dart';

class ClientsState {
  final List<Client> clients;
  final bool isLoading;
  final String searchQuery;

  const ClientsState({
    this.clients = const [],
    this.isLoading = false,
    this.searchQuery = '',
  });

  List<Client> get filteredClients {
    if (searchQuery.trim().isEmpty) return clients;
    final query = searchQuery.trim().toLowerCase();
    return clients.where((c) =>
      c.name.toLowerCase().contains(query) ||
      c.phone.contains(query) ||
      c.address.toLowerCase().contains(query) ||
      c.profession.toLowerCase().contains(query)
    ).toList();
  }

  ClientsState copyWith({
    List<Client>? clients,
    bool? isLoading,
    String? searchQuery,
  }) {
    return ClientsState(
      clients: clients ?? this.clients,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn, {required ClientsState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('ClientsProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('ClientsProvider Error: $e');
    }
  }
}

class ClientsNotifier extends StateNotifier<ClientsState> {
  final ClientRepository _repository = ClientRepository();

  ClientsNotifier() : super(const ClientsState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllClients();
        state = state.copyWith(clients: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false, clients: []),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> loadClients() async {
    await _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllClients();
        state = state.copyWith(clients: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false),
    );
  }

  Future<int> addClient(Client client) async {
    final id = await _repository.insertClient(client);
    await loadClients();
    return id;
  }

  Future<void> updateClient(Client client) async {
    await _repository.updateClient(client);
    await loadClients();
  }

  Future<void> deleteClient(int id) async {
    await _repository.deleteClient(id);
    await loadClients();
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, ClientsState>((ref) {
  return ClientsNotifier();
});
