import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sales_repository.g.dart';

class Sale {
  final int id;
  final String itemName;
  final double price;
  final DateTime saleDate;

  Sale({required this.id, required this.itemName, required this.price, required this.saleDate});
}

@riverpod
Stream<List<Sale>> recentSales(Ref ref) async* {
  yield [];
}

class SalesRepository {
  Future<void> addSale(String itemName, double price, {int? memberId}) async {}
}

@riverpod
SalesRepository salesRepository(Ref ref) {
  return SalesRepository();
}
