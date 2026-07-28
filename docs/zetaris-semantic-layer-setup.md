# Zetaris Semantic Layer and Data Mart Setup Guide

This guide documents how to configure the Zetaris NDP Fabric Builder to create a unified `taxi_trips` semantic layer on top of NYC TLC parquet data stored in MinIO.

## Prerequisites

- Zetaris NDP platform installed on the cluster (namespace: `zetaris-test`)
- MinIO instance with NYC TLC parquet files uploaded to `s3://data/tlc-trip-data/`
- Access to the Zetaris Fabric Builder UI
- Access to the Zetaris SQL Workspace

## 1. Register MinIO as a Data Source

Open the **SQL Workspace** in the Zetaris UI and run the following commands to register MinIO as an S3 file source.

### Create the Lightning Database

```sql
CREATE LIGHTNING DATABASE NY_TAXI DESCRIBE BY "NYC Taxi data on MinIO"
```

### Create the Yellow Taxi Filestore

```sql
CREATE LIGHTNING FILESTORE NY_TAXI OPTIONS (
    PATH "s3a://data/",
    s3Endpoint "http://minio.<namespace>.svc.cluster.local:9000",
    AWSACCESSKEYID "<minio-user>",
    AWSSECRETACCESSKEY "<minio-password>",
    useS3PathStyleAccess "true"
)
```

### Create the Green Taxi Filestore Table

```sql
CREATE LIGHTNING FILESTORE TABLE green_taxi_minio
FROM NY_TAXI FORMAT PARQUET OPTIONS (
    PATH "s3a://data/tlc-trip-data/green_tripdata_*.parquet",
    s3Endpoint "http://minio.<namespace>.svc.cluster.local:9000",
    AWSACCESSKEYID "<minio-user>",
    AWSSECRETACCESSKEY "<minio-password>",
    useS3PathStyleAccess "true",
    inferSchema "true"
)
```

### Validate Data Source Registration

Confirm Zetaris can read from both sources:

```sql
SELECT * FROM NY_TAXI.yellow_taxi_minio LIMIT 5
SELECT * FROM NY_TAXI.green_taxi_minio LIMIT 5
```

## 2. Create the Data Mart

The data mart provides virtual column renames so consumers see clean, snake_case column names.

1. Navigate to the **Virtual Data Mart** tab in the Fabric Builder
2. Click **Data Marts** in the left sidebar
3. Create a new data mart named `taxi_trips_data_mart`
4. From the **Data Sources** tab on the left, drag `NY_TAXI.yellow_taxi_minio` and `NY_TAXI.green_taxi_minio` into the data mart canvas

### Rename Virtual Columns

In each table's column list, rename the **Virtual Column** fields as follows.

**Green_taxi_minio:**

| Virtual Column (before) | Rename to |
|---|---|
| VendorID | vendor_id |
| lpep_pickup_datetime | pickup_datetime |
| lpep_dropoff_datetime | dropoff_datetime |
| RatecodeID | rate_code_id |
| PULocationID | pu_location_id |
| DOLocationID | do_location_id |
| passenger_count | passenger_count |
| trip_type | hail_type |

**Yellow_taxi_minio:**

| Virtual Column (before) | Rename to |
|---|---|
| VendorID | vendor_id |
| tpep_pickup_datetime | pickup_datetime |
| tpep_dropoff_datetime | dropoff_datetime |
| RatecodeID | rate_code_id |
| PULocationID | pu_location_id |
| DOLocationID | do_location_id |
| passenger_count | passenger_count |
| Airport_fee | airport_fee |

> **Note:** Green's `trip_type` column is renamed to `hail_type` to avoid collision with the yellow/green discriminator column added in the view.

Click **Save changes** in the top right.

## 3. Create the Unified View

The permanent view combines both tables into a single `taxi_trips` queryable surface with a trip type discriminator and decoded enum labels.

1. Navigate to the **Query Builder** tab
2. Click the **Views** sub-tab
3. Create a new **View Container** (e.g., `taxi`) or use an existing one
4. Click the **+** next to the container to create a new view named `taxi_trips`
5. From the **Data Sources** tab on the left, expand **Data Marts** and drag both `green_taxi_minio` and `yellow_taxi_minio` from `taxi_trips_data_mart` into the view canvas
6. In the **SQL** panel at the bottom, paste the following query:

