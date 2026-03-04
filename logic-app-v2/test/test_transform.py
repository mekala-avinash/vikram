#!/usr/bin/env python3
"""
Test script for KsefFa3.xslt transformation against FA(3)_schemat.xsd.

Usage:
    python logic-app-v2/test/test_transform.py

Requires: lxml (pip install lxml)
"""
import sys
import os
from pathlib import Path

try:
    from lxml import etree
except ImportError:
    print("ERROR: lxml is required. Install with: pip install lxml")
    sys.exit(1)

# Resolve paths relative to this script
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
XSLT_PATH = PROJECT_ROOT / "maps" / "KsefFa3.xslt"
SCHEMA_PATH = PROJECT_ROOT / "schemas" / "FA3_schemat.xsd"
SAMPLE_PATH = SCRIPT_DIR / "sample_canonical.xml"


def run_transform(xslt_path: Path, input_path: Path) -> etree._Element:
    """Apply XSLT transformation and return the result tree."""
    xslt_doc = etree.parse(str(xslt_path))
    transform = etree.XSLT(xslt_doc)
    input_doc = etree.parse(str(input_path))
    result = transform(input_doc)
    if transform.error_log:
        for entry in transform.error_log:
            print(f"  XSLT warning: {entry}")
    return result


class LocalSchemaResolver(etree.Resolver):
    """Resolve imported schemas from local schemas/ directory."""
    def __init__(self, schemas_dir: Path):
        self.schemas_dir = schemas_dir
        super().__init__()

    def resolve(self, system_url, public_id, context):
        if system_url:
            filename = system_url.rsplit("/", 1)[-1]
            local = self.schemas_dir / filename
            if local.exists():
                return self.resolve_filename(str(local), context)
        return None


def validate_against_xsd(xml_tree: etree._Element, schema_path: Path) -> list:
    """Validate XML tree against XSD schema. Returns list of error strings."""
    parser = etree.XMLParser()
    parser.resolvers.add(LocalSchemaResolver(schema_path.parent))
    schema_doc = etree.parse(str(schema_path), parser)
    schema = etree.XMLSchema(schema_doc)
    is_valid = schema.validate(xml_tree)
    if is_valid:
        return []
    return [str(err) for err in schema.error_log]


def check_structure(xml_tree: etree._Element) -> list:
    """Perform structural checks on the transformed XML."""
    issues = []
    ns = {"fa": "http://ksef.mf.gov.pl/schema/FA/3-0E"}
    root = xml_tree.getroot()

    if root.tag != "{http://ksef.mf.gov.pl/schema/FA/3-0E}Faktura":
        issues.append(f"Root element is '{root.tag}', expected '{{http://ksef.mf.gov.pl/schema/FA/3-0E}}Faktura'")

    kod = root.find(".//fa:Naglowek/fa:KodFormularza", ns)
    if kod is not None:
        ks = kod.get("kodSystemowy")
        if ks != "FA (3)":
            issues.append(f"KodFormularza@kodSystemowy is '{ks}', expected 'FA (3)'")
        if kod.text != "FA":
            issues.append(f"KodFormularza text is '{kod.text}', expected 'FA'")
    else:
        issues.append("KodFormularza element not found")

    wariant = root.find(".//fa:Naglowek/fa:WariantFormularza", ns)
    if wariant is None:
        issues.append("WariantFormularza element not found")
    elif wariant.text != "3":
        issues.append(f"WariantFormularza is '{wariant.text}', expected '3'")

    for el_name in ["JST", "GV"]:
        el = root.find(f".//fa:Podmiot2/fa:{el_name}", ns)
        if el is None:
            issues.append(f"Podmiot2/{el_name} element not found")

    p15 = root.find(".//fa:Fa/fa:P_15", ns)
    if p15 is None:
        issues.append("Fa/P_15 (total gross) element not found")

    adnotacje = root.find(".//fa:Fa/fa:Adnotacje", ns)
    if adnotacje is None:
        issues.append("Fa/Adnotacje section not found")

    rodzaj = root.find(".//fa:Fa/fa:RodzajFaktury", ns)
    if rodzaj is None:
        issues.append("Fa/RodzajFaktury element not found")

    kod_waluty = root.find(".//fa:Fa/fa:KodWaluty", ns)
    if kod_waluty is None:
        issues.append("Fa/KodWaluty not found as direct child of Fa")

    waluta_wrapper = root.find(".//fa:Fa/fa:Waluta", ns)
    if waluta_wrapper is not None:
        issues.append("Fa/Waluta wrapper element found (should not exist in FA(3))")

    termin = root.find(".//fa:Fa/fa:Platnosc/fa:TerminPlatnosci/fa:Termin", ns)
    if termin is None:
        issues.append("Platnosc/TerminPlatnosci/Termin structure not found")

    return issues


def main():
    print("=" * 60)
    print("FA(3) XSLT Transformation Test")
    print("=" * 60)

    for path, label in [(XSLT_PATH, "XSLT"), (SCHEMA_PATH, "XSD"), (SAMPLE_PATH, "Sample XML")]:
        if not path.exists():
            print(f"FAIL: {label} file not found: {path}")
            sys.exit(1)
        print(f"  {label}: {path}")
    print()

    # Step 1: Transform
    print("[1/3] Applying XSLT transformation...")
    result = run_transform(XSLT_PATH, SAMPLE_PATH)
    result_xml = etree.tostring(result, pretty_print=True, xml_declaration=True, encoding="UTF-8").decode()
    print(f"  Output length: {len(result_xml)} bytes")

    output_path = SCRIPT_DIR / "output_fa3.xml"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(result_xml)
    print(f"  Saved to: {output_path}")
    print()

    # Step 2: Structural checks
    print("[2/3] Running structural checks...")
    structural_issues = check_structure(result)
    if structural_issues:
        for issue in structural_issues:
            print(f"  ISSUE: {issue}")
    else:
        print("  All structural checks passed.")
    print()

    # Step 3: XSD validation
    print("[3/3] Validating against FA(3)_schemat.xsd...")
    xsd_errors = validate_against_xsd(result, SCHEMA_PATH)
    if xsd_errors:
        print(f"  FAILED: {len(xsd_errors)} validation error(s):")
        for err in xsd_errors:
            print(f"    - {err}")
    else:
        print("  PASSED: XML validates against FA(3) XSD with zero errors.")
    print()

    # Summary
    print("=" * 60)
    total_issues = len(structural_issues) + len(xsd_errors)
    if total_issues == 0:
        print("RESULT: ALL CHECKS PASSED")
        print("=" * 60)
        return 0
    else:
        print(f"RESULT: {total_issues} issue(s) found")
        print("=" * 60)
        return 1


if __name__ == "__main__":
    sys.exit(main())
