import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).parents[1]
CONTENT = ROOT / "src/ios/Views/ContentView.swift"
COMPAT = ROOT / "src/ios/Views/NavigationCompatibility.swift"


class IOS15SettingsNavigationRegressionTests(unittest.TestCase):
    def test_settings_rows_use_compatibility_value_links(self):
        text = CONTENT.read_text(encoding="utf-8")
        settings = text[text.index("private struct SettingsSheet"):]
        self.assertNotRegex(settings, r"(?<!IOS15)NavigationLink\\s*\\{")
        self.assertGreaterEqual(
            len(re.findall(r"IOS15NavigationLink\(value: SettingsDestination\.", settings)),
            15,
        )

    def test_ios15_fallback_has_one_navigation_link_per_path_depth(self):
        text = COMPAT.read_text(encoding="utf-8")
        self.assertIn("IOS15NavigationDestination", text)
        self.assertIn("path.elements[index]", text)
        self.assertIn("path.elements.count > index + 1", text)
        self.assertIn("truncate(to:", text)

    def test_settings_destination_switch_is_the_single_route_mapping(self):
        text = CONTENT.read_text(encoding="utf-8")
        self.assertIn("IOS15NavigationStack", text)
        self.assertIn("settingsDestinationView(for:", text)
        self.assertIn("IOS15NavigationLink(value: SettingsDestination.providers)", text)
        self.assertIn("IOS15NavigationLink(value: SettingsDestination.mcpIntegrations)", text)


if __name__ == "__main__":
    unittest.main()
