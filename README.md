# Note Transcriber

AI-powered batch transcription of handwritten and printed sticky notes using Claude or OpenAI vision models.

## Requirements

- Python 3.12 (managed via `.python-version`)
- [UV](https://docs.astral.sh/uv/) for dependency management
- Anthropic and/or OpenAI API key with image-reading capabilities

## Installation

### Automatic Setup (Recommended)

Run the setup script for your operating system. It will:
- Check if uv is installed
- Install uv if needed (with your confirmation)
- Install Python dependencies
- Create required folders
- Set up .env file

**Linux / macOS:**
```bash
chmod +x setup.sh
./setup.sh
```

**Windows PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

### Manual Installation

If you prefer to install manually:

#### macOS
```bash
brew install uv
```

#### Linux
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

#### Windows
```powershell
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

## Manual Setup

1. Clone or download this repository and move into the `claudeocr` directory.
2. (Optional but recommended) Run the TUI setup helper:
   ```bash
   uv run python setup_cli.py
   ```
   This script checks your Python version, confirms the `uv` CLI is installed, ensures `.env` exists, and creates any missing folders. It runs in any regular macOS/Linux terminal (Terminal.app, iTerm2, GNOME Terminal, etc.).
3. Install Python dependencies:
   ```bash
   uv sync
   ```
4. Configure your API keys (skip if you already filled them in from the TUI):
   - Copy `.env.example` to `.env`
   - Add whichever of these you plan to use: `ANTHROPIC_API_KEY=...`, `OPENAI_API_KEY=...`
5. Prepare your assets:
   - Place source images inside the `input/` folder (jpg, jpeg, png, pdf)
   - Create a CSV or Excel template containing the columns you want in the output

## Template Configuration

The template file defines the structure of your output data. The tool validates and configures your template interactively.

### Template Requirements

- **Format**: CSV or Excel (.csv, .xlsx, .xls)
- **Column headers**: Must be in Row 1
- **No duplicates**: Each column name must be unique
- **UTF-8 encoding**: Ensure proper character encoding

### Example Template

```csv
Bedrift,Beskrivelse,Business Value,Risk,Verdivurdering,Gjennomførbarhet
```

### Field Configuration

When you load a template, the tool will:

1. **Display detected columns** - Shows all fields found in Row 1
2. **Ask for configuration preference**:
   - **Auto (recommended)**: Uses smart defaults based on field names
   - **Manual**: Lets you configure each field individually

### Smart Field Detection

The tool automatically recognizes common field types:

| Field Type | Norwegian Keywords | English Keywords | Data Type | Split Pattern |
|------------|-------------------|------------------|-----------|---------------|
| Value Assessment | verdivurdering, verdi, priorit | value, priority | number | x (first) |
| Feasibility | gjennomførbarhet | feasibility, complexity | number | y (second) |
| Risk | risiko | risk | text | - |
| Description | beskrivelse | description, business value | text | - |
| Entity Names | bedrift, kunde | company, customer | text | - |

### Split Pattern Detection

**Important:** The tool automatically detects when **Verdivurdering** and **Gjennomførbarhet** fields are adjacent (typical Norwegian business note pattern).

**How it works:**
- On your physical note, you write: **"3-5"**
- The AI automatically splits this:
  - **Verdivurdering** (column E) = `3` (first number)
  - **Gjennomførbarhet** (column F) = `5` (second number)

**Example Note:**
```
Bedrift: Acme Corp
Beskrivelse: Implement new CRM system
Business Value: Increase customer retention
Risk: Integration complexity
3-5    ← This single value splits into two columns!
```

**CSV Output:**
```csv
Bedrift,Beskrivelse,Business Value,Risk,Verdivurdering,Gjennomførbarhet
Acme Corp,Implement new CRM system,Increase customer retention,Integration complexity,3,5
```

### Field Types Explained

- **text**: General text content (names, descriptions, paragraphs)
- **number**: Numeric values (integers or decimals) - used for split pattern fields
- **rating**: Numeric scores or ranges (e.g., "3-5", "2-4") - only when NOT using split pattern
- **date**: Date values

### How AI Uses Field Metadata

The configured field types guide the AI in:
- **Pattern matching**: Understanding "x-y" format for ratings
- **Content expectations**: Knowing descriptions are usually sentences
- **Validation**: Ensuring numeric fields contain numbers
- **Accuracy**: Extracting data in the expected format

### Handling Verbose Notes

**Notes can contain more text than template fields!**

The system intelligently handles verbose notes by:
- **Consolidating extra text** into the `Beskrivelse` or `Description` field
- **Supporting multi-paragraph descriptions** - no length limits
- **Preserving context** - all relevant information is retained
- **Organizing content coherently** - the AI structures the text logically

**Example:**
If your sticky note contains:
```
Bedrift: Acme Corp
Implementere nytt CRM-system for å øke kundelojalitet.
Dette vil også forbedre datakvalitet og gi bedre rapportering.
Vi trenger integrering med eksisterende systemer.
Risk: Kompleks integrasjon
3-5
```

The AI will:
1. Extract "Acme Corp" → **Bedrift**
2. Consolidate all the descriptive text → **Beskrivelse**:
   "Implementere nytt CRM-system for å øke kundelojalitet. Dette vil også forbedre datakvalitet og gi bedre rapportering. Vi trenger integrering med eksisterende systemer."
3. Extract "Kompleks integrasjon" → **Risk**
4. Split "3-5" → **Verdivurdering** (3) and **Gjennomførbarhet** (5)

**No need to limit your notes** - write as much detail as you need!

### Manual Configuration Example

If you choose manual configuration, you'll specify for each field:

```
Field: Verdivurdering
  Type: [1] Text [2] Number [3] Rating/Score [4] Date
  Choose (1-4): 3
  Expected format (e.g., 'x-y', '1-5'): 3-7
  Description: Value assessment score
```

## Usage

Run the CLI:
```bash
uv run python main.py
```

The program guides you through:
1. **Loading your template file** - Provide path to CSV/Excel template
2. **Configuring fields** - Choose auto-detection or manual setup
3. **Reviewing configuration** - Verify detected fields and patterns
4. **Selecting a mode** - Choose dry run, preview, full batch, or resume
5. **Monitoring progress** - Track processing via progress bar and logs

### Processing Modes

- **Dry Run**: Estimate costs and time without processing (no API calls)
- **Preview**: Process first 5 images to test configuration
- **Full Batch**: Process all images in input/ folder
- **Resume**: Continue from last processed image (after interruption)

Tip: A standard terminal session (macOS Terminal/iTerm, GNOME Terminal, Windows PowerShell) is sufficient—no container or VM is required once `uv` is installed.

## Output

The tool organizes results into multiple folders based on extraction quality:

- **`output.csv`**: All extracted data (consolidated results from all runs)
- **`processed/`**: ✅ Successfully extracted with good quality
- **`review/`**: ⚠️ Extracted but quality is suspicious (manual check recommended)
- **`failed/`**: ❌ Complete failures (API errors, corrupt files, invalid JSON)
- **`warnings.log`**: Detailed warnings about suspicious extractions
- **`logs/process.log`**: Complete processing log with all events
- **`progress.json`**: Resume state for interrupted runs

### Quality Validation

The tool automatically validates extraction quality and flags potential issues:

- **Empty extraction**: No notes found in image
- **Mostly null fields**: More than 50% of fields are empty
- **Incomplete split pattern**: "x-y" value not properly split
- **Partial extraction**: Fewer notes than expected

Images with quality issues are moved to `review/` for manual inspection while still saving extracted data to `output.csv`.

## Multi-Note Detection

The tool automatically detects and processes **multiple separate notes** in a single image using Claude's vision capabilities.

### What Gets Detected as Separate Notes

The AI looks for:
- **Physical boundaries**: Separate sticky notes, index cards, or papers
- **Significant whitespace**: Clear spacing between sections
- **Visual grouping**: Distinct sections or containers
- **Different locations**: Notes in different areas of the image

### How It Works

1. **Single API call** - The AI analyzes the entire image once
2. **Spatial reasoning** - Claude Vision identifies visually distinct notes
3. **Sequential numbering** - Notes are numbered top-left to bottom-right
4. **Individual extraction** - Each note becomes a separate row in output.csv

### Example Use Cases

✅ **Good for multi-note detection**:
- Whiteboard with multiple sticky notes
- Scanned page with multiple labeled sections
- Grid layout of index cards
- Receipt with multiple line items

⚠️ **May need single note per image**:
- Dense text without clear separation
- Continuous paragraphs
- Tightly spaced content without visual boundaries

### Tips for Best Results

- Ensure good lighting and clear note boundaries
- Leave visible whitespace between notes
- Use physically separate items (sticky notes work great)
- Test with Preview mode (5 images) to verify detection accuracy

### Cost Efficiency

Multi-note detection uses the **same single API call** as single-note processing, making it extremely cost-effective for batch work.

## Notes

- All paths are handled with `pathlib` for cross-platform compatibility.
- The tool requires UTF-8 encoded templates; ensure Excel/CSV exports adhere to UTF-8.
- For Windows terminals, run commands inside a supported shell (PowerShell or Git Bash).

## Model Recommendations

- **Anthropic Claude Sonnet 4 (default)** – Best balance of accuracy and speed for mixed handwriting/print OCR, good at structured JSON outputs.
- **Anthropic Claude Haiku 4** – Faster/cheaper if handwriting is very clear and you need lower cost; update `ANTHROPIC_MODEL` in `config.py` to use it.
- **OpenAI GPT-4o (default)** – Strong OCR quality, works well on receipts/labels with diagrams; lower latency than legacy GPT-4.
- **OpenAI GPT-4o Mini** – Budget-friendly alternative when perfect accuracy is not critical.

You can change the defaults by editing `ANTHROPIC_MODEL` or `OPENAI_MODEL` in `config.py`. During runtime, the CLI automatically selects the provider whose API key is available (or prompts you when both keys exist).
