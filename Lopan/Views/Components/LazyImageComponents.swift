//
//  LazyImageComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Lazy Image Loader
@MainActor
class LazyImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var imageData: Data?
    private let cache = ImageCache.shared
    
    init() {}
    
    func loadImage(from data: Data?, cacheKey: String? = nil) {
        guard let data = data else {
            self.image = nil
            return
        }
        
        // Check cache first
        if let cacheKey = cacheKey, let cachedImage = cache.getImage(forKey: cacheKey) {
            self.image = cachedImage
            return
        }
        
        // Check if this is the same data we already loaded
        if let currentData = imageData, currentData == data {
            return
        }
        
        imageData = data
        isLoading = true
        error = nil
        
        Task {
            do {
                let loadedImage = try await loadImageAsync(from: data)
                
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                    
                    // Cache the image if we have a key
                    if let cacheKey = cacheKey {
                        self.cache.setImage(loadedImage, forKey: cacheKey)
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadImageAsync(from data: Data) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ImageLoadError.invalidData)
                }
            }
        }
    }
}

enum ImageLoadError: Error, LocalizedError {
    case invalidData
    case loadingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "图片数据无效"
        case .loadingFailed:
            return "图片加载失败"
        }
    }
}

// MARK: - Image Cache
class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let maxMemoryUsage: Int = 50 * 1024 * 1024 // 50MB
    
    private init() {
        cache.totalCostLimit = maxMemoryUsage
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    func getImage(forKey key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = imageMemorySize(image)
        cache.setObject(image, forKey: NSString(string: key), cost: cost)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    private func imageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

// MARK: - Lazy Image View
struct LazyImageView: View {
    let imageData: Data?
    let placeholder: String
    let width: CGFloat?
    let height: CGFloat?
    let contentMode: ContentMode
    let cornerRadius: CGFloat
    let cacheKey: String?
    
    @StateObject private var loader = LazyImageLoader()
    
    init(
        imageData: Data?,
        placeholder: String = "photo",
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        contentMode: ContentMode = .fit,
        cornerRadius: CGFloat = 8,
        cacheKey: String? = nil
    ) {
        self.imageData = imageData
        self.placeholder = placeholder
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.cacheKey = cacheKey
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .accessibilityLabel("产品图片")
            } else if loader.isLoading {
                LoadingPlaceholder()
            } else {
                ErrorPlaceholder(placeholder: placeholder)
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(cornerRadius)
        .onAppear {
            loader.loadImage(from: imageData, cacheKey: cacheKey)
        }
        .onChange(of: imageData) { _, newData in
            loader.loadImage(from: newData, cacheKey: cacheKey)
        }
    }
}

// MARK: - Loading Placeholder
struct LoadingPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(LopanColors.secondary.opacity(0.3))
            .overlay(
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("正在加载图片")
            )
    }
}

// MARK: - Error Placeholder
struct ErrorPlaceholder: View {
    let placeholder: String
    
    var body: some View {
        Rectangle()
            .fill(LopanColors.secondary.opacity(0.2))
            .overlay(
                Image(systemName: placeholder)
                    .font(.system(size: 24))
                    .foregroundColor(LopanColors.secondary)
                    .accessibilityLabel("图片占位符")
            )
    }
}

// MARK: - Optimized Product Image Row
struct OptimizedProductImageRow: View {
    let product: Product
    let imageSize: CGFloat
    let showDetails: Bool
    