```sql
SELECT
    'yellow' AS trip_type,
    vendor_id,
    CASE vendor_id WHEN 1 THEN 'Creative Mobile' WHEN 2 THEN 'Verifone' END AS vendor_label,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    trip_distance,
    rate_code_id,
    CASE rate_code_id WHEN 1 THEN 'Standard' WHEN 2 THEN 'JFK' WHEN 3 THEN 'Newark' WHEN 4 THEN 'Nassau/Westchester' WHEN 5 THEN 'Negotiated' WHEN 6 THEN 'Group' END AS rate_code_label,
    store_and_fwd_flag,
    pu_location_id,
    do_location_id,
    payment_type,
    CASE payment_type WHEN 1 THEN 'Credit Card' WHEN 2 THEN 'Cash' WHEN 3 THEN 'No Charge' WHEN 4 THEN 'Dispute' WHEN 5 THEN 'Unknown' END AS payment_type_label,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    cbd_congestion_fee,
    airport_fee,
    CAST(NULL AS DOUBLE) AS ehail_fee,
    CAST(NULL AS BIGINT) AS hail_type,
    CAST(NULL AS STRING) AS hail_type_label
FROM Taxi_trips_data_mart.Yellow_taxi_minio
UNION ALL
SELECT
    'green' AS trip_type,
    vendor_id,
    CASE vendor_id WHEN 1 THEN 'Creative Mobile' WHEN 2 THEN 'Verifone' END AS vendor_label,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    trip_distance,
    rate_code_id,
    CASE rate_code_id WHEN 1 THEN 'Standard' WHEN 2 THEN 'JFK' WHEN 3 THEN 'Newark' WHEN 4 THEN 'Nassau/Westchester' WHEN 5 THEN 'Negotiated' WHEN 6 THEN 'Group' END AS rate_code_label,
    store_and_fwd_flag,
    pu_location_id,
    do_location_id,
    payment_type,
    CASE payment_type WHEN 1 THEN 'Credit Card' WHEN 2 THEN 'Cash' WHEN 3 THEN 'No Charge' WHEN 4 THEN 'Dispute' WHEN 5 THEN 'Unknown' END AS payment_type_label,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    cbd_congestion_fee,
    CAST(NULL AS DOUBLE) AS airport_fee,
    ehail_fee,
    hail_type,
    CASE hail_type WHEN 1 THEN 'Street-hail' WHEN 2 THEN 'Dispatch' END AS hail_type_label
FROM Taxi_trips_data_mart.Green_taxi_minio
```

> **Important:** Keep CASE expressions on single lines. Multi-line CASE statements may cause parsing issues in the Query Builder SQL editor.

7. Click the **Result** tab to preview the data and confirm the query runs
8. Save the view

The view is now queryable as `taxi.taxi_trips` from the SQL Workspace.

## 4. Validation

Run these queries in the **SQL Workspace** to verify the semantic layer is working correctly.

### Both trip types present

```sql
SELECT trip_type, COUNT(*) AS cnt
FROM taxi.taxi_trips
GROUP BY trip_type
```

Expected: rows for both `yellow` and `green`.

### Unified datetime columns

```sql
SELECT trip_type, pickup_datetime, dropoff_datetime
FROM taxi.taxi_trips
LIMIT 5
```

Expected: columns named `pickup_datetime` and `dropoff_datetime` (no `tpep_` or `lpep_` prefixes).

### Enum decoding

```sql
SELECT trip_type, vendor_id, vendor_label, payment_type, payment_type_label, rate_code_id, rate_code_label
FROM taxi.taxi_trips
LIMIT 10
```

Expected: both integer codes and decoded string labels.

### Green hail type

```sql
SELECT trip_type, hail_type, hail_type_label
FROM taxi.taxi_trips
WHERE trip_type = 'green'
LIMIT 5
```

Expected: `hail_type` values with decoded labels (`Street-hail`, `Dispatch`).

## Column Reference

| Column | Type | Source | Description |
|---|---|---|---|
| trip_type | string | computed | `'yellow'` or `'green'` discriminator |
| vendor_id | int | both | Original TLC vendor code |
| vendor_label | string | computed | 1=Creative Mobile, 2=Verifone |
| pickup_datetime | timestamp | both | Unified from `tpep_`/`lpep_pickup_datetime` |
| dropoff_datetime | timestamp | both | Unified from `tpep_`/`lpep_dropoff_datetime` |
| passenger_count | bigint | both | Number of passengers |
| trip_distance | double | both | Trip distance in miles |
| rate_code_id | bigint | both | Original TLC rate code |
| rate_code_label | string | computed | 1=Standard, 2=JFK, 3=Newark, 4=Nassau/Westchester, 5=Negotiated, 6=Group |
| store_and_fwd_flag | string | both | Store-and-forward flag |
| pu_location_id | int | both | Pickup TLC zone ID |
| do_location_id | int | both | Dropoff TLC zone ID |
| payment_type | bigint | both | Original TLC payment code |
| payment_type_label | string | computed | 1=Credit Card, 2=Cash, 3=No Charge, 4=Dispute, 5=Unknown |
| fare_amount | double | both | Base fare |
| extra | double | both | Miscellaneous extras |
| mta_tax | double | both | MTA tax |
| tip_amount | double | both | Tip amount |
| tolls_amount | double | both | Tolls |
| improvement_surcharge | double | both | Improvement surcharge |
| total_amount | double | both | Total charged amount |
| congestion_surcharge | double | both | Congestion surcharge |
| cbd_congestion_fee | double | both | CBD congestion fee |
| airport_fee | double | yellow only | Airport fee (NULL for green) |
| ehail_fee | double | green only | E-hail fee (NULL for yellow) |
| hail_type | bigint | green only | Original green `trip_type` code (NULL for yellow) |
| hail_type_label | string | computed | 1=Street-hail, 2=Dispatch (NULL for yellow) |

