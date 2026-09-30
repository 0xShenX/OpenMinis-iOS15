import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).parents[1]
PROJECT = ROOT / "src/ios/Minis.xcodeproj/project.pbxproj"
WORKFLOW = ROOT / ".github/workflows/ios-trollstore.yml"

class IOS15CompatibilityTests(unittest.TestCase):
    def test_compatibility_layer_does_not_expose_ios164_type(self):
        source = (ROOT / 'src/ios/Views/NavigationCompatibility.swift').read_text(encoding='utf-8')
        self.assertNotIn('_ interaction: PresentationContentInteraction)', source)
        self.assertIn('enum IOS15PresentationContentInteraction', source)

    def test_compatibility_modifiers_cover_spacing_and_toolbar_visibility(self):
        source = (ROOT / 'src/ios/Views/NavigationCompatibility.swift').read_text(encoding='utf-8')
        self.assertRegex(source, r'func safeAreaInsetCompat<[^{]+spacing: CGFloat')
        self.assertIn('func toolbarVisibilityCompat', source)

    def test_content_view_and_app_navigation_use_compatibility_containers(self):
        content = (ROOT / 'src/ios/Views/ContentView.swift').read_text(encoding='utf-8')
        self.assertNotRegex(content, r'(?<!IOS15)NavigationStack\s*\{')
        self.assertNotIn('.navigationDestination(for: SettingsDestination.self)', content)
        self.assertIn('IOS15NavigationStack', content)

    def test_ios16_only_modifiers_are_not_called_unconditionally(self):
        for relative in ('Views/Providers/ProviderInstanceDetailView.swift',
                         'Views/Providers/ModelGroupDetailView.swift'):
            text = (ROOT / 'src/ios' / relative).read_text(encoding='utf-8')
            self.assertNotIn('.scrollDismissesKeyboard(', text)

    def test_app_and_test_targets_deploy_to_ios_15_4(self):
        text = PROJECT.read_text(encoding="utf-8")
        for identifier in ('E51000070', 'E51000071', 'E51000072', 'E51000073',
                           'E5E000070', 'E5E000071', 'BB1000080F700000000000AA',
                           'BB1000090F700000000000AA', 'AA8A56932F6FBB7A00A3E54E',
                           'AA8A56942F6FBB7A00A3E54E'):
            block = re.search(r'\b' + identifier + r' /\* (?:Debug|Release) \*/ = \{(.*?)\n\t\t\};', text, re.S)
            self.assertIsNotNone(block, identifier)
            self.assertTrue('IPHONEOS_DEPLOYMENT_TARGET = 15.4;' in block[1], identifier)

    def test_workflow_is_manual_and_packages_unsigned_payload(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("workflow_dispatch:", text)
        self.assertIn("macos-", text)
        self.assertIn("CODE_SIGNING_ALLOWED=NO", text)
        self.assertIn("Payload", text)
        self.assertIn(".ipa", text)

    def test_newer_os_extensions_remain_available(self):
        text = PROJECT.read_text(encoding="utf-8")
        self.assertTrue('E5H000009 /* AgentWidgetExtension.appex in Embed Foundation Extensions */,' in text)
        self.assertTrue('E5FP00009 /* MinisFileProvider.appex in Embed Foundation Extensions */,' in text)

    def test_rclone_native_slices_deploy_to_ios15(self):
        text = (ROOT / 'deps/build_rclone_ios.sh').read_text(encoding='utf-8')
        self.assertTrue('-miphoneos-version-min=15.4' in text)
        self.assertTrue('-mios-simulator-version-min=15.4' in text)

    def test_chat_uses_availability_dispatch_for_hosting(self):
        source = (ROOT / 'src/ios/Agent/MessageList/CollectionViewMessageListV3.swift').read_text(encoding='utf-8')
        self.assertEqual(len(re.findall(r'let config = MinisHostingConfiguration \{', source)), 4)
        infrastructure = (ROOT / 'src/ios/Agent/MessageList/MessageListInfrastructure.swift').read_text(encoding='utf-8')
        self.assertTrue('struct MinisHostingConfiguration' in infrastructure)
        self.assertTrue('UIHostingController(rootView:' in infrastructure)

    def test_navigation_compatibility_layer_preserves_stack_and_split_routes(self):
        source = (ROOT / 'src/ios/Views/NavigationCompatibility.swift').read_text(encoding='utf-8')
        content = (ROOT / 'src/ios/Views/ContentView.swift').read_text(encoding='utf-8')
        self.assertIn('struct IOS15NavigationStack', source)
        self.assertIn('struct IOS15NavigationSplitView', source)
        self.assertIn('struct IOS15NavigationPath', source)
        self.assertIn('NavigationCompatibility.swift', (ROOT / 'src/ios/Minis.xcodeproj/project.pbxproj').read_text(encoding='utf-8'))
        self.assertIn('IOS15NavigationStack', content)
        self.assertIn('IOS15NavigationSplitView', content)
        self.assertNotRegex(content, r'@State private var (?:navigationPath|navPath) = NavigationPath\(\)')

    def test_ios15_fallback_modifiers_exist_for_newer_swiftui_apis(self):
        source = (ROOT / 'src/ios/Views/NavigationCompatibility.swift').read_text(encoding='utf-8')
        for symbol in ('presentationDetentsCompat', 'presentationDragIndicatorCompat',
                       'presentationContentInteractionCompat', 'interactiveDismissDisabledCompat',
                       'safeAreaInsetCompat', 'scrollContentBackgroundCompat'):
            self.assertIn(symbol, source)

    def test_newer_frameworks_have_ios15_runtime_fallbacks(self):
        app = (ROOT / 'src/ios/MinisApp.swift').read_text(encoding='utf-8')
        self.assertIn('if #available(iOS 16.0, *) {', app)
        self.assertIn('[FileProvider] unavailable on iOS 15', app)
        self.assertIn('@available(iOS 16.0, *)\n    private static func registerFileProviderDomain', app)
        settings = (ROOT / 'src/ios/Views/Settings/SharedFoldersSettingsView.swift').read_text(encoding='utf-8')
        self.assertIn('guard #available(iOS 16.0, *) else { return }', settings)

        weather = (ROOT / 'src/ios/NativeOffloads/WeatherOffload.m').read_text(encoding='utf-8')
        self.assertIn('WeatherKit requires iOS 16 or later', weather)
        bridge = (ROOT / 'src/ios/NativeOffloads/WeatherOffloadBridge.swift').read_text(encoding='utf-8')
        self.assertIn('@available(iOS 16.0, *)\n@objc public class WeatherOffloadBridge', bridge)

    def test_app_intents_are_not_exposed_to_ios15(self):
        intents = ROOT / 'src/ios/Agent/Intents'
        for path in intents.glob('*.swift'):
            text = path.read_text(encoding='utf-8')
            if 'import AppIntents' not in text or 'RetryRunIntent.swift' == path.name or 'UserMessageEntity.swift' == path.name:
                continue
            self.assertRegex(text, r'@available\(iOS 16\.0, \*\)\n(?:enum|struct) ', path.name)

    def test_dependency_audit_records_binary_and_manifest_limitations(self):
        audit = (ROOT / 'docs/IOS15_COMPATIBILITY.md').read_text(encoding='utf-8')
        self.assertIn('dependency minimum audit', audit.lower())
        self.assertIn('RealTimeCutVADLibrary', audit)

    def test_activitykit_has_hardened_runtime_probe_and_extension_floor(self):
        manager = (ROOT / 'src/ios/Agent/Background/AgentLiveActivityManager.swift').read_text(encoding='utf-8')
        self.assertIn('guard #available(iOS 16.2, *) else { return false }', manager)
        self.assertIn('dlopen("/System/Library/Frameworks/ActivityKit.framework/ActivityKit"', manager)
        self.assertIn('Activity descriptor symbol missing', manager)
        widget = (ROOT / 'src/ios/AgentWidget/AgentWidgetBundle.swift').read_text(encoding='utf-8')
        self.assertIn('iOSApplicationExtension 16.2', widget)

    def test_media_picker_uses_phpicker_and_not_ios16_photos_picker(self):
        chat = (ROOT / 'src/ios/Views/Chat/AIChatView.swift').read_text(encoding='utf-8')
        input_bar = (ROOT / 'src/ios/Views/Chat/ChatInputBar.swift').read_text(encoding='utf-8')
        soul = (ROOT / 'src/ios/Views/Settings/SoulSettingsView.swift').read_text(encoding='utf-8')
        self.assertIn('PHPickerViewController', input_bar)
        self.assertIn('IOS15MediaPicker', input_bar)
        self.assertNotIn('PhotosPickerItem', chat)
        self.assertNotIn('.photosPicker(', chat)
        self.assertNotIn('PhotosPickerItem', soul)
        self.assertNotIn('.photosPicker(', soul)

    def test_flow_layout_has_ios15_grid_fallback(self):
        source = (ROOT / 'src/ios/Views/Chat/ChatInputBar.swift').read_text(encoding='utf-8')
        self.assertNotIn('private struct FlowLayout: Layout', source)
        self.assertIn('LazyVGrid', source)

if __name__ == "__main__":
    unittest.main()
