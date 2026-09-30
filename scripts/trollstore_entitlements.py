"""Preserve declared capabilities and add explicit TrollStore-local identity.

This is not a provisioning profile or a CoreTrust bypass. TROLLTROLL follows
TrollStore's fallback identity; keychain access is scoped to this app family.
"""
import argparse
import pathlib
import plistlib


def generate(source, output, bundle_identifier):
    entitlements = plistlib.loads(pathlib.Path(source).read_bytes())
    entitlements.setdefault('application-identifier', 'TROLLTROLL.' + bundle_identifier)
    entitlements.setdefault('com.apple.developer.team-identifier', 'TROLLTROLL')
    entitlements.setdefault('keychain-access-groups', ['TROLLTROLL.com.openminis.app'])
    pathlib.Path(output).write_bytes(plistlib.dumps(entitlements))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('output')
    parser.add_argument('bundle_identifier')
    args = parser.parse_args()
    generate(args.source, args.output, args.bundle_identifier)