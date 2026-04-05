#!/usr/bin/env python3
"""Generate ButterRun.xcodeproj/project.pbxproj and scheme files."""

import hashlib
import os

BASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ButterRun")
APP_SRC = os.path.join(BASE_DIR, "ButterRun")
TEST_SRC = os.path.join(BASE_DIR, "ButterRunTests")
UITEST_SRC = os.path.join(BASE_DIR, "ButterRunUITests")
PROJ_DIR = os.path.join(BASE_DIR, "ButterRun.xcodeproj")
SCHEME_DIR = os.path.join(PROJ_DIR, "xcshareddata", "xcschemes")


def make_uuid(seed: str) -> str:
    """Generate a deterministic 24-char uppercase hex UUID from a seed string."""
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def collect_swift_files(root_dir: str) -> list[str]:
    """Return sorted list of .swift file paths relative to root_dir."""
    results = []
    for dirpath, _, filenames in os.walk(root_dir):
        for f in filenames:
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(dirpath, f), root_dir)
                results.append(rel)
    results.sort()
    return results


# ---------------------------------------------------------------------------
# Collect files
# ---------------------------------------------------------------------------
app_swift = collect_swift_files(APP_SRC)
test_swift = collect_swift_files(TEST_SRC)
uitest_swift = collect_swift_files(UITEST_SRC)

# Resource / config files (relative to APP_SRC)
app_resources = ["Assets.xcassets", "PrivacyInfo.xcprivacy"]
app_config_files = ["Info.plist", "ButterRun.entitlements"]

# ---------------------------------------------------------------------------
# UUID generation helpers
# ---------------------------------------------------------------------------

def file_ref_uuid(path: str) -> str:
    return make_uuid(f"fileref:{path}")

def build_file_uuid(path: str, target: str) -> str:
    return make_uuid(f"buildfile:{target}:{path}")

def group_uuid(path: str) -> str:
    return make_uuid(f"group:{path}")

# Fixed UUIDs for structural objects
PROJECT_UUID = make_uuid("project:ButterRun")
ROOT_GROUP_UUID = make_uuid("group:root")
PRODUCTS_GROUP_UUID = make_uuid("group:Products")
APP_GROUP_UUID = make_uuid("group:ButterRun")
TEST_GROUP_UUID = make_uuid("group:ButterRunTests")
UITEST_GROUP_UUID = make_uuid("group:ButterRunUITests")

APP_TARGET_UUID = make_uuid("target:ButterRun")
TEST_TARGET_UUID = make_uuid("target:ButterRunTests")
UITEST_TARGET_UUID = make_uuid("target:ButterRunUITests")

APP_PRODUCT_UUID = make_uuid("product:ButterRun.app")
TEST_PRODUCT_UUID = make_uuid("product:ButterRunTests.xctest")
UITEST_PRODUCT_UUID = make_uuid("product:ButterRunUITests.xctest")

APP_SOURCES_PHASE_UUID = make_uuid("sources:ButterRun")
APP_FRAMEWORKS_PHASE_UUID = make_uuid("frameworks:ButterRun")
APP_RESOURCES_PHASE_UUID = make_uuid("resources:ButterRun")

TEST_SOURCES_PHASE_UUID = make_uuid("sources:ButterRunTests")
TEST_FRAMEWORKS_PHASE_UUID = make_uuid("frameworks:ButterRunTests")

UITEST_SOURCES_PHASE_UUID = make_uuid("sources:ButterRunUITests")
UITEST_FRAMEWORKS_PHASE_UUID = make_uuid("frameworks:ButterRunUITests")

# Config list UUIDs
PROJECT_CONFIG_LIST_UUID = make_uuid("configlist:project")
APP_CONFIG_LIST_UUID = make_uuid("configlist:ButterRun")
TEST_CONFIG_LIST_UUID = make_uuid("configlist:ButterRunTests")
UITEST_CONFIG_LIST_UUID = make_uuid("configlist:ButterRunUITests")

