#!/usr/bin/env python3
"""SCA-1867: wire SideBySideComparisonView.swift + both reference JSON fixtures
into the PickleballCoach app target so CI build-verifies the two-panel render
and bundles the exemplars for runtime decode."""
import sys, subprocess, pathlib

PROJ = pathlib.Path("PickleballCoach/PickleballCoach.xcodeproj/project.pbxproj")
src = PROJ.read_text()

# New object UUIDs (follow existing A1B2C3D4E5F60XXXA7B8C9D0 scheme; ...0041 is highest used)
VIEW_FR   = "A1B2C3D4E5F60042A7B8C9D0"
VIEW_BF   = "A1B2C3D4E5F60043A7B8C9D0"
RES_GROUP = "A1B2C3D4E5F60044A7B8C9D0"
FH_FR     = "A1B2C3D4E5F60045A7B8C9D0"
FH_BF     = "A1B2C3D4E5F60046A7B8C9D0"
BH_FR     = "A1B2C3D4E5F60047A7B8C9D0"
BH_BF     = "A1B2C3D4E5F60048A7B8C9D0"

def replace_once(s, old, new):
    if s.count(old) != 1:
        sys.exit(f"FATAL: anchor not unique ({s.count(old)}x):\n{old}")
    return s.replace(old, new)

# 1. PBXBuildFile entries (insert after the MechanicsScore build file line)
anchor = "\t\tA1B2C3D4E5F60041A7B8C9D0 /* MechanicsScore.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1B2C3D4E5F60040A7B8C9D0 /* MechanicsScore.swift */; };\n"
add = (
    f"\t\t{VIEW_BF} /* SideBySideComparisonView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {VIEW_FR} /* SideBySideComparisonView.swift */; }};\n"
    f"\t\t{FH_BF} /* reference_forehand_drive_v0.json in Resources */ = {{isa = PBXBuildFile; fileRef = {FH_FR} /* reference_forehand_drive_v0.json */; }};\n"
    f"\t\t{BH_BF} /* reference_backhand_drive_v0.json in Resources */ = {{isa = PBXBuildFile; fileRef = {BH_FR} /* reference_backhand_drive_v0.json */; }};\n"
)
src = replace_once(src, anchor, anchor + add)

# 2. PBXFileReference entries (insert after the MechanicsScore file reference line)
anchor = '\t\tA1B2C3D4E5F60040A7B8C9D0 /* MechanicsScore.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MechanicsScore.swift; sourceTree = "<group>"; };\n'
add = (
    f'\t\t{VIEW_FR} /* SideBySideComparisonView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SideBySideComparisonView.swift; sourceTree = "<group>"; }};\n'
    f'\t\t{FH_FR} /* reference_forehand_drive_v0.json */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = reference_forehand_drive_v0.json; sourceTree = "<group>"; }};\n'
    f'\t\t{BH_FR} /* reference_backhand_drive_v0.json */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = reference_backhand_drive_v0.json; sourceTree = "<group>"; }};\n'
)
src = replace_once(src, anchor, anchor + add)

# 3a. Add view to Views group (after PoseOverlayView)
anchor = "\t\t\t\tA1B2C3D4E5F6002DA7B8C9D0 /* PoseOverlayView.swift */,\n"
src = replace_once(src, anchor, anchor + f"\t\t\t\t{VIEW_FR} /* SideBySideComparisonView.swift */,\n")

# 3b. Add Resources group to PickleballCoach group (after Assets.xcassets child)
anchor = ("\t\t\t\tA1B2C3D4E5F60024A7B8C9D0 /* Assets.xcassets */,\n"
          "\t\t\t\tA1B2C3D4E5F60028A7B8C9D0 /* Info.plist */,\n")
src = replace_once(src, anchor,
    "\t\t\t\tA1B2C3D4E5F60024A7B8C9D0 /* Assets.xcassets */,\n"
    f"\t\t\t\t{RES_GROUP} /* Resources */,\n"
    "\t\t\t\tA1B2C3D4E5F60028A7B8C9D0 /* Info.plist */,\n")

# 3c. Define the Resources PBXGroup (insert before "Products" group def)
anchor = "\t\tA1B2C3D4E5F60007A7B8C9D0 /* Products */ = {\n"
res_group = (
    f"\t\t{RES_GROUP} /* Resources */ = {{\n"
    "\t\t\tisa = PBXGroup;\n"
    "\t\t\tchildren = (\n"
    f"\t\t\t\t{FH_FR} /* reference_forehand_drive_v0.json */,\n"
    f"\t\t\t\t{BH_FR} /* reference_backhand_drive_v0.json */,\n"
    "\t\t\t);\n"
    "\t\t\tpath = Resources;\n"
    '\t\t\tsourceTree = "<group>";\n'
    "\t\t};\n"
)
src = replace_once(src, anchor, res_group + anchor)

# 4. Add JSONs to Resources build phase
anchor = "\t\t\t\tA1B2C3D4E5F60025A7B8C9D0 /* Assets.xcassets in Resources */,\n"
src = replace_once(src, anchor, anchor +
    f"\t\t\t\t{FH_BF} /* reference_forehand_drive_v0.json in Resources */,\n"
    f"\t\t\t\t{BH_BF} /* reference_backhand_drive_v0.json in Resources */,\n")

# 5. Add view to Sources build phase (after MechanicsScore in Sources)
anchor = "\t\t\t\tA1B2C3D4E5F60041A7B8C9D0 /* MechanicsScore.swift in Sources */,\n"
src = replace_once(src, anchor, anchor +
    f"\t\t\t\t{VIEW_BF} /* SideBySideComparisonView.swift in Sources */,\n")

PROJ.write_text(src)
print("patched. validating plist structure...")
r = subprocess.run(["plutil", "-lint", str(PROJ)], capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip())
sys.exit(r.returncode)
