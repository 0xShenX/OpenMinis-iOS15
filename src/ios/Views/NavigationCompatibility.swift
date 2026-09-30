import SwiftUI

/// A compact replacement for SwiftUI's iOS 16-only LabeledContent.
/// Keeping this local avoids making settings screens unavailable on iOS 15.
struct IOS15LabeledContent<Label: View, Content: View>: View {
    private let label: Label
    private let content: Content

    init(@ViewBuilder label: () -> Label, @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
    }

    init<V: StringProtocol>(_ title: V, value: String) where Label == Text, Content == Text {
        self.label = Text(title)
        self.content = Text(value)
    }

    init<V: StringProtocol>(_ title: V, @ViewBuilder content: () -> Content) where Label == Text {
        self.label = Text(title)
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            label
            Spacer(minLength: 8)
            content.multilineTextAlignment(.trailing)
        }
    }
}

/// Value navigation that keeps the iOS 16 implementation while providing an
/// iOS 15 NavigationView fallback. The fallback builds one hidden link per
/// path depth so a multi-level route has a real UIKit back stack.
struct IOS15NavigationPath: Equatable {
    fileprivate var elements: [String] = []

    init() {}
    init<S: Sequence>(_ values: S) where S.Element == String {
        elements = Array(values)
    }

    var count: Int { elements.count }
    var isEmpty: Bool { elements.isEmpty }
    mutating func append(_ value: String) { elements.append(value) }
    mutating func append<Value: IOS15NavigationValue>(_ value: Value) {
        elements.append(value.ios15NavigationID)
    }
}

protocol IOS15NavigationValue {
    var ios15NavigationID: String { get }
}

struct IOS15NavigationStack<Root: View>: View {
    @Binding private var path: IOS15NavigationPath
    private let root: Root
    private let destination: (String) -> AnyView

    init(path: Binding<IOS15NavigationPath>, @ViewBuilder root: () -> Root,
         destination: @escaping (String) -> AnyView) {
        _path = path
        self.root = root()
        self.destination = destination
    }

    init(path: Binding<IOS15NavigationPath>, @ViewBuilder root: () -> Root) {
        _path = path
        self.root = root()
        self.destination = { _ in AnyView(EmptyView()) }
    }

    init(@ViewBuilder root: () -> Root) {
        _path = .constant(IOS15NavigationPath())
        self.root = root()
        self.destination = { _ in AnyView(EmptyView()) }
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(path: Binding(
                get: { path.elements },
                set: { path = IOS15NavigationPath($0) }
            )) {
                root.navigationDestination(for: String.self, destination: destination)
            }
        } else {
            IOS15NavigationViewFallback(path: $path, root: root, destination: destination)
        }
    }
}

private struct IOS15NavigationViewFallback<Root: View>: View {
    @Binding var path: IOS15NavigationPath
    let root: Root
    let destination: (String) -> AnyView

    var body: some View {
        NavigationView {
            root.environment(\.ios15NavigationPush, { path.append($0) })
                .background(IOS15NavigationDestination(
                    index: 0, path: $path, destination: destination
                ))
        }
        .navigationViewStyle(.stack)
    }
}

/// A hidden link for one path element. Its destination owns the next hidden
/// link, which makes `[root, A, B]` three UIKit controllers rather than one
/// controller whose content is replaced in place. SwiftUI may evaluate an
/// inactive destination, so the element lookup is guarded at every level.
private struct IOS15NavigationDestination: View {
    let index: Int
    @Binding var path: IOS15NavigationPath
    let destination: (String) -> AnyView

    var body: some View {
        NavigationLink(
            isActive: Binding(
                get: { path.elements.count > index },
                set: { active in
                    if !active { path.truncate(to: index) }
                }
            ),
            destination: {
                if path.elements.count > index {
                    let id = path.elements[index]
                    // A nested link is only active when another route exists.
                    let hasNextRoute = path.elements.count > index + 1
                    destination(id)
                        .environment(\.ios15NavigationPush, { path.append($0) })
                        .background(IOS15NavigationDestination(
                            index: index + 1, path: $path, destination: destination
                        ))
                } else {
                    EmptyView()
                }
            },
            label: { EmptyView() }
        )
        .hidden()
    }
}

private extension IOS15NavigationPath {
    mutating func truncate(to count: Int) {
        elements.removeLast(max(0, elements.count - count))
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct IOS15NavigationLink<Value: Hashable & IOS15NavigationValue, Label: View>: View {
    let value: Value
    @ViewBuilder let label: () -> Label
    @Environment(\.ios15NavigationPush) private var push

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationLink(value: value.ios15NavigationID, label: label)
        } else {
            Button(action: { push?(value.ios15NavigationID) }, label: label)
        }
    }
}

