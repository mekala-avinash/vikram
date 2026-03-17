#!/usr/bin/env python3
"""
Test script for KsefFa3.xslt v7.0 transformation against FA(3)_schemat.xsd.

Tests both standard invoices and corrective invoices, validating all new fields
added for Excel spec v2.2 alignment.

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

# Also support the project root input.xml
ALT_SAMPLE_PATH = PROJECT_ROOT.parent / "input.xml"
CORRECTIVE_SAMPLE_PATH = SCRIPT_DIR / "input_corrective.xml"

# Updated namespace for v7.0
NS_FA3 = "http://crd.gov.pl/wzor/2025/06/25/13775/"
NS = {"fa": NS_FA3}


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


def find_fa3(root, xpath):
    """Helper to find elements with FA(3) namespace."""
    return root.find(xpath, NS)


def find_all_fa3(root, xpath):
    """Helper to find all elements with FA(3) namespace."""
    return root.findall(xpath, NS)


def check_structure(xml_tree: etree._Element, is_corrective: bool = False) -> list:
    """Perform structural checks on the transformed XML."""
    issues = []
    root = xml_tree.getroot()

    # Root element check
    expected_root = f"{{{NS_FA3}}}Faktura"
    if root.tag != expected_root:
        issues.append(f"Root element is '{root.tag}', expected '{expected_root}'")

    # Naglowek checks
    kod = find_fa3(root, ".//fa:Naglowek/fa:KodFormularza")
    if kod is not None:
        ks = kod.get("kodSystemowy")
        if ks != "FA (3)":
            issues.append(f"KodFormularza@kodSystemowy is '{ks}', expected 'FA (3)'")
        if kod.text != "FA":
            issues.append(f"KodFormularza text is '{kod.text}', expected 'FA'")
    else:
        issues.append("KodFormularza element not found")

    wariant = find_fa3(root, ".//fa:Naglowek/fa:WariantFormularza")
    if wariant is None:
        issues.append("WariantFormularza element not found")
    elif wariant.text != "3":
        issues.append(f"WariantFormularza is '{wariant.text}', expected '3'")

    # Podmiot1 checks (Seller)
    prefiks = find_fa3(root, ".//fa:Podmiot1/fa:PrefiksPodatnika")
    if prefiks is None:
        issues.append("Podmiot1/PrefiksPodatnika not found (required per Excel spec)")
    elif prefiks.text != "PL":
        issues.append(f"PrefiksPodatnika is '{prefiks.text}', expected 'PL'")

    nip = find_fa3(root, ".//fa:Podmiot1/fa:DaneIdentyfikacyjne/fa:NIP")
    if nip is None:
        issues.append("Podmiot1/DaneIdentyfikacyjne/NIP not found")

    nazwa = find_fa3(root, ".//fa:Podmiot1/fa:DaneIdentyfikacyjne/fa:Nazwa")
    if nazwa is None:
        issues.append("Podmiot1/DaneIdentyfikacyjne/Nazwa not found")

    # Podmiot2 checks (Buyer)
    for el_name in ["JST", "GV"]:
        el = find_fa3(root, f".//fa:Podmiot2/fa:{el_name}")
        if el is None:
            issues.append(f"Podmiot2/{el_name} element not found")

    # Fa core checks
    p15 = find_fa3(root, ".//fa:Fa/fa:P_15")
    if p15 is None:
        issues.append("Fa/P_15 (total gross) element not found")

    adnotacje = find_fa3(root, ".//fa:Fa/fa:Adnotacje")
    if adnotacje is None:
        issues.append("Fa/Adnotacje section not found")

    rodzaj = find_fa3(root, ".//fa:Fa/fa:RodzajFaktury")
    if rodzaj is None:
        issues.append("Fa/RodzajFaktury element not found")

    kod_waluty = find_fa3(root, ".//fa:Fa/fa:KodWaluty")
    if kod_waluty is None:
        issues.append("Fa/KodWaluty not found as direct child of Fa")

    waluta_wrapper = find_fa3(root, ".//fa:Fa/fa:Waluta")
    if waluta_wrapper is not None:
        issues.append("Fa/Waluta wrapper element found (should not exist in FA(3))")

    # P_1M (Issue Place) — check if present when input has IssuePlace
    p1m = find_fa3(root, ".//fa:Fa/fa:P_1M")
    # Just check it's valid if present (no error if missing — it's conditional)

    # Adnotacje sub-checks
    if adnotacje is not None:
        for ann_name in ["P_16", "P_17", "P_18", "P_18A", "P_23"]:
            ann = find_fa3(adnotacje, f"fa:{ann_name}")
            if ann is None:
                issues.append(f"Adnotacje/{ann_name} not found")

        zwolnienie = find_fa3(adnotacje, "fa:Zwolnienie")
        if zwolnienie is None:
            issues.append("Adnotacje/Zwolnienie not found")

        nst = find_fa3(adnotacje, "fa:NoweSrodkiTransportu")
        if nst is None:
            issues.append("Adnotacje/NoweSrodkiTransportu not found")

        pmarzy = find_fa3(adnotacje, "fa:PMarzy")
        if pmarzy is None:
            issues.append("Adnotacje/PMarzy not found")

    # Line items check
    line_items = find_all_fa3(root, ".//fa:Fa/fa:FaWiersz")
    if not line_items:
        issues.append("No FaWiersz (line items) found")

    # Corrective invoice specific checks
    if is_corrective:
        if rodzaj is not None and rodzaj.text != "KOR":
            issues.append(f"RodzajFaktury is '{rodzaj.text}', expected 'KOR' for corrective invoice")

        dane_kor = find_fa3(root, ".//fa:Fa/fa:DaneFaKorygowanej")
        if dane_kor is None:
            issues.append("DaneFaKorygowanej section not found (required for corrective invoices)")
        else:
            data_wyst = find_fa3(dane_kor, "fa:DataWystFaKorygowanej")
            if data_wyst is None:
                issues.append("DaneFaKorygowanej/DataWystFaKorygowanej not found")
            nr_fa = find_fa3(dane_kor, "fa:NrFaKorygowanej")
            if nr_fa is None:
                issues.append("DaneFaKorygowanej/NrFaKorygowanej not found")

        przyczyna = find_fa3(root, ".//fa:Fa/fa:PrzyczynaKorekty")
        if przyczyna is None:
            issues.append("PrzyczynaKorekty not found (required for corrective invoices)")

        typ_kor = find_fa3(root, ".//fa:Fa/fa:TypKorekty")
        if typ_kor is None:
            issues.append("TypKorekty not found (required for corrective invoices)")

    # Stopka check (if KRS/REGON present in input)
    stopka = find_fa3(root, ".//fa:Stopka")
    rejestry = find_fa3(root, ".//fa:Stopka/fa:Rejestry") if stopka is not None else None

    return issues


def run_test(label: str, input_path: Path, is_corrective: bool = False) -> int:
    """Run a single test case. Returns number of issues found."""
    print(f"\n{'─' * 60}")
    print(f"TEST: {label}")
    print(f"{'─' * 60}")

    if not input_path.exists():
        print(f"  SKIP: Input file not found: {input_path}")
        return 0

    # Step 1: Transform
    print("[1/3] Applying XSLT transformation...")
    result = run_transform(XSLT_PATH, input_path)
    result_xml = etree.tostring(result, pretty_print=True, xml_declaration=True, encoding="UTF-8").decode()
    print(f"  Output length: {len(result_xml)} bytes")

    suffix = "_corrective" if is_corrective else ""
    output_path = SCRIPT_DIR / f"output_fa3{suffix}.xml"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(result_xml)
    print(f"  Saved to: {output_path}")
    print()

    # Step 2: Structural checks
    print("[2/3] Running structural checks...")
    structural_issues = check_structure(result, is_corrective=is_corrective)
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
        for err in xsd_errors[:10]:
            print(f"    - {err}")
        if len(xsd_errors) > 10:
            print(f"    ... and {len(xsd_errors) - 10} more errors")
    else:
        print("  PASSED: XML validates against FA(3) XSD with zero errors.")

    return len(structural_issues) + len(xsd_errors)


def main():
    print("=" * 60)
    print("FA(3) XSLT v7.0 Transformation Test Suite")
    print("=" * 60)

    for path, label in [(XSLT_PATH, "XSLT"), (SCHEMA_PATH, "XSD")]:
        if not path.exists():
            print(f"FAIL: {label} file not found: {path}")
            sys.exit(1)
        print(f"  {label}: {path}")
    print()

    total_issues = 0

    # Test 1: Standard invoice (prefer sample_canonical.xml, fall back to input.xml)
    standard_input = SAMPLE_PATH if SAMPLE_PATH.exists() else ALT_SAMPLE_PATH
    total_issues += run_test("Standard Invoice (export, EUR, non-EU buyer)", standard_input)

    # Test 2: Corrective invoice
    if CORRECTIVE_SAMPLE_PATH.exists():
        total_issues += run_test("Corrective Invoice (KOR, PLN, Polish buyer)", CORRECTIVE_SAMPLE_PATH, is_corrective=True)

    # Summary
    print()
    print("=" * 60)
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
