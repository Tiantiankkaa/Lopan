//
//  InsightsExportService.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Export service for Insights data - CSV, PDF, and PNG formats
//

import Foundation
import UIKit
import SwiftUI
import PDFKit

// MARK: - Export Service

/// Service for exporting Insights data to various formats
@MainActor
class InsightsExportService {

    // MARK: - Export Formats

    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "csv"
        case pdf = "pdf"
        case png = "png"

        var id: String { rawValue }

        var displayName: LocalizedStringKey {
            switch self {
            case .csv: return "insights_export_csv"
            case .pdf: return "insights_export_pdf"
            case .png: return "insights_export_png"
            }
        }

        var systemImage: String {
            switch self {
            case .csv: return "tablecells"
            case .pdf: return "doc.text"
            case .png: return "photo"
            }
        }

        var fileExtension: String {
            rawValue
        }

        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .pdf: return "application/pdf"
            case .png: return "image/png"
            }
        }
    }

    // MARK: - Export Errors

    enum ExportError: LocalizedError {
        case dataConversionFailed
        case fileCreationFailed
        case permissionDenied
        case invalidData
        case renderingFailed

        var errorDescription: String? {
            switch self {
            case .dataConversionFailed:
                return NSLocalizedString("insights_export_error_conversion", comment: "")
            case .fileCreationFailed:
                return NSLocalizedString("insights_export_error_file_creation", comment: "")
            case .permissionDenied:
                return NSLocalizedString("insights_export_error_permission", comment: "")
            case .invalidData:
                return NSLocalizedString("insights_export_error_invalid_data", comment: "")
            case .renderingFailed:
                return NSLocalizedString("insights_export_error_rendering", comment: "")
            }
        }
    }

    // MARK: - Export Configuration

    struct ExportConfiguration {
        let title: String
        let subtitle: String?
        let includeChart: Bool
        let includeData: Bool
        let includeSummary: Bool
        let timeRange: TimeRange
        let mode: AnalysisMode

        init(
            title: String,
            subtitle: String? = nil,
            includeChart: Bool = true,
            includeData: Bool = true,
            includeSummary: Bool = true,
            timeRange: TimeRange,
            mode: AnalysisMode
        ) {
            self.title = title
            self.subtitle = subtitle
            self.includeChart = includeChart
            self.includeData = includeData
            self.includeSummary = includeSummary
            self.timeRange = timeRange
            self.mode = mode
        }
    }

    // MARK: - CSV Export

    /// Export bar chart data to CSV format
    func exportToCSV(
        data: [BarChartItem],
        configuration: ExportConfiguration
    ) throws -> URL {
        var csvString = "Category,Value,SubCategory\n"

        for item in data {
            let category = item.category.replacingOccurrences(of: ",", with: ";")
            let subCategory = item.subCategory?.replacingOccurrences(of: ",", with: ";") ?? ""
            csvString += "\(category),\(item.value),\(subCategory)\n"
        }

        guard let csvData = csvString.data(using: .utf8) else {
            throw ExportError.dataConversionFailed
        }

        let fileName = generateFileName(
            prefix: "insights_\(configuration.mode.rawValue)",
            extension: "csv"
        )
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            throw ExportError.fileCreationFailed
        }
    }

    /// Export pie chart data to CSV format
    func exportPieToCSV(
        data: [PieChartSegment],
        configuration: ExportConfiguration
    ) throws -> URL {
        var csvString = "Label,Value,Percentage\n"

        let total = data.reduce(0) { $0 + $1.value }

        for segment in data {
            let label = segment.label.replacingOccurrences(of: ",", with: ";")
            let percentage = total > 0 ? (segment.value / total * 100) : 0
            csvString += "\(label),\(segment.value),\(String(format: "%.2f", percentage))%\n"
        }

        guard let csvData = csvString.data(using: .utf8) else {
            throw ExportError.dataConversionFailed
        }

        let fileName = generateFileName(
            prefix: "insights_\(configuration.mode.rawValue)",
            extension: "csv"
        )
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try csvData.write(to: tempURL, options: .atomic)
        return tempURL
    }

    // MARK: - PDF Export

    /// Export data with optional chart to PDF
    func exportToPDF(
        barData: [BarChartItem]? = nil,
        pieData: [PieChartSegment]? = nil,
        chartImage: UIImage?,
        configuration: ExportConfiguration
    ) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "Lopan Insights",
            kCGPDFContextTitle: configuration.title,
            kCGPDFContextAuthor: "Lopan Production Management"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0  // US Letter width
        let pageHeight = 11 * 72.0  // US Letter height
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 50

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let fileName = generateFileName(
            prefix: "insights_\(configuration.mode.rawValue)_report",
            extension: "pdf"
        )
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()
                var yPosition: CGFloat = margin

                // Title
                yPosition = drawTitle(
                    configuration.title,
                    at: yPosition,
                    in: pageRect,
                    margin: margin
                )

                // Subtitle
                if let subtitle = configuration.subtitle {
                    yPosition = drawSubtitle(
                        subtitle,
                        at: yPosition,
                        in: pageRect,
                        margin: margin
                    )
                }

                // Chart image
                if configuration.includeChart, let image = chartImage {
                    yPosition = drawChartImage(
                        image,
                        at: yPosition,
                        in: pageRect,
                        margin: margin
                    )
                }

                // Data table
                if configuration.includeData {
                    if let barData = barData {
                        yPosition = drawBarDataTable(
                            barData,
                            at: yPosition,
                            in: pageRect,
                            margin: margin
                        )
                    } else if let pieData = pieData {
                        yPosition = drawPieDataTable(
                            pieData,
                            at: yPosition,
                            in: pageRect,
                            margin: margin
                        )
                    }
                }

                // Footer
                drawFooter(in: pageRect, margin: margin)
            }

            return tempURL
        } catch {
            throw ExportError.fileCreationFailed
        }
    }

    // MARK: - PNG Export

    /// Export a SwiftUI view to PNG image
    func exportToPNG<Content: View>(
        view: Content,
        size: CGSize = CGSize(width: 1200, height: 800)
    ) throws -> URL {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0  // High resolution

        guard let uiImage = renderer.uiImage else {
            throw ExportError.renderingFailed
        }

        guard let pngData = uiImage.pngData() else {
            throw ExportError.dataConversionFailed
        }

        let fileName = generateFileName(
            prefix: "insights_chart",
            extension: "png"
        )
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            throw ExportError.fileCreationFailed
        }
    }

    // MARK: - PDF Drawing Helpers

    private func drawTitle(
        _ title: String,
        at yPosition: CGFloat,
        in pageRect: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.label
        ]

        let titleRect = CGRect(
            x: margin,
            y: yPosition,
            width: pageRect.width - 2 * margin,
            height: 40
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)

        return yPosition + 50
    }

    private func drawSubtitle(
        _ subtitle: String,
        at yPosition: CGFloat,
        in pageRect: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let subtitleRect = CGRect(
            x: margin,
            y: yPosition,
            width: pageRect.width - 2 * margin,
            height: 30
        )
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)

        return yPosition + 40
    }

    private func drawChartImage(
        _ image: UIImage,
        at yPosition: CGFloat,
        in pageRect: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        let maxImageHeight: CGFloat = 300
        let imageWidth = pageRect.width - 2 * margin
        let aspectRatio = image.size.height / image.size.width
        let imageHeight = min(imageWidth * aspectRatio, maxImageHeight)

        let imageRect = CGRect(
            x: margin,
            y: yPosition,
            width: imageWidth,
            height: imageHeight
        )
        image.draw(in: imageRect)

        return yPosition + imageHeight + 30
    }

    private func drawBarDataTable(
        _ data: [BarChartItem],
        at yPosition: CGFloat,
        in pageRect: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = yPosition

        // Table header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        "Category\t\tValue\t\tDetails".draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: headerAttributes
        )
        currentY += 25

        // Draw separator line
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.separator.cgColor)
        context?.setLineWidth(1)
        context?.move(to: CGPoint(x: margin, y: currentY))
        context?.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
        context?.strokePath()
        currentY += 15

        // Table rows
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]

        let itemsPerPage = 25
        for item in data.prefix(itemsPerPage) {
            let subCategory = item.subCategory ?? ""
            "\(item.category)\t\t\(Int(item.value))\t\t\(subCategory)".draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: cellAttributes
            )
            currentY += 20

            // Check if we need a new page
            if currentY > pageRect.height - 100 {
                break
            }
        }

        return currentY + 20
    }

    private func drawPieDataTable(
        _ data: [PieChartSegment],
        at yPosition: CGFloat,
        in pageRect: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = yPosition

        let total = data.reduce(0) { $0 + $1.value }

        // Table header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        "Label\t\tValue\t\tPercentage".draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: headerAttributes
        )
        currentY += 25

        // Draw separator
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.separator.cgColor)
        context?.setLineWidth(1)
        context?.move(to: CGPoint(x: margin, y: currentY))
        context?.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
        context?.strokePath()
        currentY += 15

        // Table rows
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]

        for segment in data {
            let percentage = total > 0 ? (segment.value / total * 100) : 0
            "\(segment.label)\t\t\(Int(segment.value))\t\t\(String(format: "%.1f", percentage))%".draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: cellAttributes
            )
            currentY += 20

            if currentY > pageRect.height - 100 {
                break
            }
        }

        return currentY + 20
    }

    private func drawFooter(in pageRect: CGRect, margin: CGFloat) {
        let footerText = "Generated by Lopan Insights • \(Date().formatted(date: .long, time: .shortened))"
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.tertiaryLabel
        ]

        footerText.draw(
            at: CGPoint(x: margin, y: pageRect.height - margin + 10),
            withAttributes: footerAttributes
        )
    }

    // MARK: - Utility

    private func generateFileName(prefix: String, extension fileExtension: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())

        return "\(prefix)_\(dateString).\(fileExtension)"
    }
}

// MARK: - Insights Export Result

struct InsightsExportResult {
    let url: URL
    let format: InsightsExportService.ExportFormat
    let fileSize: Int64

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}