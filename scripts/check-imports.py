#!/usr/bin/env python3
"""Every `import CareX` must be declared as a dependency of the target doing the importing.

An undeclared import can still link under implicit module builds, because the module it wants is
already sitting in the same build directory. Under explicit module builds the scan refuses it with
"Unable to resolve module dependency", which is how CareData importing CareReminders reached a Mac
before anyone noticed. This reads the manifest and the sources and fails when the two disagree, so
the answer arrives in CI rather than on someone's device.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "Packages" / "Package.swift"
SOURCES = ROOT / "Packages" / "Sources"
APP = ROOT / "Care"

TARGET = re.compile(
    r'\.(?:target|testTarget)\(\s*name:\s*"(?P<name>\w+)"'
    r'(?P<body>.*?)(?=\n\s*\.(?:target|testTarget)\(|\n\s*\]\s*$)',
    re.S | re.M,
)
DEPS = re.compile(r'dependencies:\s*\[(?P<list>[^\]]*)\]', re.S)
NAMES = re.compile(r'"(\w+)"')
IMPORT = re.compile(r'^\s*(?:@\w+\s+)?import\s+(\w+)', re.M)


def declared_dependencies() -> dict[str, set[str]]:
    text = MANIFEST.read_text()
    out: dict[str, set[str]] = {}
    for match in TARGET.finditer(text):
        deps = DEPS.search(match.group("body"))
        out[match.group("name")] = set(NAMES.findall(deps.group("list"))) if deps else set()
    return out


def imports_in(directory: Path, modules: set[str]) -> dict[str, set[Path]]:
    found: dict[str, set[Path]] = {}
    for swift in sorted(directory.rglob("*.swift")):
        for module in set(IMPORT.findall(swift.read_text())) & modules:
            found.setdefault(module, set()).add(swift.relative_to(ROOT))
    return found


def main() -> int:
    declared = declared_dependencies()
    modules = {name for name in declared if (SOURCES / name).is_dir()}
    if not modules:
        print("check-imports: found no targets in the manifest", file=sys.stderr)
        return 1

    problems: list[str] = []
    for target, deps in sorted(declared.items()):
        directory = SOURCES / target
        if not directory.is_dir():
            continue
        for module, files in sorted(imports_in(directory, modules - {target}).items()):
            if module not in deps:
                where = ", ".join(str(f) for f in sorted(files))
                problems.append(f"  {target} imports {module} but does not depend on it  ({where})")

    # The app target links package products rather than declaring dependencies in the manifest, so it
    # is checked against the project's own product list instead.
    pbxproj = (ROOT / "Care.xcodeproj" / "project.pbxproj").read_text()
    linked = set(re.findall(r"productName = (\w+);", pbxproj))
    for module, files in sorted(imports_in(APP, modules).items()):
        if module not in linked:
            where = ", ".join(str(f) for f in sorted(files))
            problems.append(f"  the app imports {module} but does not link it  ({where})")

    if problems:
        print("Undeclared module dependencies:", file=sys.stderr)
        print("\n".join(problems), file=sys.stderr)
        return 1

    print(f"check-imports: {len(modules)} modules, every import declared")
    return 0


if __name__ == "__main__":
    sys.exit(main())