# Build configuration UUIDs
PROJECT_DEBUG_UUID = make_uuid("config:project:Debug")
PROJECT_RELEASE_UUID = make_uuid("config:project:Release")
APP_DEBUG_UUID = make_uuid("config:ButterRun:Debug")
APP_RELEASE_UUID = make_uuid("config:ButterRun:Release")
TEST_DEBUG_UUID = make_uuid("config:ButterRunTests:Debug")
TEST_RELEASE_UUID = make_uuid("config:ButterRunTests:Release")
UITEST_DEBUG_UUID = make_uuid("config:ButterRunUITests:Debug")
UITEST_RELEASE_UUID = make_uuid("config:ButterRunUITests:Release")

# xcconfig file reference
XCCONFIG_FILE_UUID = make_uuid("fileref:ButterRun.xcconfig")

# Container item proxy / target dependency UUIDs
TEST_PROXY_UUID = make_uuid("proxy:ButterRunTests")
UITEST_PROXY_UUID = make_uuid("proxy:ButterRunUITests")
TEST_DEP_UUID = make_uuid("dep:ButterRunTests")
UITEST_DEP_UUID = make_uuid("dep:ButterRunUITests")


# ---------------------------------------------------------------------------
# Build directory tree for groups
# ---------------------------------------------------------------------------
def build_dir_tree(file_list: list[str]) -> dict:
    """Build a nested dict representing directory structure. Leaves are file names."""
    tree: dict = {}
    for fp in file_list:
        parts = fp.split(os.sep)
        node = tree
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node[parts[-1]] = None  # leaf
    return tree


def emit_group(name: str, group_id: str, children_lines: list[str], path: str | None = None, source_tree: str = '"<group>"') -> str:
    children_str = "\n".join(f"\t\t\t\t{c}," for c in children_lines)
    path_line = f'\t\t\tpath = "{path}";\n' if path and (" " in path) else (f"\t\t\tpath = {path};\n" if path else "")
    name_line = f'\t\t\tname = "{name}";\n' if name and (" " in name) else ""
    return (
        f"\t\t{group_id} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"{children_str}\n"
        f"\t\t\t);\n"
        f"{name_line}"
        f"{path_line}"
        f"\t\t\tsourceTree = {source_tree};\n"
        f"\t\t}};\n"
    )


# ---------------------------------------------------------------------------
# Generate groups recursively for a target's source tree
# ---------------------------------------------------------------------------
all_groups: list[str] = []

def generate_groups_recursive(tree: dict, prefix: str, group_prefix: str) -> list[str]:
    """Generate PBXGroup entries. Returns list of child UUIDs for the parent group."""
    child_uuids = []
    # Sort: directories first, then files
    dirs = sorted(k for k, v in tree.items() if v is not None)
    files = sorted(k for k, v in tree.items() if v is None)

    for d in dirs:
        sub_path = f"{prefix}/{d}" if prefix else d
        gid = group_uuid(f"{group_prefix}:{sub_path}")
        sub_children = generate_groups_recursive(tree[d], sub_path, group_prefix)
        all_groups.append(emit_group(d, gid, sub_children, path=d))
        child_uuids.append(f"{gid} /* {d} */")

    for f in files:
        file_path = f"{prefix}/{f}" if prefix else f
        fid = file_ref_uuid(f"{group_prefix}:{file_path}")
        child_uuids.append(f"{fid} /* {f} */")

    return child_uuids


# ---------------------------------------------------------------------------
# Build PBXFileReference entries
# ---------------------------------------------------------------------------
file_refs: list[str] = []

