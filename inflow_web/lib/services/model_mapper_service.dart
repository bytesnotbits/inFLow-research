import '../models/product.dart';
import '../models/sales_order_line.dart';
import '../models/purchase_order_line.dart';
import '../models/inventory_transaction.dart';

class ModelMapperService {
  static Product? mapToProduct(Map<String, String> row) {
    try {
      return Product(
        sku: row['SKU'] ?? row['ProductSKU'] ?? row['ProductName'] ?? '',
        name: row['ProductName'] ?? row['SKU'] ?? '',
        category: row['Category'] ?? '',
        isActive: (row['IsActive'] ?? 'True').toLowerCase() == 'true',
        defaultUnitPrice: double.tryParse(row['DefaultUnitPrice'] ?? row['ProductUnitPrice'] ?? '0') ?? 0,
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
        quantity: double.tryParse(row['ProductQuantity'] ?? row['Quantity'] ?? '0') ?? 0,
        unitPrice: double.tryParse(row['ProductUnitPrice'] ?? row['UnitPrice'] ?? '0') ?? 0,
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
        quantity: double.tryParse(row['ProductQuantity'] ?? row['Quantity'] ?? '0') ?? 0,
        unitPrice: double.tryParse(row['ProductUnitPrice'] ?? row['UnitPrice'] ?? '0') ?? 0,
        location: row['Location'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static InventoryTransaction? mapToInventoryTransaction(Map<String, String> row) {
    try {
      return InventoryTransaction(
        transactionType: row['TransactionType'] ?? '',
        date: DateTime.tryParse(row['Date'] ?? '') ?? DateTime(1970),
        location: row['Location'] ?? '',
        sublocation: row['ReelNumber'] ?? row['Sublocation'] ?? '',
        orderNumber: row['OrderNumber'] ?? '',
        quantity: double.tryParse(row['Quantity'] ?? '0') ?? 0,
        qtyBefore: double.tryParse(row['QtyBefore'] ?? '0') ?? 0,
        qtyAfter: double.tryParse(row['QtyAfter'] ?? '0') ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
