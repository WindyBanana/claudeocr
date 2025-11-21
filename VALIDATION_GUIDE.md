# Validation & Error Handling Guide

## Overview

The tool includes comprehensive validation to detect partial failures, suspicious extractions, and data quality issues. This guide explains what happens when notes aren't read correctly and how to handle different failure scenarios.

## File Organization System

### Automatic File Classification

After processing, images are moved to different folders based on extraction quality:

```
claudeocr/
├── input/              # Source images (emptied after processing)
├── processed/          # ✅ Successfully extracted with good quality
├── review/             # ⚠️  Extracted but quality is suspicious
├── failed/             # ❌ Complete failures (API errors, corrupt files)
└── output.csv          # All extracted data (includes review/ data)
```

###  What Goes Where

| Folder | Condition | Examples |
|--------|-----------|----------|
| **processed/** | Clean extraction, no warnings | All fields extracted, split pattern applied correctly |
| **review/** | Data extracted BUT quality is suspicious | Empty notes, mostly null fields, incomplete splits |
| **failed/** | Complete failure, no usable data | API errors, invalid JSON, corrupt images, exceeded retries |

## Validation Checks

The tool performs 5 automatic validation checks on every image:

### 1. Empty Extraction Detection

**Trigger:** AI returns empty array `[]` (no notes found)

**Warning:**
```
image_001.jpg: No notes extracted (empty array)
```

**Possible causes:**
- Image is blank or very low quality
- Handwriting is illegible
- Notes are too faint or blurred
- Wrong type of image (no text content)

**Action:** Image → **review/**

---

### 2. Minimum Expected Notes

**Trigger:** Fewer notes extracted than configured minimum

**Configuration:** `MIN_EXPECTED_NOTES` in `config.py` (default: 1)

**Warning:**
```
image_002.jpg: Only 2 notes extracted (expected at least 3)
```

**Possible causes:**
- AI missed some visually distinct notes
- Notes are too similar/overlapping
- Poor image quality obscures some notes

**Action:** Image → **review/** if partial data, **failed/** if complete failure

---

### 3. Mostly Null Fields

**Trigger:** More than 50% of fields are null/empty for a note

**Configuration:** `MAX_NULL_FIELDS_RATIO` in `config.py` (default: 0.5)

**Warning:**
```
image_003.jpg note #1: 4/6 fields are null (67%)
```

**Possible causes:**
- Note is incomplete or partial
- Handwriting is partially illegible
- AI couldn't confidently extract some fields
- Note doesn't contain all expected information

**Action:** Image → **review/** (data still saved, but flagged)

---

### 4. Incomplete Split Pattern

**Trigger:** Split pattern fields not properly populated

**Warnings:**
```
# Pattern not split:
image_004.jpg note #1: 'Verdivurdering' contains '3-5'
(expected split into Verdivurdering=3, Gjennomførbarhet=5)

# One field missing:
image_005.jpg note #2: Incomplete split pattern
(Verdivurdering=3, Gjennomførbarhet=null)
```

**Possible causes:**
- AI didn't recognize "x-y" pattern
- Value written in unexpected format ("3/5" instead of "3-5")
- One number is illegible
- Pattern ambiguous in handwriting

**Action:** Image → **review/**

---

### 5. Missing Required Fields

**Trigger:** Required fields are empty (if configured)

**Configuration:** `REQUIRE_ALL_FIELDS` in `config.py` (default: False)

**Warning:**
```
image_006.jpg note #1: Missing required fields: Bedrift, Beskrivelse
```

**Action:** Image → **review/** if partial acceptance enabled, **failed/** otherwise

---

## Configuration Options

Edit `config.py` to adjust validation behavior:

### Validation Settings

```python
# Warnings
WARN_ON_EMPTY_EXTRACTION = True      # Warn if no notes found
WARN_ON_MOSTLY_NULL = True           # Warn if >50% fields are null
WARN_ON_INCOMPLETE_SPLIT = True      # Warn if split pattern incomplete
MIN_EXPECTED_NOTES = 1               # Minimum notes per image (0 = no minimum)
MAX_NULL_FIELDS_RATIO = 0.5          # Flag notes with >50% null fields

# Partial failure handling
ACCEPT_PARTIAL_EXTRACTION = True     # Accept even if some notes missing
REQUIRE_ALL_FIELDS = False           # Fail if required fields missing

# File movement
MOVE_PROCESSED_FILES = True          # Move clean extractions to processed/
MOVE_REVIEW_FILES = True             # Move suspicious extractions to review/
MOVE_FAILED_FILES = True             # Move failures to failed/
```

### Recommended Configurations

**Strict Mode** (Reject partial failures):
```python
MIN_EXPECTED_NOTES = 3               # Expect at least 3 notes per image
ACCEPT_PARTIAL_EXTRACTION = False    # Reject if any notes missing
REQUIRE_ALL_FIELDS = True            # All fields must be populated
```

**Permissive Mode** (Accept anything extractable):
```python
MIN_EXPECTED_NOTES = 0               # No minimum
ACCEPT_PARTIAL_EXTRACTION = True     # Accept partial data
REQUIRE_ALL_FIELDS = False           # Optional fields allowed
WARN_ON_MOSTLY_NULL = False          # Don't warn about null fields
```

**Production Mode** (Balanced):
```python
MIN_EXPECTED_NOTES = 1               # At least one note
ACCEPT_PARTIAL_EXTRACTION = True     # Save partial data
MAX_NULL_FIELDS_RATIO = 0.7          # More lenient (70% threshold)
```

---

## Processing Summary Report

After each run, you'll see a detailed summary:

```
📊 Processing Summary

Images:
  ✓ Processed: 25
  ⚠ Review needed: 3 (suspicious quality)
  ✗ Failed: 2
  Success rate: 92.9%

Notes extracted: 78
  Average per image: 3.1

Token usage: 45,230 input / 12,450 output
Estimated API cost: $0.32

⚠ Warnings (5):
  • Mostly null fields: 3
  • Incomplete split pattern: 2

Details saved to: warnings.log

Output locations:
  • Extracted data: output.csv
  • Processed images: processed/
  • Review needed: review/ (check these manually)
  • Failed images: failed/
```

---

## Common Scenarios

### Scenario 1: Photo with 5 Notes, Only 3 Extracted

**What happens:**
1. API returns 3 notes in JSON array
2. Validation detects: `len(notes) < MIN_EXPECTED_NOTES`
3. Warning logged: "Only 3 notes extracted (expected at least 5)"
4. If `ACCEPT_PARTIAL_EXTRACTION=True`:
   - 3 notes saved to `output.csv`
   - Image moved to `review/`
   - Marked as "review needed" in summary
5. If `ACCEPT_PARTIAL_EXTRACTION=False`:
   - Image moved to `failed/`
   - Nothing written to CSV

**Action:** Check `review/` folder, manually verify image

---

### Scenario 2: Note with "3-5" Not Split

**What happens:**
1. AI returns: `{"Verdivurdering": "3-5", "Gjennomførbarhet": null}`
2. Validation detects dash in Verdivurdering field
3. Warning: "contains '3-5' (expected split)"
4. Data saved to CSV as-is: `3-5, null`
5. Image moved to `review/`

**Action:**
1. Check image in `review/`
2. Verify if "3-5" is clear and readable
3. If legible: Report as AI extraction bug
4. If ambiguous: Improve image quality

---

### Scenario 3: Empty Array (No Notes Found)

**What happens:**
1. AI returns: `[]`
2. Validation: "No notes extracted (empty array)"
3. If `MIN_EXPECTED_NOTES=0`: Accept, image → `review/`
4. If `MIN_EXPECTED_NOTES>0`: Reject, image → `failed/`
5. Nothing written to CSV

**Possible causes:**
- Blank image
- Very poor quality
- Wrong image type

---

### Scenario 4: Complete API Failure

**What happens:**
1. API call fails (rate limit, auth error, timeout)
2. Retry 3 times (configurable)
3. After 3 failures: Exception raised
4. Image moved to `failed/`
5. Error logged to `logs/process.log`
6. Count as failed image in summary

**Examples:**
- Network timeout
- Invalid API key
- Rate limit exceeded
- Model unavailable

---

## Warnings Log

All warnings are saved to `warnings.log` with timestamps:

```
=== Run at 2025-01-15T10:30:00 ===
sticky_note_001.jpg: Only 2 notes extracted (expected at least 3)
sticky_note_003.jpg note #1: 4/6 fields are null (67%)
sticky_note_005.jpg note #2: Incomplete split pattern (Verdivurdering=3, Gjennomførbarhet=null)

=== Run at 2025-01-15T11:00:00 ===
photo_batch_02.jpg: No notes extracted (empty array)
```

---

## Best Practices

### During Testing (Preview Mode)

1. **Always start with Preview mode** (5 images)
2. Check summary for warnings
3. Review `review/` folder images manually
4. Adjust configuration if needed
5. Re-process failed images if appropriate

### During Production (Full Batch)

1. **Monitor review folder** after each run
2. Check warnings log for patterns
3. If >20% images in review: Improve image quality
4. If >10% in failed: Check API issues or image format

### Handling Review Folder

**Weekly workflow:**
1. Open `review/` folder
2. Inspect each image visually
3. For each image:
   - If extraction is correct: Move to `processed/`
   - If partially correct: Manually fix in `output.csv`
   - If incorrect: Delete from CSV, retake photo, reprocess

### Improving Extraction Quality

**If you see many warnings:**

| Warning Type | Solution |
|--------------|----------|
| Empty extraction | Better lighting, clearer handwriting |
| Mostly null fields | Write all fields on notes, use print instead of cursive |
| Incomplete split pattern | Write "x-y" clearly with dash, avoid ambiguous formats |
| Missing notes | Better spacing between notes, higher resolution photos |

---

## Advanced: Custom Validation

You can add custom validation logic in `main.py`:

```python
def validate_extraction(
    notes: list[dict[str, Any]],
    fields: Sequence[FieldMetadata],
    image_path: Path,
) -> ValidationResult:
    result = ValidationResult(notes_count=len(notes))

    # Your custom check
    for note in notes:
        company = note.get("Bedrift")
        if company and len(company) < 2:
            result.warnings.append(
                f"{image_path.name}: Company name too short ('{company}')"
            )
            result.should_review = True

    return result
```

---

## Troubleshooting

### Q: Everything goes to review/

**A:** Your thresholds are too strict. Try:
```python
MAX_NULL_FIELDS_RATIO = 0.7  # Allow more null fields
MIN_EXPECTED_NOTES = 0       # Don't enforce minimum
```

### Q: No warnings but extraction is bad

**A:** Enable more checks:
```python
WARN_ON_MOSTLY_NULL = True
WARN_ON_INCOMPLETE_SPLIT = True
MIN_EXPECTED_NOTES = 2  # Set reasonable minimum
```

### Q: Too many false positives

**A:** Images go to review but extraction is actually good:
```python
MAX_NULL_FIELDS_RATIO = 0.8  # More lenient
WARN_ON_MOSTLY_NULL = False  # Disable if not needed
```

---

## Summary

**Three-folder system:**
- ✅ **processed/** = Perfect extraction
- ⚠️ **review/** = Extracted but suspicious (manual check recommended)
- ❌ **failed/** = Total failure (no usable data)

**Key insight:** `review/` folder lets you accept partial successes while flagging them for manual verification, maximizing data extraction while maintaining quality control.
