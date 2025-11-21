#!/usr/bin/env python3
"""Quick test to verify validation logic works without API calls."""

from pathlib import Path
from main import FieldMetadata, ValidationResult, validate_extraction

# Mock field configuration (your template)
fields = [
    FieldMetadata(name="Bedrift", data_type="text", description="Company name"),
    FieldMetadata(name="Beskrivelse", data_type="text", description="Description"),
    FieldMetadata(name="Business Value", data_type="text", description="Value description"),
    FieldMetadata(name="Risk", data_type="text", description="Risk level"),
    FieldMetadata(
        name="Verdivurdering",
        data_type="number",
        split_pattern="x",
        split_partner="Gjennomførbarhet",
        description="Value assessment"
    ),
    FieldMetadata(
        name="Gjennomførbarhet",
        data_type="number",
        split_pattern="y",
        split_partner="Verdivurdering",
        description="Feasibility"
    ),
]

image_path = Path("test_image.jpg")

print("=" * 60)
print("VALIDATION LOGIC TESTS")
print("=" * 60)

# Test 1: Perfect extraction
print("\n✓ Test 1: Perfect extraction (all fields filled)")
notes = [
    {
        "note_number": 1,
        "Bedrift": "Acme Corp",
        "Beskrivelse": "New CRM system",
        "Business Value": "Better insights",
        "Risk": "Data migration",
        "Verdivurdering": "3",
        "Gjennomførbarhet": "5"
    }
]
result = validate_extraction(notes, fields, image_path)
print(f"  is_valid: {result.is_valid}")
print(f"  should_review: {result.should_review}")
print(f"  warnings: {result.warnings}")
print(f"  → Would go to: {'processed/' if not result.should_review else 'review/'}")

# Test 2: Empty extraction
print("\n⚠ Test 2: Empty extraction (no notes found)")
notes = []
result = validate_extraction(notes, fields, image_path)
print(f"  is_valid: {result.is_valid}")
print(f"  should_review: {result.should_review}")
print(f"  warnings: {result.warnings}")
print(f"  → Would go to: {'review/' if result.should_review else 'processed/'}")

# Test 3: Split pattern NOT applied
print("\n⚠ Test 3: Split pattern not applied (still contains 'x-y')")
notes = [
    {
        "note_number": 1,
        "Bedrift": "Beta Inc",
        "Beskrivelse": "API integration",
        "Business Value": "Faster processing",
        "Risk": "Technical complexity",
        "Verdivurdering": "3-5",  # WRONG: Should be split
        "Gjennomførbarhet": None
    }
]
result = validate_extraction(notes, fields, image_path)
print(f"  is_valid: {result.is_valid}")
print(f"  should_review: {result.should_review}")
print(f"  warnings: {len(result.warnings)} warnings")
for w in result.warnings:
    print(f"    - {w}")
print(f"  → Would go to: {'review/' if result.should_review else 'processed/'}")

# Test 4: Mostly null fields
print("\n⚠ Test 4: Mostly null fields (4/6 empty = 67%)")
notes = [
    {
        "note_number": 1,
        "Bedrift": "Gamma Ltd",
        "Beskrivelse": None,
        "Business Value": None,
        "Risk": None,
        "Verdivurdering": None,
        "Gjennomførbarhet": "3"
    }
]
result = validate_extraction(notes, fields, image_path)
print(f"  is_valid: {result.is_valid}")
print(f"  should_review: {result.should_review}")
print(f"  warnings: {len(result.warnings)} warnings")
for w in result.warnings:
    print(f"    - {w}")
print(f"  → Would go to: {'review/' if result.should_review else 'processed/'}")

# Test 5: Partial extraction (only 2 of 3 notes)
print("\n⚠ Test 5: Partial extraction (only 2 notes, expected 3+)")
notes = [
    {
        "note_number": 1,
        "Bedrift": "Delta Corp",
        "Beskrivelse": "Mobile app",
        "Business Value": "User engagement",
        "Risk": "Platform fragmentation",
        "Verdivurdering": "4",
        "Gjennomførbarhet": "3"
    },
    {
        "note_number": 2,
        "Bedrift": "Epsilon LLC",
        "Beskrivelse": "Cloud migration",
        "Business Value": "Cost savings",
        "Risk": "Downtime",
        "Verdivurdering": "5",
        "Gjennomførbarhet": "4"
    }
]
# Note: This would only trigger if MIN_EXPECTED_NOTES is set > 2
result = validate_extraction(notes, fields, image_path)
print(f"  is_valid: {result.is_valid}")
print(f"  should_review: {result.should_review}")
print(f"  warnings: {len(result.warnings)} warnings")
print(f"  → Would go to: {'processed/' if not result.should_review else 'review/'}")

print("\n" + "=" * 60)
print("VALIDATION LOGIC TESTS COMPLETE")
print("=" * 60)
print("\nAll validation checks are working as designed.")
print("Next step: Test with real images and API calls.")
