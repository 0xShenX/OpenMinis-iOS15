import pathlib
import importlib.util
import plistlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).parents[1]

class PickerPackagingTests(unittest.TestCase):
    def test_signing_entitlements_preserve_capabilities_and_scope_keychain(self):
        path = ROOT / 'scripts/trollstore_entitlements.py'
        self.assertTrue(path.exists(), 'signing entitlements generator is missing')
        spec = importlib.util.spec_from_file_location('entitlements', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for source, bundle in [('src/ios/Minis.entitlements', 'com.openminis.app'),
                               ('src/ios/ShareExtension/ShareExtension.entitlements', 'com.openminis.app.share')]:
            with tempfile.TemporaryDirectory() as directory:
                output = pathlib.Path(directory) / 'signed.plist'
                module.generate(ROOT / source, output, bundle)
                original = plistlib.loads((ROOT / source).read_bytes())
                generated = plistlib.loads(output.read_bytes())
                for key, value in original.items():
                    self.assertEqual(generated[key], value)
                self.assertEqual(generated['application-identifier'], 'TROLLTROLL.' + bundle)
                self.assertEqual(generated['keychain-access-groups'], ['TROLLTROLL.com.openminis.app'])

    def test_existing_signing_identity_is_not_replaced(self):
        spec = importlib.util.spec_from_file_location('entitlements', ROOT / 'scripts/trollstore_entitlements.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original = {'application-identifier': 'EXISTING.app',
                    'com.apple.developer.team-identifier': 'EXISTING',
                    'keychain-access-groups': ['EXISTING.shared']}
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / 'source.plist'
            output = pathlib.Path(directory) / 'output.plist'
            source.write_bytes(plistlib.dumps(original))
            module.generate(source, output, 'com.openminis.app')
            self.assertEqual(plistlib.loads(output.read_bytes()), original)

    def test_selection_is_delivered_before_loading_and_owned_by_chat(self):
        picker = (ROOT / 'src/ios/Views/Chat/ChatInputBar.swift').read_text(encoding='utf-8')
        chat = (ROOT / 'src/ios/Views/Chat/AIChatView.swift').read_text(encoding='utf-8')
        self.assertIn('onSelection?(results)', picker)
        self.assertIn('mediaImportProgress', chat)
        self.assertIn('cancelMediaImport()', chat)
        self.assertIn('vm.markPlaceholderFailed(id: id)', chat)
        self.assertIn('defer { try? FileManager.default.removeItem(at: url) }', chat)

    def test_ci_keeps_diagnostics_and_embeds_entitlements(self):
        workflow = (ROOT / '.github/workflows/ios-trollstore.yml').read_text(encoding='utf-8')
        self.assertIn('runs-on: macos-15', workflow)
        self.assertIn('if: always()', workflow)
        self.assertIn('-resultBundlePath', workflow)
        self.assertIn('-resolvePackageDependencies', workflow)
        self.assertIn('codesign --force --sign - --entitlements', workflow)
        self.assertIn('ShareExtension.entitlements', workflow)

if __name__ == '__main__':
    unittest.main()