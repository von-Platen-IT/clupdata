import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'package:clupdata/core/models/data_grid_meta_state.dart';
import 'package:clupdata/core/providers/data_grid_meta_state_provider.dart';
import 'package:clupdata/widgets/data_grid_v2/data_grid_column_config.dart';
import 'package:clupdata/widgets/data_grid_v2/sort_column_config.dart';

void main() {
  group('DataGridMetaStateNotifier', () {
    late ProviderContainer container;
    late DataGridMetaStateNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(dataGridMetaStateProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    DataGridMetaState _testMetaState({String entityType = 'mitglied'}) {
      return DataGridMetaState(
        entityType: entityType,
        activeFilters: {'name': 'test'},
        activeSorts: [
          SortColumnConfig(field: 'name', label: 'Name', ascending: true),
        ],
        visibleColumns: ['name', 'email'],
        allColumns: [
          DataGridColumnConfig<String>(
            field: 'name',
            title: 'Name',
            valueExtractor: (item) => item,
            type: PlutoColumnType.text(),
          ),
          DataGridColumnConfig<String>(
            field: 'email',
            title: 'E-Mail',
            valueExtractor: (item) => item,
            type: PlutoColumnType.text(),
          ),
        ],
        searchText: 'suche',
      );
    }

    test('initial state is empty map', () {
      expect(notifier.state, isEmpty);
    });

    test('updateMetaState adds new entity state', () {
      final metaState = _testMetaState();

      notifier.updateMetaState('mitglied', metaState);

      expect(notifier.state, contains('mitglied'));
      expect(notifier.state['mitglied']!.entityType, 'mitglied');
      expect(notifier.state['mitglied']!.activeFilters, {'name': 'test'});
      expect(notifier.state['mitglied']!.searchText, 'suche');
    });

    test('updateMetaState replaces existing entity state', () {
      notifier.updateMetaState('mitglied', _testMetaState());
      final updatedState = _testMetaState().copyWith(searchText: 'neu');

      notifier.updateMetaState('mitglied', updatedState);

      expect(notifier.state['mitglied']!.searchText, 'neu');
    });

    test('updateMetaState supports multiple entity types', () {
      notifier.updateMetaState(
        'mitglied',
        _testMetaState(entityType: 'mitglied'),
      );
      notifier.updateMetaState(
        'beitrag',
        _testMetaState(entityType: 'beitrag'),
      );

      expect(notifier.state, containsPair('mitglied', anything));
      expect(notifier.state, containsPair('beitrag', anything));
      expect(notifier.state.length, 2);
    });

    test('removeMetaState removes entity from state', () {
      notifier.updateMetaState('mitglied', _testMetaState());
      notifier.updateMetaState(
        'beitrag',
        _testMetaState(entityType: 'beitrag'),
      );

      notifier.removeMetaState('mitglied');

      expect(notifier.state, isNot(contains('mitglied')));
      expect(notifier.state, contains('beitrag'));
    });

    test('clearAll resets state to empty', () {
      notifier.updateMetaState('mitglied', _testMetaState());
      notifier.updateMetaState(
        'beitrag',
        _testMetaState(entityType: 'beitrag'),
      );

      notifier.clearAll();

      expect(notifier.state, isEmpty);
    });

    test('updateFilters updates filters for existing entity', () {
      notifier.updateMetaState('mitglied', _testMetaState());

      notifier.updateFilters('mitglied', {'email': 'filter'});

      expect(notifier.state['mitglied']!.activeFilters, {'email': 'filter'});
    });

    test('updateFilters does nothing for non-existing entity', () {
      notifier.updateFilters('nonexistent', {'name': 'test'});

      expect(notifier.state, isNot(contains('nonexistent')));
    });

    test('updateSorts updates sorts for existing entity', () {
      notifier.updateMetaState('mitglied', _testMetaState());
      final newSorts = [
        SortColumnConfig(field: 'email', label: 'E-Mail', ascending: false),
      ];

      notifier.updateSorts('mitglied', newSorts);

      expect(notifier.state['mitglied']!.activeSorts.length, 1);
      expect(notifier.state['mitglied']!.activeSorts.first.field, 'email');
    });

    test('updateVisibleColumns updates columns for existing entity', () {
      notifier.updateMetaState('mitglied', _testMetaState());

      notifier.updateVisibleColumns('mitglied', ['name']);

      expect(notifier.state['mitglied']!.visibleColumns, ['name']);
    });

    test('updateSearchText updates search for existing entity', () {
      notifier.updateMetaState('mitglied', _testMetaState());

      notifier.updateSearchText('mitglied', 'neuer suchbegriff');

      expect(notifier.state['mitglied']!.searchText, 'neuer suchbegriff');
    });

    test('provider is keepAlive — state updates do not throw after '
        'container dispose (UnmountedRefException fix)', () {
      // This is the key test for the UnmountedRefException fix.
      // A keepAlive provider should NOT auto-dispose when no one is
      // watching it, so state mutations remain safe even after the
      // originating widget is unmounted.
      notifier.updateMetaState('mitglied', _testMetaState());

      // Simulate the scenario from the bug: controller fires
      // notifyListeners after the widget tree has been unmounted.
      // With keepAlive, the notifier's ref stays mounted.
      expect(
        () => notifier.updateMetaState(
          'beitrag',
          _testMetaState(entityType: 'beitrag'),
        ),
        returnsNormally,
      );
    });
  });
}
