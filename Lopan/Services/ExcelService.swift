//
//  ExcelService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

public class ExcelService {
    static let shared = ExcelService()
    
    private init() {}
    
    // MARK: - Export Functions
    
    func exportCustomers(_ customers: [Customer]) -> URL? {
        let csvContent = generateCustomerCSV(customers)
        return saveCSVToFile(csvContent, filename: "customers_\(Date().timeIntervalSince1970)")
    }
    
    func exportProducts(_ products: [Product]) -> URL? {
        let csvContent = generateProductCSV(products)
        return saveCSVToFile(csvContent, filename: "products_\(Date().timeIntervalSince1970)")
    }
    
    func exportReturnOrders(_ items: [CustomerOutOfStock]) -> URL? {
        let csvContent = generateReturnOrdersCSV(items)
        return saveCSVToFile(csvContent, filename: "return_orders_\(Date().timeIntervalSince1970)")
    }
    
    // MARK: - Import Functions
    
    func importCustomers(from url: URL, modelContext: ModelContext) -> ExcelImportResult {
        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines)
            
            guard lines.count > 1 else {
                return ExcelImportResult(success: false, message: "文件为空或格式不正确")
            }
            
            var importedCount = 0
            var errors: [String] = []
            
            // Skip header row
            for (index, line) in lines.enumerated().dropFirst() {
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                let columns = parseCSVLine(line)
                if columns.count >= 3 {
                    let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let address = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let phone = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !name.isEmpty && !address.isEmpty {
                        let customer = Customer(name: name, address: address, phone: phone)
                        modelContext.insert(customer)
                        importedCount += 1
                    } else {
                        errors.append("第\(index + 1)行: 姓名和地址不能为空")
                    }
                } else {
                    errors.append("第\(index + 1)行: 数据格式不正确")
                }
            }
            
            try modelContext.save()
            
            let message = "成功导入 \(importedCount) 个客户"
            if !errors.isEmpty {
                return ExcelImportResult(success: true, message: message, errors: errors)
            }
            return ExcelImportResult(success: true, message: message)
            
        } catch {
            return ExcelImportResult(success: false, message: "导入失败: \(error.localizedDescription)")
        }
    }
    
    func importProducts(from url: URL, modelContext: ModelContext) -> ExcelImportResult {
        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines)
            
            guard lines.count > 1 else {
                return ExcelImportResult(success: false, message: "文件为空或格式不正确")
            }
            
            var importedCount = 0
            var errors: [String] = []
            
            // Skip header row
            for (index, line) in lines.enumerated().dropFirst() {
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                let columns = parseCSVLine(line)
                if columns.count >= 3 {
                    let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let skuString = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let sizesString = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)

                    if !name.isEmpty {
                        let sku = skuString.isEmpty ? "PRD-\(UUID().uuidString.prefix(8))" : skuString
                        let sizes = sizesString.isEmpty ? [] : sizesString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                        let product = Product(sku: sku, name: name, imageData: nil, price: 0.0)
                        modelContext.insert(product)
                        
                        // Add sizes
                        for sizeName in sizes {
                            let size = ProductSize(size: sizeName, product: product)
                            modelContext.insert(size)
                            if product.sizes == nil {
                                product.sizes = []
                            }
                            product.sizes?.append(size)
                        }

                        // Update cached inventory status based on sizes
                        product.updateCachedInventoryStatus()

                        importedCount += 1
                    } else {
                        errors.append("第\(index + 1)行: 产品名称不能为空")
                    }
                } else {
                    errors.append("第\(index + 1)行: 数据格式不正确")
                }
            }
            
            try modelContext.save()
            
            let message = "成功导入 \(importedCount) 个产品"
            if !errors.isEmpty {
                return ExcelImportResult(success: true, message: message, errors: errors)
            }
            return ExcelImportResult(success: true, message: message)
            
        } catch {
            return ExcelImportResult(success: false, message: "导入失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Template Generation
    
    func generateCustomerTemplate() -> URL? {
        let header = "姓名,地址,联系电话"
        let example = "张三,北京市朝阳区建国路88号,13800138001"
        let csvContent = "\(header)\n\(example)"
        return saveCSVToFile(csvContent, filename: "customer_template")
    }
    
    func generateProductTemplate() -> URL? {
        let header = "产品名称,SKU,尺寸(用逗号分隔)"
        let example = "经典圆领T恤,PRD-001,XS,S,M,L,XL"
        let csvContent = "\(header)\n\(example)"
        return saveCSVToFile(csvContent, filename: "product_template")
    }
    
    func generateReturnOrderTemplate() -> URL? {
        let header = "客户姓名,客户地址,产品名称,已还数量,剩余数量,还货日期"
        let example = "张三,北京市朝阳区建国路88号,经典圆领T恤,30,20,2025/1/15"
        let csvContent = "\(header)\n\(example)"
        return saveCSVToFile(csvContent, filename: "return_order_template")
    }
    
    // MARK: - Private Helper Functions
    
    private func generateCustomerCSV(_ customers: [Customer]) -> String {
        let header = "姓名,地址,联系电话,创建时间"
        let rows = customers.map { customer in
            let phone = customer.phone.isEmpty ? "" : customer.phone
            let date = customer.createdAt.formatted(date: .abbreviated, time: .omitted)
            return "\(customer.name),\(customer.address),\(phone),\(date)"
        }
        return "\(header)\n\(rows.joined(separator: "\n"))"
    }
    
    private func generateProductCSV(_ products: [Product]) -> String {
        let header = "产品名称,SKU,尺寸,创建时间"
        let rows = products.map { product in
            let sku = product.sku
            let sizes = product.sizeNames.joined(separator: ",")
            let date = product.createdAt.formatted(date: .abbreviated, time: .omitted)
            return "\(product.name),\(sku),\(sizes),\(date)"
        }
        return "\(header)\n\(rows.joined(separator: "\n"))"
    }
    
    private func generateReturnOrdersCSV(_ items: [CustomerOutOfStock]) -> String {
        let header = "客户姓名,客户地址,产品名称,已还货数量,剩余数量,还货日期"
        let rows = items.map { item in
            let customerName = item.customer?.name ?? "未知客户"
            let customerAddress = item.customer?.address ?? "未知地址"
            let productName = item.product?.name ?? "未知产品"
            let deliveredQuantity = "\(item.deliveryQuantity)"
            let remainingQuantity = "\(item.remainingQuantity)"
            let deliveryDate = item.deliveryDate?.formatted(date: .abbreviated, time: .omitted) ?? "未还货"

            return "\(customerName),\(customerAddress),\(productName),\(deliveredQuantity),\(remainingQuantity),\(deliveryDate)"
        }
        return "\(header)\n\(rows.joined(separator: "\n"))"
    }
    
    private func saveCSVToFile(_ content: String, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(filename).csv")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving CSV file: \(error)")
            return nil
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

// MARK: - Supporting Types

struct ExcelImportResult {
    let success: Bool
    let message: String
    let errors: [String]?
    
    init(success: Bool, message: String, errors: [String]? = nil) {
        self.success = success
        self.message = message
        self.errors = errors
    }
} 