extension String: IOS15NavigationValue {
    var ios15NavigationID: String { self }
}

private struct IOS15NavigationPushKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

private extension EnvironmentValues {
    var ios15NavigationPush: ((String) -> Void)? {
        get { self[IOS15NavigationPushKey.self] }
        set { self[IOS15NavigationPushKey.self] = newValue }
    }
}

enum IOS15ColumnVisibility {
    case automatic
    case all
    case doubleColumn
    case detailOnly
}

enum IOS15PresentationDetent {
    case medium
    case large
    case height(CGFloat)
}

enum IOS15PresentationContentInteraction {
    case resizes
    case scrolls
}

enum IOS15ScrollDismissesKeyboardMode {
    case immediately
    case interactively
    case never
}

struct IOS15NavigationContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
                .navigationViewStyle(.stack)
        }
    }
}

struct IOS15NavigationSplitView<Sidebar: View, Detail: View>: View {
    @Binding var columnVisibility: IOS15ColumnVisibility
    let sidebar: Sidebar
    let detail: Detail

    init(columnVisibility: Binding<IOS15ColumnVisibility>,
         @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        _columnVisibility = columnVisibility
        self.sidebar = sidebar()
        self.detail = detail()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationSplitView(columnVisibility: Binding(
                get: {
                    switch columnVisibility {
                    case .automatic: return NavigationSplitViewVisibility.automatic
                    case .all: return NavigationSplitViewVisibility.all
                    case .doubleColumn: return NavigationSplitViewVisibility.doubleColumn
                    case .detailOnly: return NavigationSplitViewVisibility.detailOnly
                    }
                },
                set: { value in
                    switch value {
                    case .automatic: columnVisibility = .automatic
                    case .all: columnVisibility = .all
                    case .doubleColumn: columnVisibility = .doubleColumn
                    case .detailOnly: columnVisibility = .detailOnly
                    @unknown default: columnVisibility = .automatic
                    }
                }
            )) {
                sidebar
            } detail: {
                detail
            }
        } else {
            NavigationView {
                sidebar
                detail
            }
            .navigationViewStyle(.columns)
        }
    }
}

extension View {
    @ViewBuilder
    func presentationDetentsCompat(_ detents: Set<IOS15PresentationDetent>) -> some View {
        if #available(iOS 16.0, *) {
            presentationDetents(Set(detents.map { detent in
                switch detent {
                case .medium: return PresentationDetent.medium
                case .large: return PresentationDetent.large
                case .height(let value): return PresentationDetent.height(value)
                }
            }))
        } else {
            self
        }
    }

    @ViewBuilder
    func presentationDetentsCompat(_ detents: [IOS15PresentationDetent]) -> some View {
        presentationDetentsCompat(Set(detents))
    }

    @ViewBuilder
    func presentationDragIndicatorCompat(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, *) {
            presentationDragIndicator(visibility)
        } else {
            self
        }
    }

    @ViewBuilder
    func presentationContentInteractionCompat(_ interaction: IOS15PresentationContentInteraction) -> some View {
        if #available(iOS 16.4, *) {
            switch interaction {
            case .resizes: presentationContentInteraction(.resizes)
            case .scrolls: presentationContentInteraction(.scrolls)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func interactiveDismissDisabledCompat(_ isDisabled: Bool = true) -> some View {
        if #available(iOS 15.0, *) {
            interactiveDismissDisabled(isDisabled)
        } else {
            self
        }
    }

    @ViewBuilder
    func safeAreaInsetCompat<Inset: View>(edge: Edge.Set = .bottom, spacing: CGFloat? = nil,
                                           @ViewBuilder content: () -> Inset) -> some View {
        if #available(iOS 15.0, *) {
            safeAreaInset(edge: edge, spacing: spacing, content: content)
        } else {
            self
        }
    }

    @ViewBuilder
    func scrollContentBackgroundCompat(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, *) { scrollContentBackground(visibility) } else { self }
    }

    @ViewBuilder
    func toolbarVisibilityCompat(_ visibility: Visibility, for bar: ToolbarPlacement = .navigationBar) -> some View {
        if #available(iOS 16.0, *) { toolbar(visibility, for: bar) } else { self }
    }

    @ViewBuilder
    func scrollDismissesKeyboardCompat(_ mode: IOS15ScrollDismissesKeyboardMode) -> some View {
        if #available(iOS 16.0, *) {
            switch mode {
            case .immediately: scrollDismissesKeyboard(.immediately)
            case .interactively: scrollDismissesKeyboard(.interactively)
            case .never: scrollDismissesKeyboard(.never)
            }
        } else {
            self
        }
    }
}