    init(
        product: Product,
        imageSize: CGFloat = 60,
        showDetails: Bool = true
    ) {
        self.product = product
        self.imageSize = imageSize
        self.showDetails = showDetails
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Lazy loaded product image
            LazyImageView(
                imageData: product.imageData,
                placeholder: "cube.box",
                width: imageSize,
                height: imageSize,
                contentMode: .fill,
                cornerRadius: 8,
                cacheKey: "product_\(product.id)"
            )
            
            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text("SKU: \(product.sku)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if !product.sizeNames.isEmpty {
                        Text("尺寸: \(product.sizeNames.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.name)产品")
        .accessibilityValue("SKU: \(product.sku)，尺寸: \(product.sizeNames.joined(separator: ", "))")
    }
}

// MARK: - Lazy Grid Image View
struct LazyGridImageView: View {
    let products: [Product]
    let columns: Int
    let spacing: CGFloat
    let imageSize: CGFloat
    let onProductTap: ((Product) -> Void)?
    
    init(
        products: [Product],
        columns: Int = 2,
        spacing: CGFloat = 16,
        imageSize: CGFloat = 120,
        onProductTap: ((Product) -> Void)? = nil
    ) {
        self.products = products
        self.columns = columns
        self.spacing = spacing
        self.imageSize = imageSize
        self.onProductTap = onProductTap
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(products) { product in
                Button(action: {
                    onProductTap?(product)
                }) {
                    VStack(spacing: 8) {
                        LazyImageView(
                            imageData: product.imageData,
                            placeholder: "cube.box",
                            width: imageSize,
                            height: imageSize,
                            contentMode: .fill,
                            cornerRadius: 12,
                            cacheKey: "grid_product_\(product.id)"
                        )
                        
                        Text(product.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(product.name)产品")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding()
    }
}

// MARK: - Memory Optimized Image Picker
struct MemoryOptimizedImagePicker: View {
    @Binding var imageData: Data?
    let maxImageSize: CGFloat
    let compressionQuality: CGFloat
    
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    
    init(
        imageData: Binding<Data?>,
        maxImageSize: CGFloat = 800,
        compressionQuality: CGFloat = 0.8
    ) {
        self._imageData = imageData
        self.maxImageSize = maxImageSize
        self.compressionQuality = compressionQuality
    }
    
    var body: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            Group {
                if let data = imageData {
                    LazyImageView(
                        imageData: data,
                        width: 100,
                        height: 100,
                        contentMode: .fill,
                        cornerRadius: 8
                    )
                } else {
                    Rectangle()
                        .fill(LopanColors.secondary.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            VStack {
                                Image(systemName: "plus")
                                    .font(.title2)
                                Text("添加图片")
                                    .font(.caption)
                            }
                            .foregroundColor(LopanColors.secondary)
                        )
                }
            }
        }
        .accessibilityLabel(imageData != nil ? "更改图片" : "添加图片")
        .confirmationDialog("选择图片", isPresented: $showingActionSheet) {
            Button("相机") {
                // Implement camera picker
            }
            Button("相册") {
                showingImagePicker = true
            }
            if imageData != nil {
                Button("删除图片", role: .destructive) {
                    imageData = nil
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView { selectedImage in
                imageData = compressImage(selectedImage)
            }
        }
    }
    
    private func compressImage(_ image: UIImage) -> Data? {
        // Resize image to max size
        let resized = resizeImage(image, maxSize: maxImageSize)
        
        // Compress to JPEG
        return resized.jpegData(compressionQuality: compressionQuality)
    }
    
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height)
        
        if scale >= 1 {
            return image
        }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}

// MARK: - Image Picker Coordinator
struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Cached Async Image
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder
    
    @StateObject private var loader = ImageURLLoader()
    
    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
            } else if loader.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.loadImage(from: url)
        }
        .onChange(of: url) { _, newURL in
            loader.loadImage(from: newURL)
        }
    }
}

// Image URL Loader for async loading
@MainActor
class ImageURLLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private let cache = ImageCache.shared
    
    func loadImage(from url: URL?) {
        guard let url = url else {
            self.image = nil
            return
        }
        
        let cacheKey = url.absoluteString
        
        // Check cache first
        if let cachedImage = cache.getImage(forKey: cacheKey) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let loadedImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                        self.isLoading = false
                        self.cache.setImage(loadedImage, forKey: cacheKey)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}