def add_file_ref(uuid: str, name: str, file_type: str, path: str, source_tree: str = '"<group>"', explicit: bool = False):
    if explicit:
        file_refs.append(
            f'\t\t{uuid} /* {name} */ = {{isa = PBXFileReference; explicitFileType = {file_type}; includeInIndex = 0; path = {name}; sourceTree = {source_tree}; }};'
        )
    else:
        path_val = f'"{path}"' if " " in path else path
        file_refs.append(
            f'\t\t{uuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {path_val}; sourceTree = {source_tree}; }};'
        )


# App swift files
for sf in app_swift:
    fname = os.path.basename(sf)
    fid = file_ref_uuid(f"ButterRun:{sf}")
    add_file_ref(fid, fname, "sourcecode.swift", fname)

# App resources
for rf in app_resources:
    fid = file_ref_uuid(f"ButterRun:{rf}")
    ft = "folder.assetcatalog" if rf.endswith(".xcassets") else "text.xml"
    add_file_ref(fid, rf, ft, rf)

# App config files
for cf in app_config_files:
    fid = file_ref_uuid(f"ButterRun:{cf}")
    if cf.endswith(".plist"):
        ft = "text.plist.xml"
    else:
        ft = "text.plist.entitlements"
    add_file_ref(fid, cf, ft, cf)

# xcconfig file (lives next to .xcodeproj, one level up from ButterRun/)
# Check if xcconfig exists; if not, check for template
xcconfig_path = os.path.join(BASE_DIR, "ButterRun.xcconfig")
xcconfig_template_path = os.path.join(BASE_DIR, "ButterRun.xcconfig.template")
if os.path.exists(xcconfig_path) or os.path.exists(xcconfig_template_path):
    add_file_ref(XCCONFIG_FILE_UUID, "ButterRun.xcconfig", "text.xcconfig", "ButterRun.xcconfig")

# Test swift files
for sf in test_swift:
    fname = os.path.basename(sf)
    fid = file_ref_uuid(f"ButterRunTests:{sf}")
    add_file_ref(fid, fname, "sourcecode.swift", fname)

# UI Test swift files
for sf in uitest_swift:
    fname = os.path.basename(sf)
    fid = file_ref_uuid(f"ButterRunUITests:{sf}")
    add_file_ref(fid, fname, "sourcecode.swift", fname)

# Product references
add_file_ref(APP_PRODUCT_UUID, "ButterRun.app", "wrapper.application", "ButterRun.app", "BUILT_PRODUCTS_DIR", explicit=True)
add_file_ref(TEST_PRODUCT_UUID, "ButterRunTests.xctest", "wrapper.cfbundle", "ButterRunTests.xctest", "BUILT_PRODUCTS_DIR", explicit=True)
add_file_ref(UITEST_PRODUCT_UUID, "ButterRunUITests.xctest", "wrapper.cfbundle", "ButterRunUITests.xctest", "BUILT_PRODUCTS_DIR", explicit=True)

# ---------------------------------------------------------------------------
# Build PBXBuildFile entries
# ---------------------------------------------------------------------------
build_files: list[str] = []

# App sources
for sf in app_swift:
    fname = os.path.basename(sf)
    bf_uuid = build_file_uuid(sf, "ButterRun")
    fr_uuid = file_ref_uuid(f"ButterRun:{sf}")
    build_files.append(f"\t\t{bf_uuid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_uuid} /* {fname} */; }};")

# App resources
for rf in app_resources:
    bf_uuid = build_file_uuid(rf, "ButterRun:resources")
    fr_uuid = file_ref_uuid(f"ButterRun:{rf}")
    build_files.append(f"\t\t{bf_uuid} /* {rf} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr_uuid} /* {rf} */; }};")

# Test sources
for sf in test_swift:
    fname = os.path.basename(sf)
    bf_uuid = build_file_uuid(sf, "ButterRunTests")
    fr_uuid = file_ref_uuid(f"ButterRunTests:{sf}")
    build_files.append(f"\t\t{bf_uuid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_uuid} /* {fname} */; }};")

