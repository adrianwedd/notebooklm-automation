# Gemini Deep Research Internal API

Reverse-engineered from the Gemini web interface at `gemini.google.com`.

## Overview

Gemini Deep Research uses Google's internal `batchexecute` RPC framework and the `BardFrontendService/StreamGenerate` streaming endpoint. All requests go through `gemini.google.com/_/BardChatUi/data/`.

## Authentication

All requests require:
- **Cookies**: Google session cookies (SID, HSID, SSID, etc.)
- **`at` parameter**: CSRF/auth token (42 chars), sent as form data
- **`f.sid` parameter**: Session ID, sent in URL query string

## Endpoints

### 1. StreamGenerate (Main Query/Action)

**URL**: `/_/BardChatUi/data/assistant.lamda.BardFrontendService/StreamGenerate`

**Method**: POST (form-encoded)

**URL Parameters**:
| Param | Description | Example |
|-------|-------------|---------|
| `bl` | Build label | `boq_assistant-bard-web-server_...` |
| `f.sid` | Session ID | `-4458636884453319938` |
| `hl` | Locale | `en-AU` |
| `_reqid` | Request counter | `3764181` |
| `rt` | Response type | `c` |

**Body Parameters**:
- `f.req` - URL-encoded nested JSON array
- `at` - Auth token

**f.req format for initiating Deep Research query**:
```
[null, "[[\"<prompt_text>\",0,null,null,null,null,0],
        [\"<locale>\"],
        [\"c_<conv_id>\",\"r_<response_id>\",\"rc_<candidate_id>\",null,null,null,null,null,null,\"<continuation_token>\"],
        \"<session_token>\"
       ]"]
```

**f.req format for "Start research" action**:
```
[null, "[[\"Start research\",0,null,null,null,null,0],
        [\"en-AU\"],
        [\"c_<conv_id>\",\"r_<response_id>\",\"rc_<candidate_id>\",
         null,null,null,null,null,null,\"<continuation_token>\"],
        \"<session_token>\"
       ]"]
```

**Response format** (streaming, anti-XSSI protected):
```
)]}'

<chunk_length>
[["wrb.fr",null,"<inner_json>",null,null,null,"generic"]]
<chunk_length>
[["wrb.fr",null,"<inner_json>",null,null,null,"generic"]]
...
```

**Inner JSON structure** contains:
- `[null, ["c_<conv_id>", "r_<new_response_id>"], ...]` - IDs
- Response candidate IDs (`rc_...`)
- Message text content
- Metadata (model info, locale, etc.)

### 2. batchexecute (RPC Calls)

**URL**: `/_/BardChatUi/data/batchexecute`

**Method**: POST (form-encoded)

**URL Parameters**: Same as StreamGenerate, plus:
| Param | Description |
|-------|-------------|
| `rpcids` | RPC method name |
| `source-path` | Current conversation path |

**Body format**:
```
f.req=[[[\"<RPC_METHOD>\",\"<params_json>\",null,\"generic\"]]]&at=<auth_token>&
```

## RPC Methods

### ESY5D - Activity Check
Checks if Bard activity logging is enabled.

**Request**: `[[[\"bard_activity_enabled\"]]]`
**Response**: `[[null,null,null,null,true]]`

### kwDCne - Deep Research Task Status (Primary Polling)
Returns the full Deep Research task state including research plan, progress, and results.

**Request**: `[\"<task_uuid>\"]`
**Response structure**:
```json
[["<task_uuid>", [
  null, null, null,
  ["c_<conv_id>"],           // Index 3: conversation
  ["<title>", "<plan_text>", // Index 4: research plan + content (grows to 250KB+)
   [<191_progress_items>]],
  [<timestamp_sec>, <timestamp_nsec>]  // Index 5: timestamps
]]]
```

**Progress items** (array of 191+ entries):
- Items 0-2: Research plan section headers (e.g., "Mapping Recent Milestones")
- Items 3-180+: "Researching websites..." entries with growing source lists
- Items 185-186: Google logo URLs (section separators)
- Items 188-190: Analysis section headers (e.g., "Massive Scaling of Logical Qubits")

### PCck7e - Response Polling
Polls for response updates using a response ID.

**Request**: `[\"r_<response_id>\"]`
**Response**: `[]` (empty while processing) or response data when complete

### qpEbW - Timing/Status
Returns timing data for processing states.

**Request**: `[[[1,4],[6,6],[1,15]]]`
**Response**: `[[[[2,15,2],1,0,[<timestamp>],300,300],...],\"<session_id>\"]`

### aPya6c - Status Check
Simple boolean status check.

**Request**: `[]`
**Response**: `[false,0,[]]`

### hNvQHb - Full Conversation State
Returns the complete conversation state including all turns and the Deep Research report.

**Response structure** (459KB+):
```
[[
  [
    [["c_<conv_id>", "r_<latest_resp_id>"],
     ["c_<conv_id>", "r_<original_resp_id>", "rc_<candidate_id>"],
     [<metadata>],
     <response_data_array_22_elements>,
     [<timestamp>]
    ],
    [<previous_turn>]
  ],
  null, null,
  [[[]]]
]]
```