## 5. REST API Access

The Zetaris REST API allows programmatic SQL queries against the semantic layer. Full API docs are available at the Redoc endpoint (see below).

### Endpoints

| Operation | Method | Path | Description |
|---|---|---|---|
| Login | `GET` | `/api/v1.0/auth/login` | Basic Auth (email/password) to obtain a bearer token |
| Refresh | `GET` | `/api/v1.0/auth/refresh` | Refresh an expired `idToken` using the `refreshToken` |
| OpenSqlQuery | `POST` | `/api/v1.0/query/sql/start` | Begin a SQL query; returns page 1 and a `queryToken` |
| PageSqlQuery | `GET` | `/api/v1.0/query/sql/page` | Fetch a specific page of a running query |
| CloseSqlQuery | `DELETE` | `/api/v1.0/query/sql/close/{queryToken}` | Release server-side query resources |

**Base URL:** `https://api.<zetaris-namespace>.apps.<cluster-domain>`

**API docs (Redoc):** `<base-url>/redoc/index.html`

### Required Headers

All endpoints require:

| Header | Value |
|---|---|
| `X-Request-ID` | Any UUID (e.g., `00000000-0000-0000-0000-000000000001`) |
| `X-Org-ID` | Organization ID (integer, typically `1`) |

Query endpoints (`OpenSqlQuery`, `PageSqlQuery`, `CloseSqlQuery`) additionally require:

| Header | Value |
|---|---|
| `Authorization` | `Bearer <idToken>` (obtained from Login) |

### Authentication

Login uses HTTP Basic Auth and returns a JWT pair:

```bash
curl -s -u '<email>:<password>' \
  -H 'X-Request-ID: 00000000-0000-0000-0000-000000000001' \
  -H 'X-Org-ID: 1' \
  '<base-url>/api/v1.0/auth/login'
```

Response:

```json
{
  "idToken": "eyJ0eXAi...",
  "refreshToken": "eyJ0eXAi..."
}
```

The `idToken` (15-minute TTL) is used as the bearer token for query endpoints. Use the Refresh endpoint with the `refreshToken` (1-hour TTL) to obtain a new pair without re-authenticating.

### OpenSqlQuery

Begin executing a SQL query. Returns the first page of results and a `queryToken` for pagination.

```bash
curl -s -X POST \
  -H 'Authorization: Bearer <idToken>' \
  -H 'Content-Type: application/json' \
  -H 'X-Request-ID: 00000000-0000-0000-0000-000000000002' \
  -H 'X-Org-ID: 1' \
  -d '{"select": "SELECT trip_type, COUNT(*) AS cnt FROM taxi.taxi_trips GROUP BY trip_type", "pageLimit": 10}' \
  '<base-url>/api/v1.0/query/sql/start'
```

Request body:

| Field | Type | Description |
|---|---|---|
| `select` | string | SQL query to execute |
| `pageLimit` | int | Max records per page (1-100) |

Response:

```json
{
  "records": [{"trip_type": "yellow", "cnt": "16640038"}, {"trip_type": "green", "cnt": "184836"}],
  "pageNumber": 1,
  "pageLimit": 10,
  "totalCount": 2,
  "totalPages": 1,
  "queryToken": "EXAMPLE_QUERY_TOKEN"
}
```

### PageSqlQuery

Fetch a specific page of results from a running query.

```bash
curl -s \
  -H 'Authorization: Bearer <idToken>' \
  -H 'X-Request-ID: 00000000-0000-0000-0000-000000000003' \
  -H 'X-Org-ID: 1' \
  '<base-url>/api/v1.0/query/sql/page?queryToken=<queryToken>&pageLimit=10&pageNumber=2'
```

Query parameters:

| Parameter | Type | Description |
|---|---|---|
| `queryToken` | string | Token from `OpenSqlQuery` response |
| `pageLimit` | int | Max records per page |
| `pageNumber` | int | Page number to fetch |

### CloseSqlQuery

Release server-side resources for a completed query.

```bash
curl -s -X DELETE \
  -H 'Authorization: Bearer <idToken>' \
  -H 'X-Request-ID: 00000000-0000-0000-0000-000000000004' \
  -H 'X-Org-ID: 1' \
  '<base-url>/api/v1.0/query/sql/close/<queryToken>'
```

Returns HTTP 200 with an empty body on success.

### Postman Collection

A ready-to-import Postman collection is provided at [`docs/zetaris-api.postman_collection.json`](zetaris-api.postman_collection.json).

To use it:

1. Import the collection in Postman (File > Import)
2. Update the Login request's Basic Auth credentials with your Zetaris email and password
3. Send **Login** first — the test script auto-saves `idToken` and `refreshToken` to collection variables
4. Send **OpenSqlQuery** — the test script auto-saves `queryToken` for use by PageSqlQuery and CloseSqlQuery
5. Send **PageSqlQuery** or **CloseSqlQuery** as needed — they reference `{{queryToken}}` automatically

> **Note:** The collection ships with a placeholder password (`<your-password>`). Update it in the Login request's Authorization tab before first use.