# UI Test sources
for sf in uitest_swift:
    fname = os.path.basename(sf)
    bf_uuid = build_file_uuid(sf, "ButterRunUITests")
    fr_uuid = file_ref_uuid(f"ButterRunUITests:{sf}")
    build_files.append(f"\t\t{bf_uuid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_uuid} /* {fname} */; }};")

# ---------------------------------------------------------------------------
# Build PBXGroup entries
# ---------------------------------------------------------------------------

# App group
app_tree = build_dir_tree(app_swift)
app_children = generate_groups_recursive(app_tree, "", "ButterRun")
# Add resources and config files to app group children
for rf in app_resources:
    app_children.append(f'{file_ref_uuid(f"ButterRun:{rf}")} /* {rf} */')
for cf in app_config_files:
    app_children.append(f'{file_ref_uuid(f"ButterRun:{cf}")} /* {cf} */')

all_groups.append(emit_group("ButterRun", APP_GROUP_UUID, app_children, path="ButterRun"))

# Test group
test_tree = build_dir_tree(test_swift)
test_children = generate_groups_recursive(test_tree, "", "ButterRunTests")
all_groups.append(emit_group("ButterRunTests", TEST_GROUP_UUID, test_children, path="ButterRunTests"))

# UI Test group
uitest_tree = build_dir_tree(uitest_swift)
uitest_children = generate_groups_recursive(uitest_tree, "", "ButterRunUITests")
all_groups.append(emit_group("ButterRunUITests", UITEST_GROUP_UUID, uitest_children, path="ButterRunUITests"))

# Products group
products_children = [
    f"{APP_PRODUCT_UUID} /* ButterRun.app */",
    f"{TEST_PRODUCT_UUID} /* ButterRunTests.xctest */",
    f"{UITEST_PRODUCT_UUID} /* ButterRunUITests.xctest */",
]
all_groups.append(emit_group("Products", PRODUCTS_GROUP_UUID, products_children, path=None))

# Root group
root_children = [
    f"{APP_GROUP_UUID} /* ButterRun */",
    f"{TEST_GROUP_UUID} /* ButterRunTests */",
    f"{UITEST_GROUP_UUID} /* ButterRunUITests */",
    f"{PRODUCTS_GROUP_UUID} /* Products */",
]
# Add xcconfig to root group if it exists
if os.path.exists(xcconfig_path) or os.path.exists(xcconfig_template_path):
    root_children.insert(0, f"{XCCONFIG_FILE_UUID} /* ButterRun.xcconfig */")
root_group = (
    f"\t\t{ROOT_GROUP_UUID} = {{\n"
    f"\t\t\tisa = PBXGroup;\n"
    f"\t\t\tchildren = (\n"
    + "\n".join(f"\t\t\t\t{c}," for c in root_children) + "\n"
    f"\t\t\t);\n"
    f'\t\t\tsourceTree = "<group>";\n'
    f"\t\t}};\n"
)
all_groups.append(root_group)

# ---------------------------------------------------------------------------
# Build phases
# ---------------------------------------------------------------------------

def sources_phase(uuid: str, files: list[str], target: str) -> str:
    file_lines = []
    for sf in files:
        fname = os.path.basename(sf)
        bf_uuid = build_file_uuid(sf, target)
        file_lines.append(f"\t\t\t\t{bf_uuid} /* {fname} in Sources */,")
    return (
        f"\t\t{uuid} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        + "\n".join(file_lines) + "\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )

def frameworks_phase(uuid: str) -> str:
    return (
        f"\t\t{uuid} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )

def resources_phase(uuid: str, resources: list[str]) -> str:
    file_lines = []
    for rf in resources:
        bf_uuid = build_file_uuid(rf, "ButterRun:resources")
        file_lines.append(f"\t\t\t\t{bf_uuid} /* {rf} in Resources */,")
    return (
        f"\t\t{uuid} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        + "\n".join(file_lines) + "\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )

# ---------------------------------------------------------------------------
# Build configurations
# ---------------------------------------------------------------------------

def build_config(uuid: str, name: str, settings: dict, base_config_ref: str | None = None) -> str:
    lines = []
    for k in sorted(settings.keys()):
        v = settings[k]
        lines.append(f"\t\t\t\t{k} = {v};")
    base_line = ""
    if base_config_ref:
        base_line = f"\t\t\tbaseConfigurationReference = {base_config_ref} /* ButterRun.xcconfig */;\n"
    return (
        f"\t\t{uuid} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"{base_line}"
        f"\t\t\tbuildSettings = {{\n"
        + "\n".join(lines) + "\n"
        f"\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};\n"
    )

def config_list(uuid: str, comment: str, debug_uuid: str, release_uuid: str) -> str:
    return (
        f"\t\t{uuid} /* {comment} */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{debug_uuid} /* Debug */,\n"
        f"\t\t\t\t{release_uuid} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};\n"
    )

# Project-level settings
project_debug_settings = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"',
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}

project_release_settings = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SDKROOT": "iphoneos",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
}

app_debug_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CODE_SIGN_ENTITLEMENTS": "ButterRun/ButterRun.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": '"$(DEVELOPMENT_TEAM)"',
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "ButterRun/Info.plist",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "MARKETING_VERSION": "1.0.0",
    "PRODUCT_BUNDLE_IDENTIFIER": '"$(BUNDLE_ID_PREFIX).ButterRun"',
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}

app_release_settings = dict(app_debug_settings)
app_release_settings["SWIFT_OPTIMIZATION_LEVEL"] = '"-O"'

test_debug_settings = {
    "BUNDLE_LOADER": '"$(TEST_HOST)"',
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "PRODUCT_BUNDLE_IDENTIFIER": '"$(BUNDLE_ID_PREFIX).ButterRunTests"',
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "TEST_HOST": '"$(BUILT_PRODUCTS_DIR)/ButterRun.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ButterRun"',
}
test_release_settings = dict(test_debug_settings)

uitest_debug_settings = {
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "PRODUCT_BUNDLE_IDENTIFIER": '"$(BUNDLE_ID_PREFIX).ButterRunUITests"',
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "TEST_TARGET_NAME": "ButterRun",
}
uitest_release_settings = dict(uitest_debug_settings)

# ---------------------------------------------------------------------------
# Assemble the pbxproj
# ---------------------------------------------------------------------------

sections = []

# PBXBuildFile
sections.append("\n/* Begin PBXBuildFile section */")
for bf in sorted(build_files):
    sections.append(bf)
sections.append("/* End PBXBuildFile section */\n")

# PBXContainerItemProxy
sections.append("/* Begin PBXContainerItemProxy section */")
sections.append(
    f"\t\t{TEST_PROXY_UUID} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {PROJECT_UUID} /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {APP_TARGET_UUID};\n"
    f"\t\t\tremoteInfo = ButterRun;\n"
    f"\t\t}};"
)
sections.append(
    f"\t\t{UITEST_PROXY_UUID} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {PROJECT_UUID} /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {APP_TARGET_UUID};\n"
    f"\t\t\tremoteInfo = ButterRun;\n"
    f"\t\t}};"
)
sections.append("/* End PBXContainerItemProxy section */\n")

# PBXFileReference
sections.append("/* Begin PBXFileReference section */")
for fr in sorted(file_refs):
    sections.append(fr)
sections.append("/* End PBXFileReference section */\n")

# PBXFrameworksBuildPhase
sections.append("/* Begin PBXFrameworksBuildPhase section */")
sections.append(frameworks_phase(APP_FRAMEWORKS_PHASE_UUID))
sections.append(frameworks_phase(TEST_FRAMEWORKS_PHASE_UUID))
sections.append(frameworks_phase(UITEST_FRAMEWORKS_PHASE_UUID))
sections.append("/* End PBXFrameworksBuildPhase section */\n")

