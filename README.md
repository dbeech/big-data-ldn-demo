# Big Data LDN Digitransit demo

![Architecture diagram](images/architecture.jpg)

## Instructions

1. Create `env.sh` containing your Aiven API token

```
cat > env.sh <<EOF
export TF_VAR_aiven_api_token=<your api key>
EOF
```

2. Create infrastructure

> **Note:** Update `terraform.tfvars` with your Aiven project name first.

```
$ source env.sh
$ terraform init
$ terraform plan
$ terraform apply
```

3. Create Python 3 virtualenv and install dependencies

```
$ python3 -m venv venv
$ source venv/bin/activate
$ pip install -r requirements.txt
```

4. Load reference data into PostgreSQL (requires `psql` to be installed)

```
$ avn service cli bigdataldn-demo-postgres
defaultdb=> \i scripts/create_postgres_schema.sql; 
```

5. Create ClickHouse materialized view using SQL in `scripts/create_clickhouse_view.sql`

6. Prepare environment variables for Python Notebook
```
$ cd notebooks
$ bash env.sh
```
Start your prefererred Notebook environment

