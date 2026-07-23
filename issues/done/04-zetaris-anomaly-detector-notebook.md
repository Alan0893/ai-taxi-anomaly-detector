# Create Zetaris semantic layer notebook (`zetaris_anomaly_detector.ipynb`)

**Parent PRD:** [#10 — Add Zetaris semantic layer notebook and dual-auth Postman support](https://github.com/rh-ai-quickstart/ai-taxi-anomaly-detector/issues/10)

**Labels:** notebook, feature
**Blocked by:** [#03 — Helm credential injection](#03) (for cluster deployment; local authoring can proceed)
**Blocks:** [#05 — Validate end-to-end](#05)

---

## Goal

Create a new notebook that runs the same IsolationForest anomaly detection pipeline as `taxi_anomaly_detector.ipynb`, but sources data from the `taxi.taxi_trips` semantic layer via the Zetaris Lightning REST API. This enables side-by-side comparison: same analysis, different data source.

## User Stories

- **US 1** — Query the `taxi.taxi_trips` semantic layer with standardised column names.
- **US 2** — Authenticate via API key (Bearer token), no login/refresh flows.
- **US 4** — Filter data server-side with SQL `WHERE` + `LIMIT 10000`.
- **US 5** — Paginate through results automatically.
- **US 6** — Close the query token when pagination is complete.
- **US 7** — Run the same IsolationForest model (same features, same parameters).
- **US 8** — Produce the same scatter plot with anomalies in red.
- **US 9** — Clear error messages for wrong API key / unreachable endpoint.
- **US 10** — Validate required env vars before making API calls.
- **US 12** — Notebook appears via existing git-sync mechanism (just add to `notebooks/`).
- **US 13** — Both notebooks coexist.

## File

`notebooks/zetaris_anomaly_detector.ipynb`

## Notebook Structure (5 cells)

### Cell 0 — Markdown header

```markdown
# Taxi Anomaly Detection via Zetaris Semantic Layer

This notebook runs the same IsolationForest anomaly detection as
`taxi_anomaly_detector.ipynb`, but sources data from the `taxi.taxi_trips`
unified view via the Zetaris Lightning REST API instead of reading parquet
files from MinIO.
```

### Cell 1 — Environment validation

Read and validate `ZETARIS_API_URL`, `ZETARIS_API_KEY`, `ZETARIS_ORG_ID`. Print values (mask the API key to first 4 + last 4 chars). Fail early with a clear message if any are missing. Mirror the pattern from `init_check.ipynb`.

```python
import os

ZETARIS_API_URL = os.environ.get("ZETARIS_API_URL", "")
ZETARIS_API_KEY = os.environ.get("ZETARIS_API_KEY", "")
ZETARIS_ORG_ID  = os.environ.get("ZETARIS_ORG_ID", "")

missing = []
if not ZETARIS_API_URL: missing.append("ZETARIS_API_URL")
if not ZETARIS_API_KEY: missing.append("ZETARIS_API_KEY")
if not ZETARIS_ORG_ID:  missing.append("ZETARIS_ORG_ID")
if missing:
    raise EnvironmentError(
        f"Missing required environment variable(s): {', '.join(missing)}. "
        "Set them in the workbench pod spec or export manually."
    )

masked_key = ZETARIS_API_KEY[:4] + "****" + ZETARIS_API_KEY[-4:]
print(f"Zetaris API URL : {ZETARIS_API_URL}")
print(f"Zetaris API Key : {masked_key}")
print(f"Zetaris Org ID  : {ZETARIS_ORG_ID}")
```

### Cell 2 — Query Zetaris API with pagination

- `POST /api/v1.0/query/sql/start` to open query, get first page + `queryToken`
- Loop `GET /api/v1.0/query/sql/page` until no more rows
- `DELETE /api/v1.0/query/sql/close/{queryToken}` in a `finally` block
- All requests include `Authorization: Bearer <api-key>`, `X-Request-ID` (UUID), `X-Org-ID`
- Build pandas DataFrame from accumulated rows

SQL query:

```sql
SELECT passenger_count, trip_distance, fare_amount, tip_amount, pickup_datetime
FROM taxi.taxi_trips
WHERE pickup_datetime >= '2025-10-01' AND pickup_datetime < '2025-11-01'
LIMIT 10000
```

Error handling:
- HTTP 401 → `"Authentication failed. Check ZETARIS_API_KEY."`
- Connection error → `"Cannot reach Zetaris API. Check ZETARIS_API_URL."`
- No retry logic (matches existing notebook style).

Print summary: `"Loaded {n:,} trips from taxi.taxi_trips via Zetaris API ({pages} pages)"`

### Cell 3 — Anomaly detection

Identical to `taxi_anomaly_detector.ipynb` cell 2:

```python
features = ["passenger_count", "trip_distance", "fare_amount", "tip_amount"]
df = df.dropna(subset=features)
X = df[features]

model = IsolationForest(contamination=0.02, random_state=42)
df["anomaly_score"] = model.fit_predict(X)
df["is_anomaly"] = df["anomaly_score"] == -1

anomalies = df[df["is_anomaly"]]
print(f"Detected {len(anomalies):,} anomalous trips ({len(anomalies) / len(df):.1%})")
anomalies.sort_values("fare_amount", ascending=False).head(10)
```

### Cell 4 — Scatter plot

Identical to `taxi_anomaly_detector.ipynb` cell 3 (trip_distance vs fare_amount, anomalies in red).

## Implementation Notes

- `requests` is available in the notebook image (transitive dep of `boto3`). No `pip install` needed.
- No new Python dependencies.
- The notebook is delivered via the existing git-sync init container — just commit to `notebooks/`.
- Page limit per API call is 100 (API maximum). With `LIMIT 10000`, expect ~100 paginated calls.

## Out of Scope

- Replacing the existing MinIO notebook — both coexist.
- Pulling more than 10,000 rows.
- Using additional semantic layer columns beyond the 4 features.
- Retry logic.

## Acceptance Criteria

- [ ] `notebooks/zetaris_anomaly_detector.ipynb` exists and is valid JSON (can be opened in JupyterLab).
- [ ] Cell 1 fails with a clear message when any `ZETARIS_*` env var is missing.
- [ ] Cell 2 successfully queries and paginates through the Zetaris API, producing a DataFrame.
- [ ] Cell 2 closes the query token in a `finally` block even if pagination fails mid-way.
- [ ] Cell 3 runs IsolationForest with `contamination=0.02, random_state=42` on the same 4 features.
- [ ] Cell 4 produces a scatter plot of `trip_distance` vs `fare_amount` with anomalies in red.
- [ ] HTTP 401 from the API produces a readable error mentioning `ZETARIS_API_KEY`.
- [ ] The existing `taxi_anomaly_detector.ipynb` and `init_check.ipynb` are unchanged.