# PBXGroup
sections.append("/* Begin PBXGroup section */")
for g in all_groups:
    sections.append(g)
sections.append("/* End PBXGroup section */\n")

# PBXNativeTarget
sections.append("/* Begin PBXNativeTarget section */")
# App target
sections.append(
    f"\t\t{APP_TARGET_UUID} /* ButterRun */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {APP_CONFIG_LIST_UUID} /* Build configuration list for PBXNativeTarget \"ButterRun\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{APP_SOURCES_PHASE_UUID} /* Sources */,\n"
    f"\t\t\t\t{APP_FRAMEWORKS_PHASE_UUID} /* Frameworks */,\n"
    f"\t\t\t\t{APP_RESOURCES_PHASE_UUID} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t);\n"
    f"\t\t\tname = ButterRun;\n"
    f"\t\t\tproductName = ButterRun;\n"
    f"\t\t\tproductReference = {APP_PRODUCT_UUID} /* ButterRun.app */;\n"
    f'\t\t\tproductType = "com.apple.product-type.application";\n'
    f"\t\t}};"
)
# Test target
sections.append(
    f"\t\t{TEST_TARGET_UUID} /* ButterRunTests */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {TEST_CONFIG_LIST_UUID} /* Build configuration list for PBXNativeTarget \"ButterRunTests\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{TEST_SOURCES_PHASE_UUID} /* Sources */,\n"
    f"\t\t\t\t{TEST_FRAMEWORKS_PHASE_UUID} /* Frameworks */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t\t{TEST_DEP_UUID} /* PBXTargetDependency */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = ButterRunTests;\n"
    f"\t\t\tproductName = ButterRunTests;\n"
    f"\t\t\tproductReference = {TEST_PRODUCT_UUID} /* ButterRunTests.xctest */;\n"
    f'\t\t\tproductType = "com.apple.product-type.bundle.unit-test";\n'
    f"\t\t}};"
)
# UI Test target
sections.append(
    f"\t\t{UITEST_TARGET_UUID} /* ButterRunUITests */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {UITEST_CONFIG_LIST_UUID} /* Build configuration list for PBXNativeTarget \"ButterRunUITests\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{UITEST_SOURCES_PHASE_UUID} /* Sources */,\n"
    f"\t\t\t\t{UITEST_FRAMEWORKS_PHASE_UUID} /* Frameworks */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t\t{UITEST_DEP_UUID} /* PBXTargetDependency */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = ButterRunUITests;\n"
    f"\t\t\tproductName = ButterRunUITests;\n"
    f"\t\t\tproductReference = {UITEST_PRODUCT_UUID} /* ButterRunUITests.xctest */;\n"
    f'\t\t\tproductType = "com.apple.product-type.bundle.ui-testing";\n'
    f"\t\t}};"
)
sections.append("/* End PBXNativeTarget section */\n")

