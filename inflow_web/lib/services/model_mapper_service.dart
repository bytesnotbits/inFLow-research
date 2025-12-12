import '../models/inventory_transaction.dart';
import '../models/product.dart';
import '../models/purchase_order_line.dart';
import '../models/reorder_setting.dart';
import '../models/sales_order_line.dart';
import '../models/stock_level.dart';

class ModelMapperService {
  static Product? mapToProduct(Map<String, String> row) {
    try {
      return Product(
        sku: row['SKU'] ?? row['ProductSKU'] ?? row['ProductName'] ?? '',
        name: row['ProductName'] ?? row['SKU'] ?? '',
        description: row['ProductDescription'] ?? row['Description'] ?? '',
        category: row['Category'] ?? '',
        isActive: _parseBool(row['IsActive'], fallback: true),
        defaultUnitPrice:
            _parseDouble(row['DefaultUnitPrice'] ?? row['ProductUnitPrice']),
        vendor: row['Vendor'] ?? row['LastVendor'] ?? '',
        uom: row['Uom'] ?? row['ProductQuantityUoM'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static SalesOrderLine? mapToSalesOrderLine(Map<String, String> row) {
    try {
      return SalesOrderLine(
        orderNumber: row['OrderNumber'] ?? '',
        customer: row['Customer'] ?? '',
        orderDate: DateTime.tryParse(row['OrderDate'] ?? '') ?? DateTime(1970),
        productSku: row['ProductSKU'] ?? row['SKU'] ?? row['ProductName'] ?? '',
        productName: row['ProductName'] ?? row['SKU'] ?? '',
        productDescription:
            row['ProductDescription'] ?? row['Description'] ?? '',
        quantity: _parseDouble(row['ProductQuantity'] ?? row['Quantity']),
        unitPrice: _parseDouble(row['ProductUnitPrice'] ?? row['UnitPrice']),
        location: row['Location'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static PurchaseOrderLine? mapToPurchaseOrderLine(Map<String, String> row) {
    try {
      return PurchaseOrderLine(
        orderNumber: row['OrderNumber'] ?? '',
        vendor: row['Vendor'] ?? '',
        orderDate: DateTime.tryParse(row['OrderDate'] ?? '') ?? DateTime(1970),
        productSku: row['ProductSKU'] ?? row['SKU'] ?? row['ProductName'] ?? '',
        productName: row['ProductName'] ?? row['SKU'] ?? '',
        productDescription:
            row['ProductDescription'] ?? row['Description'] ?? '',
        quantity: _parseDouble(row['ProductQuantity'] ?? row['Quantity']),
        unitPrice: _parseDouble(row['ProductUnitPrice'] ?? row['UnitPrice']),
        location: row['Location'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static InventoryTransaction? mapToInventoryTransaction(
      Map<String, String> row) {
    try {
      return InventoryTransaction(
        transactionType: row['TransactionType'] ?? '',
        date: DateTime.tryParse(row['Date'] ?? '') ?? DateTime(1970),
        location: row['Location'] ?? '',
        sublocation: row['ReelNumber'] ?? row['Sublocation'] ?? '',
        orderNumber: row['OrderNumber'] ?? '',
        quantity: _parseDouble(row['Quantity']),
        qtyBefore: _parseDouble(row['QtyBefore']),
        qtyAfter: _parseDouble(row['QtyAfter']),
      );
    } catch (_) {
      return null;
    }
  }

  static StockLevel? mapToStockLevel(Map<String, String> row) {
    try {
      return StockLevel(
        productName: row['ProductName'] ?? '',
        location: row['Location'] ?? '',
        sublocation: row['Sublocation'] ?? '',
        serial: row['Serial'] ?? '',
        quantity: _parseDouble(row['Quantity']),
      );
    } catch (_) {
      return null;
    }
  }

  static ReorderSetting? mapToReorderSetting(Map<String, String> row) {
    try {
      return ReorderSetting(
        productName: row['ProductName'] ?? '',
        location: row['Location'] ?? '',
        defaultSublocation: row['DefaultSublocation'] ?? '',
        enableReordering: _parseBool(row['EnableReordering']),
        reorderPoint: _parseDouble(row['ReorderPoint']),
        reorderQuantity: _parseDouble(row['ReorderQuantity']),
        reorderMethod: row['ReorderMethod'] ?? '',
        vendor: row['Vendor'] ?? '',
        fromLocation: row['FromLocation'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static double _parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    return double.tryParse(value.replaceAll(',', '')) ?? 0;
  }

  static bool _parseBool(String? value, {bool fallback = false}) {
    if (value == null) return fallback;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return fallback;
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'n') {
      return false;
    }
    return fallback;
  }
}
