import boto3
import os
from pyiceberg.catalog import load_catalog
from pyiceberg.schema import Schema
from pyiceberg.types import (
    NestedField, StringType, IntegerType, DoubleType, TimestampType, BooleanType
)

def setup_iceberg():
    # Configurar cliente Glue
    glue_client = boto3.client(
        'glue',
        endpoint_url='http://localstack:4566',
        region_name='us-east-1',
        aws_access_key_id='test',
        aws_secret_access_key='test'
    )

    # Criar banco de dados se não existir
    try:
        glue_client.create_database(
            DatabaseInput={
                'Name': 'iceberg_db',
                'Description': 'Database for Iceberg tables',
                'LocationUri': 's3://iceberg-warehouse',
                'Parameters': {
                    'comment': 'Iceberg database',
                    'iceberg.compatibility.symlink.manifest.enabled': 'true'
                }
            }
        )
        print("Banco de dados 'iceberg_db' criado com sucesso!")
    except glue_client.exceptions.AlreadyExistsException:
        print("Banco de dados 'iceberg_db' já existe.")
    except Exception as e:
        print(f"Erro ao criar banco de dados: {e}")
        return

    # Configurar catálogo Iceberg
    catalog = load_catalog(
        "glue_catalog",
        **{
            "type": "rest",
            "uri": "http://localstack:4566",
            "s3.endpoint": "http://localstack:4566",
            "s3.path-style-access": "true",
            "warehouse": "s3://iceberg-warehouse",
            "catalog-impl": "org.apache.iceberg.aws.glue.GlueCatalog",
            "io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
            "aws.region": "us-east-1",
            "aws.access-key-id": "test",
            "aws.secret-access-key": "test"
        }
    )

    # Definir schema da tabela de exemplo
    schema = Schema(
        NestedField(field_id=1, name="order_id", field_type=StringType(), required=True),
        NestedField(field_id=2, name="customer_id", field_type=StringType(), required=True),
        NestedField(field_id=3, name="order_date", field_type=TimestampType(), required=True),
        NestedField(field_id=4, name="amount", field_type=DoubleType(), required=False),
        NestedField(field_id=5, name="status", field_type=StringType(), required=False),
        NestedField(field_id=6, name="is_active", field_type=BooleanType(), required=False),
        NestedField(field_id=7, name="created_at", field_type=TimestampType(), required=True),
        NestedField(field_id=8, name="updated_at", field_type=TimestampType(), required=False)
    )

    # Criar tabela Iceberg
    table_name = "orders"
    try:
        if not catalog.namespace_exists("iceberg_db"):
            catalog.create_namespace("iceberg_db")
            
        catalog.create_table(
            identifier=("iceberg_db", table_name),
            schema=schema,
            properties={
                'write.parquet.compression-codec': 'zstd',
                'write.metadata.delete-after-commit.enabled': 'true',
                'write.metadata.previous-versions-max': '100',
                'comment': 'Tabela de pedidos com suporte a ACID'
            }
        )
        print(f"Tabela '{table_name}' criada com sucesso no banco de dados 'iceberg_db'!")
    except Exception as e:
        print(f"Erro ao criar tabela: {e}")

    # Listar tabelas para confirmar
    try:
        tables = catalog.list_tables("iceberg_db")
        print("\nTabelas disponíveis no banco de dados 'iceberg_db':")
        for table in tables:
            print(f"- {table[1]}")
    except Exception as e:
        print(f"Erro ao listar tabelas: {e}")

if __name__ == "__main__":
    print("Configurando ambiente Iceberg no LocalStack...")
    setup_iceber()