# PBXProject
sections.append("/* Begin PBXProject section */")
sections.append(
    f"\t\t{PROJECT_UUID} /* Project object */ = {{\n"
    f"\t\t\tisa = PBXProject;\n"
    f"\t\t\tattributes = {{\n"
    f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
    f"\t\t\t\tLastSwiftUpdateCheck = 1600;\n"
    f"\t\t\t\tLastUpgradeCheck = 1600;\n"
    f"\t\t\t\tTargetAttributes = {{\n"
    f"\t\t\t\t\t{APP_TARGET_UUID} = {{\n"
    f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n"
    f"\t\t\t\t\t}};\n"
    f"\t\t\t\t\t{TEST_TARGET_UUID} = {{\n"
    f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n"
    f"\t\t\t\t\t\tTestTargetID = {APP_TARGET_UUID};\n"
    f"\t\t\t\t\t}};\n"
    f"\t\t\t\t\t{UITEST_TARGET_UUID} = {{\n"
    f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n"
    f"\t\t\t\t\t\tTestTargetID = {APP_TARGET_UUID};\n"
    f"\t\t\t\t\t}};\n"
    f"\t\t\t\t}};\n"
    f"\t\t\t}};\n"
    f"\t\t\tbuildConfigurationList = {PROJECT_CONFIG_LIST_UUID} /* Build configuration list for PBXProject \"ButterRun\" */;\n"
    f'\t\t\tcompatibilityVersion = "Xcode 14.0";\n'
    f"\t\t\tdevelopmentRegion = en;\n"
    f"\t\t\thasScannedForEncodings = 0;\n"
    f"\t\t\tknownRegions = (\n"
    f"\t\t\t\ten,\n"
    f"\t\t\t\tBase,\n"
    f"\t\t\t);\n"
    f"\t\t\tmainGroup = {ROOT_GROUP_UUID};\n"
    f"\t\t\tproductRefGroup = {PRODUCTS_GROUP_UUID} /* Products */;\n"
    f'\t\t\tprojectDirPath = "";\n'
    f'\t\t\tprojectRoot = "";\n'
    f"\t\t\ttargets = (\n"
    f"\t\t\t\t{APP_TARGET_UUID} /* ButterRun */,\n"
    f"\t\t\t\t{TEST_TARGET_UUID} /* ButterRunTests */,\n"
    f"\t\t\t\t{UITEST_TARGET_UUID} /* ButterRunUITests */,\n"
    f"\t\t\t);\n"
    f"\t\t}};"
)
sections.append("/* End PBXProject section */\n")

# PBXResourcesBuildPhase
sections.append("/* Begin PBXResourcesBuildPhase section */")
sections.append(resources_phase(APP_RESOURCES_PHASE_UUID, app_resources))
sections.append("/* End PBXResourcesBuildPhase section */\n")

# PBXSourcesBuildPhase
sections.append("/* Begin PBXSourcesBuildPhase section */")
sections.append(sources_phase(APP_SOURCES_PHASE_UUID, app_swift, "ButterRun"))
sections.append(sources_phase(TEST_SOURCES_PHASE_UUID, test_swift, "ButterRunTests"))
sections.append(sources_phase(UITEST_SOURCES_PHASE_UUID, uitest_swift, "ButterRunUITests"))
sections.append("/* End PBXSourcesBuildPhase section */\n")

# PBXTargetDependency
sections.append("/* Begin PBXTargetDependency section */")
sections.append(
    f"\t\t{TEST_DEP_UUID} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {APP_TARGET_UUID} /* ButterRun */;\n"
    f"\t\t\ttargetProxy = {TEST_PROXY_UUID} /* PBXContainerItemProxy */;\n"
    f"\t\t}};"
)
sections.append(
    f"\t\t{UITEST_DEP_UUID} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {APP_TARGET_UUID} /* ButterRun */;\n"
    f"\t\t\ttargetProxy = {UITEST_PROXY_UUID} /* PBXContainerItemProxy */;\n"
    f"\t\t}};"
)
sections.append("/* End PBXTargetDependency section */\n")

# XCBuildConfiguration
sections.append("/* Begin XCBuildConfiguration section */")
sections.append(build_config(PROJECT_DEBUG_UUID, "Debug", project_debug_settings))
sections.append(build_config(PROJECT_RELEASE_UUID, "Release", project_release_settings))
sections.append(build_config(APP_DEBUG_UUID, "Debug", app_debug_settings, base_config_ref=XCCONFIG_FILE_UUID))
sections.append(build_config(APP_RELEASE_UUID, "Release", app_release_settings, base_config_ref=XCCONFIG_FILE_UUID))
sections.append(build_config(TEST_DEBUG_UUID, "Debug", test_debug_settings))
sections.append(build_config(TEST_RELEASE_UUID, "Release", test_release_settings))
sections.append(build_config(UITEST_DEBUG_UUID, "Debug", uitest_debug_settings))
sections.append(build_config(UITEST_RELEASE_UUID, "Release", uitest_release_settings))
sections.append("/* End XCBuildConfiguration section */\n")

