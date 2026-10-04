//
//  iOS15Compatibility.swift
//  Minis - iOS 15 Compatibility Layer
//
//  Created for iOS 15.4.1 support
//

import SwiftUI

// MARK: - NavigationStack → NavigationView backport

@available(iOS, deprecated: 16.0, message: "Use NavigationStack on iOS 16+")
struct NavigationStackCompat<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
    }
}

// MARK: - .fontWeight() backport

extension View {
    @ViewBuilder
    func fontWeightCompat(_ weight: Font.Weight) -> some View {
        if #available(iOS 16.0, *) {
            self.fontWeight(weight)
        } else {
            self.font(.system(size: 17, weight: weight))
        }
    }
}

// MARK: - .scrollContentBackground() backport

extension View {
    @ViewBuilder
    func scrollContentBackgroundCompat(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(visibility)
        } else {
            // iOS 15: use UIKit appearance
            self.onAppear {
                UITableView.appearance().backgroundColor = .clear
                UITableView.appearance().backgroundView = nil
            }
        }
    }
}

// MARK: - .scrollDismissesKeyboard() backport

extension View {
    @ViewBuilder
    func scrollDismissesKeyboardCompat(_ mode: ScrollDismissesKeyboardMode) -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(mode)
        } else {
            // iOS 15: use gesture
            self.onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

// MARK: - .presentationDetents() backport

extension View {
    @ViewBuilder
    func presentationDetentsCompat(_ detents: Set<PresentationDetent>) -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents(detents)
        } else {
            // iOS 15: fallback to full screen
            self
        }
    }
    
    @ViewBuilder
    func presentationDetentsCompat(_ detents: Set<PresentationDetent>, selection: Binding<PresentationDetent>) -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents(detents, selection: selection)
        } else {
            self
        }
    }
}

// MARK: - .task {} backport

extension View {
    @ViewBuilder
    func taskCompat(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.task(priority: priority, action)
        } else {
            self.onAppear {
                Task(priority: priority) {
                    await action()
                }
            }
        }
    }
}

// MARK: - .refreshable {} backport

extension View {
    @ViewBuilder
    func refreshableCompat(_ action: @escaping @Sendable () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.refreshable(action: action)
        } else {
            self
        }
    }
}

// MARK: - .searchable() backport

extension View {
    @ViewBuilder
    func searchableCompat(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil) -> some View {
        if #available(iOS 15.0, *) {
            self.searchable(text: text, placement: placement, prompt: prompt)
        } else {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search", text: text)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                self
            }
        }
    }
}

// MARK: - PhotosPicker backport

@available(iOS 15.0, *)
struct PhotosPickerCompat<SelectionValue: Transferable, Content: View>: View {
    @Binding var selection: SelectionValue?
    let matching: PHPickerFilter?
    let content: Content
    
    @State private var isPresented = false
    
    init(
        selection: Binding<SelectionValue?>,
        matching: PHPickerFilter? = nil,
        @ViewBuilder label: () -> Content
    ) {
        self._selection = selection
        self.matching = matching
        self.content = label()
    }
    
    var body: some View {
        Button {
            isPresented = true
        } label: {
            content
        }
        .sheet(isPresented: $isPresented) {
            if #available(iOS 16.0, *) {
                PhotosPicker(selection: $selection, matching: matching) {
                    content
                }
            } else {
                LegacyPHPicker(selection: $selection, filter: matching)
            }
        }
    }
}

@available(iOS 15.0, *)
struct LegacyPHPicker<T: Transferable>: UIViewControllerRepresentable {
    @Binding var selection: T?
    let filter: PHPickerFilter?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = filter ?? .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LegacyPHPicker
        
        init(_ parent: LegacyPHPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    // Handle image loading
                }
            }
        }
    }
}

// MARK: - AsyncImage backport

@available(iOS 15.0, *)
struct AsyncImageCompat<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            AsyncImage(url: url) { phase in
                content(phase)
            }
        } else {
            content(phase)
                .onAppear {
                    loadImage()
                }
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            phase = .empty
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                phase = .failure(error)
            } else if let data = data, let image = UIImage(data: data) {
                phase = .success(Image(uiImage: image))
            }
        }.resume()
    }
}

import PhotosUI
