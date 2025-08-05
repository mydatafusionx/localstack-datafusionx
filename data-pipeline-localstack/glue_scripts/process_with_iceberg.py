import boto3
from pyiceberg.catalog import GlueCatalog
from pyiceberg.schema import Schema, NestedField, StringType, IntegerType, DoubleType, TimestampType
from pyiceberg.partitioning import PartitionField, PartitionSpec
from pyiceberg.table.sorting import SortField, SortOrder
from datetime import datetime

# Configuração do cliente para LocalStack
session = boto3.Session(
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

# Configuração do catálogo
catalog = GlueCatalog(
    'glue',
    **{
        'region_name': 'us-east-1',
        'endpoint_url': 'http://localstack:4566',
        'aws_access_key_id': 'test',
        'aws_secret_access_key': 'test',
    }
)

def create_iceberg_table():
    # Definir o schema da tabela
    schema = Schema(
        NestedField(1, "customer_id", IntegerType(), required=True, doc="ID único do cliente"),
        NestedField(2, "first_name", StringType(), doc="Primeiro nome do cliente"),
        NestedField(3, "last_name", StringType(), doc="Sobrenome do cliente"),
        NestedField(4, "email", StringType(), doc="E-mail do cliente"),
        NestedField(5, "first_order_date", TimestampType(), doc="Data do primeiro pedido"),
        NestedField(6, "most_recent_order_date", TimestampType(), doc="Data do pedido mais recente"),
        NestedField(7, "number_of_orders", IntegerType(), doc="Número total de pedidos"),
        NestedField(8, "lifetime_value", DoubleType(), doc="Valor total gasto pelo cliente"),
        NestedField(9, "etl_loaded_at", TimestampType(), doc="Data de carregamento do ETL")
    )
    
    # Especificação de partição
    partition_spec = PartitionSpec(
        PartitionField(source_id=5, field_id=1000, transform="month", name="order_month")
    )
    
    # Ordem de classificação
    sort_order = SortOrder(
        SortField("customer_id", "asc")
    )
    
    # Criar a tabela
    try:
        catalog.create_namespace("data_lake")
    except Exception:
        pass  # Namespace já existe
    
    catalog.create_table(
        ("data_lake", "customer_orders_iceberg"),
        schema=schema,
        partition_spec=partition_spec,
        sort_order=sort_order,
        properties={
            'write.parquet.compression-codec': 'zstd',
            'write.metadata.delete-after-commit.enabled': 'true',
            'write.metadata.previous-versions-max': '100',
            'write.object-storage.enabled': 'true',
            'write.object-storage.path': 's3://iceberg-warehouse/data_lake/customer_orders_iceberg'
        }
    )
    print("Tabela Iceberg criada com sucesso!")

def process_data():
    # Aqui você implementaria a lógica de processamento
    # Exemplo: ler do S3, transformar e escrever na tabela Iceberg
    print("Processamento de dados concluído!")

if __name__ == "__main__":
    create_iceberg_table()
    process_data()