# XCConfigurationList
sections.append("/* Begin XCConfigurationList section */")
sections.append(config_list(PROJECT_CONFIG_LIST_UUID, 'Build configuration list for PBXProject "ButterRun"', PROJECT_DEBUG_UUID, PROJECT_RELEASE_UUID))
sections.append(config_list(APP_CONFIG_LIST_UUID, 'Build configuration list for PBXNativeTarget "ButterRun"', APP_DEBUG_UUID, APP_RELEASE_UUID))
sections.append(config_list(TEST_CONFIG_LIST_UUID, 'Build configuration list for PBXNativeTarget "ButterRunTests"', TEST_DEBUG_UUID, TEST_RELEASE_UUID))
sections.append(config_list(UITEST_CONFIG_LIST_UUID, 'Build configuration list for PBXNativeTarget "ButterRunUITests"', UITEST_DEBUG_UUID, UITEST_RELEASE_UUID))
sections.append("/* End XCConfigurationList section */")

# Assemble full file
objects_content = "\n".join(f"\t\t{s}" if not s.startswith("\t") and not s.startswith("/*") else s for s in sections)

pbxproj = (
    "// !$*UTF8*$!\n"
    "{\n"
    "\tarchiveVersion = 1;\n"
    "\tclasses = {\n"
    "\t};\n"
    "\tobjectVersion = 56;\n"
    "\tobjects = {\n\n"
    f"{objects_content}\n\n"
    "\t};\n"
    f"\trootObject = {PROJECT_UUID} /* Project object */;\n"
    "}\n"
)

# ---------------------------------------------------------------------------
# Write pbxproj
# ---------------------------------------------------------------------------
os.makedirs(PROJ_DIR, exist_ok=True)
pbxproj_path = os.path.join(PROJ_DIR, "project.pbxproj")
with open(pbxproj_path, "w") as f:
    f.write(pbxproj)
print(f"Wrote {pbxproj_path}")

# ---------------------------------------------------------------------------
# Write scheme
# ---------------------------------------------------------------------------
os.makedirs(SCHEME_DIR, exist_ok=True)
scheme_path = os.path.join(SCHEME_DIR, "ButterRun.xcscheme")

scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES" runPostActionsOnFailure="NO">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{APP_TARGET_UUID}" BuildableName="ButterRun.app" BlueprintName="ButterRun" ReferencedContainer="container:ButterRun.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" shouldAutocreateTestPlan="YES">
      <Testables>
         <TestableReference skipped="NO" parallelizable="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TEST_TARGET_UUID}" BuildableName="ButterRunTests.xctest" BlueprintName="ButterRunTests" ReferencedContainer="container:ButterRun.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference skipped="NO" parallelizable="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{UITEST_TARGET_UUID}" BuildableName="ButterRunUITests.xctest" BlueprintName="ButterRunUITests" ReferencedContainer="container:ButterRun.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{APP_TARGET_UUID}" BuildableName="ButterRun.app" BlueprintName="ButterRun" ReferencedContainer="container:ButterRun.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{APP_TARGET_UUID}" BuildableName="ButterRun.app" BlueprintName="ButterRun" ReferencedContainer="container:ButterRun.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug" />
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES" />
</Scheme>
'''

with open(scheme_path, "w") as f:
    f.write(scheme)
print(f"Wrote {scheme_path}")

# Summary
line_count = pbxproj.count("\n")
print(f"pbxproj line count: {line_count}")
print(f"App swift files: {len(app_swift)}")
print(f"Test swift files: {len(test_swift)}")
print(f"UI test swift files: {len(uitest_swift)}")