**Response data (22-element array)**:
| Index | Content |
|-------|---------|
| 0 | Report content array (437KB) |
| 3 | Response candidate ID (`rc_...`) |
| 8 | Country code (`AU`) |
| 9 | Boolean (true) |
| 12 | Metadata array |
| 14 | Session ID |
| 21 | Model name (`3 Pro`) |

**Report content** nested path: `[0][0][12][57][1][4]`
- `[0]`: Report title (e.g., "Quantum Error Correction Developments 2025-2026")
- `[2]`: Array of 191 progress/content items

### ukz1Fe - Export to Google Docs
Triggers export of a response to Google Docs.

**Request**: `[null,[["c_<conv_id>","r_<response_id>"]]]`
**Response**: `[[["<status_label>"]]]` (e.g., "Research Completed, Ready for Questions")

The actual Doc creation happens server-side. The client opens the resulting Doc URL in a new tab. The Doc URL follows the pattern:
```
https://docs.google.com/document/d/<doc_id>/edit
```

## Deep Research Flow

### Step 1: Submit Query
- **Endpoint**: `StreamGenerate`
- **Action**: Send research question
- **Response**: Research plan with sections and estimated time

### Step 2: Approve Plan
- **Endpoint**: `StreamGenerate`
- **Action**: Send "Start research" as the prompt text
- **Response**: Confirmation message ("I'm on it...")

### Step 3: Monitor Progress
- **Endpoint**: `batchexecute` with `kwDCne`
- **Action**: Poll with task UUID (from Step 2 response)
- **Response**: Growing task data with progress (23 websites... 61 websites... Analyzing results...)
- **Polling interval**: ~15-30 seconds
- **Response sizes**: 44KB -> 85KB -> 118KB -> 166KB -> 255KB (grows as research progresses)

### Step 4: Receive Results
- **Endpoint**: `batchexecute` with `hNvQHb`
- **Action**: Fetch full conversation state
- **Response**: Complete report in structured format (459KB+)

### Step 5: Export to Docs (Optional)
- **Endpoint**: `batchexecute` with `ukz1Fe`
- **Action**: Export response to Google Docs
- **Response**: Status confirmation + Doc opens in new tab

### Step 6: Download as Markdown (Optional)
- **URL**: `https://docs.google.com/document/d/<doc_id>/export?format=md`
- **Method**: GET with Google session cookies
- **Auth**: Requires valid Google session cookies (SID, HSID, SSID, etc.)
- **Response**: Raw Markdown text (Content-Disposition: attachment)

**Other supported export formats**:
| Format | Parameter | Extension |
|--------|-----------|-----------|
| Markdown | `format=md` | `.md` |
| Plain text | `format=txt` | `.txt` |
| PDF | `format=pdf` | `.pdf` |
| DOCX | `format=docx` | `.docx` |
| HTML | `format=html` | `.html` |
| EPUB | `format=epub` | `.epub` |
| ODT | `format=odt` | `.odt` |
| RTF | `format=rtf` | `.rtf` |

**curl example**:
```bash
DOC_ID="1c0UYO8FMcvhwuSG69icPfNzucm-HhEuftl_kRcPO5Po"
curl -L -b cookies.txt \
  "https://docs.google.com/document/d/${DOC_ID}/export?format=md" \
  -o "research-report.md"
```

**Automation script**: `scripts/download-gdoc-md.sh`
```bash
./scripts/download-gdoc-md.sh "$DOC_URL" --output report.md --cookies cookies.txt
```

## Push Notifications

Progress updates are also delivered via Google's Punctual push notification system:
- **Server selection**: `signaler-pa.clients6.google.com/punctual/v1/chooseServer`
- **Long-polling channel**: `signaler-pa.clients6.google.com/punctual/multi-watch/channel`
  - Connection duration: ~260 seconds per long-poll
- **Credential refresh**: `signaler-pa.clients6.google.com/punctual/v1/refreshCreds`

## Key IDs

| ID Format | Description | Example |
|-----------|-------------|---------|
| `c_<hex>` | Conversation ID | `c_f20bd8541c5bd618` |
| `r_<hex>` | Response ID | `r_ba2511a70a104102` |
| `rc_<hex>` | Response candidate ID | `rc_48bc48b53023442b` |
| UUID | Deep Research task ID | `5aadae03-640e-4a2a-8838-911d81b082c2` |
| `e6fa609c3fa255c0` | Session ID | Used in qpEbW and response metadata |

## Notes

- All responses use Google's anti-XSSI prefix: `)]}'` followed by newline
- Streaming responses use length-prefixed chunks
- The `_reqid` URL parameter increments by 100000 for each request
- Build label (`bl`) changes with Gemini deployments
- The `at` token appears to be session-scoped
- Deep Research uses model "3 Pro" (Gemini 2.5 Pro)
- Research typically takes 3-7 minutes and researches 60-100+ websites
