import boto3
import time
from botocore.exceptions import ClientError

def create_dms_resources():
    # Configurar cliente DMS
    dms = boto3.client(
        'dms',
        endpoint_url='http://localstack:4566',
        region_name='us-east-1',
        aws_access_key_id='test',
        aws_secret_access_key='test'
    )
    
    # 1. Criar Endpoint de origem (MySQL)
    try:
        source_endpoint = dms.create_endpoint(
            EndpointIdentifier='mysql-source-endpoint',
            EndpointType='source',
            EngineName='mysql',
            Username='user',
            Password='password',
            ServerName='mysql-source',
            Port=3306,
            DatabaseName='source_db',
            SslMode='none',
            ExtraConnectionAttributes='includeOpForFullLoad=true;useLogMinerReader=N;useBfile=true;usePathPrefix=true;'
        )
        print("Endpoint de origem (MySQL) criado com sucesso!")
    except dms.exceptions.ResourceAlreadyExistsException:
        print("Endpoint de origem já existe. Continuando...")
    except Exception as e:
        print(f"Erro ao criar endpoint de origem: {e}")
        return

    # 2. Criar Endpoint de destino (S3)
    try:
        target_endpoint = dms.create_endpoint(
            EndpointIdentifier='s3-target-endpoint',
            EndpointType='target',
            EngineName='s3',
            S3Settings={
                'ServiceAccessRoleArn': 'arn:aws:iam::000000000000:role/dms-s3-role',
                'BucketName': 'raw-data',
                'BucketFolder': 'dms/',
                'CdcInsertsOnly': False,
                'CdcPath': 'cdc/',
                'DataFormat': 'parquet',
                'ParquetVersion': 'parquet-2-0',
                'IncludeOpForFullLoad': True,
                'CdcMaxBatchInterval': 60,
                'CdcMinFileSize': 32,
                'CdcPath': 'cdc/',
                'CompressionType': 'GZIP',
                'DataPageSize': 1048576,
                'DictPageSizeLimit': 8388608,
                'RowGroupLength': 1048576,
                'AddColumnName': True,
                'CdcInsertsAndUpdates': True,
                'DatePartitionEnabled': True,
                'DatePartitionSequence': 'YYYYMMDD',
                'TimestampColumnName': 'dms_timestamp'
            }
        )
        print("Endpoint de destino (S3) criado com sucesso!")
    except dms.exceptions.ResourceAlreadyExistsException:
        print("Endpoint de destino já existe. Continuando...")
    except Exception as e:
        print(f"Erro ao criar endpoint de destino: {e}")
        return

    # 3. Criar instância de replicação
    try:
        # Aguardar os endpoints estarem prontos
        time.sleep(5)
        
        replication_instance = dms.create_replication_instance(
            ReplicationInstanceIdentifier='dms-replication-instance',
            ReplicationInstanceClass='dms.t3.micro',
            AllocatedStorage=50,
            VpcSecurityGroupIds=[],
            AvailabilityZone='us-east-1a',
            ReplicationSubnetGroupIdentifier='local-subnet-group',
            EngineVersion='3.4.6',
            PubliclyAccessible=True
        )
        print("Instância de replicação criada com sucesso!")
    except dms.exceptions.ResourceAlreadyExistsException:
        print("Instância de replicação já existe. Continuando...")
    except Exception as e:
        print(f"Erro ao criar instância de replicação: {e}")
        return

    # 4. Criar tarefa de replicação
    try:
        # Aguardar a instância de replicação estar disponível
        time.sleep(10)
        
        task = dms.create_replication_task(
            ReplicationTaskIdentifier='mysql-to-s3-task',
            SourceEndpointArn='arn:aws:dms:us-east-1:000000000000:endpoint:mysql-source-endpoint',
            TargetEndpointArn='arn:aws:dms:us-east-1:000000000000:endpoint:s3-target-endpoint',
            ReplicationInstanceArn='arn:aws:dms:us-east-1:000000000000:rep:dms-replication-instance',
            MigrationType='full-load-and-cdc',
            TableMappings='''
            {
                "rules": [
                    {
                        "rule-type": "selection",
                        "rule-id": "1",
                        "rule-name": "1",
                        "object-locator": {
                            "schema-name": "%",
                            "table-name": "%"
                        },
                        "rule-action": "include"
                    }
                ]
            }
            ''',
            ReplicationTaskSettings='''
            {
                "TargetMetadata": {
                    "TargetSchema": "",
                    "SupportLobs": true,
                    "FullLobMode": false,
                    "LobChunkSize": 64,
                    "LimitedSizeLobMode": true,
                    "LobMaxSize": 32,
                    "InlineLobMaxSize": 0,
                    "LoadMaxFileSize": 0,
                    "ParallelLoadThreads": 0,
                    "ParallelLoadBufferSize": 50,
                    "BatchApplyEnabled": false,
                    "TaskRecoveryTableEnabled": false
                },
                "FullLoadSettings": {
                    "TargetTablePrepMode": "DO_NOTHING",
                    "CreatePkAfterFullLoad": false,
                    "StopTaskCachedChangesApplied": false,
                    "StopTaskCachedChangesNotApplied": false,
                    "MaxFullLoadSubTasks": 8,
                    "TransactionConsistencyTimeout": 600,
                    "CommitRate": 10000
                },
                "Logging": {
                    "EnableLogging": true
                },
                "ControlTablesSettings": {
                    "ControlSchema": "",
                    "HistoryTimeslotInMinutes": 5,
                    "HistoryTableEnabled": true,
                    "SuspendedTablesTableEnabled": true,
                    "StatusTableEnabled": true
                },
                "StreamBufferSettings": {
                    "StreamBufferCount": 3,
                    "StreamBufferSizeInMB": 8,
                    "CtrlStreamBufferSizeInMB": 5
                },
                "ChangeProcessingTuning": {
                    "BatchApplyPreserveTransaction": true,
                    "BatchApplyTimeoutMin": 1,
                    "BatchApplyTimeoutMax": 30,
                    "BatchApplyMemoryLimit": 500,
                    "BatchSplitSize": 0,
                    "MinTransactionSize": 1000,
                    "CommitTimeout": 1,
                    "MemoryLimitTotal": 1024,
                    "MemoryKeepTime": 60,
                    "StatementCacheSize": 50
                },
                "ChangeProcessingDdlHandlingPolicy": {
                    "HandleSourceTableDropped": true,
                    "HandleSourceTableTruncated": true,
                    "HandleSourceTableAltered": true
                },
                "LoopbackPreventionSettings": {
                    "EnableLoopbackPrevention": true,
                    "SourceSchema": "",
                    "SourceTable": ""
                },
                "BeforeImageSettings": {
                    "EnableBeforeImage": false
                },
                "ErrorBehavior": {
                    "DataErrorPolicy": "LOG_ERROR",
                    "DataTruncationErrorPolicy": "LOG_ERROR",
                    "DataErrorEscalationPolicy": "SUSPEND_TABLE",
                    "DataErrorEscalationCount": 0,
                    "TableErrorPolicy": "SUSPEND_TABLE",
                    "TableErrorEscalationPolicy": "STOP_TASK",
                    "TableErrorEscalationCount": 0,
                    "RecoverableErrorCount": -1,
                    "RecoverableErrorInterval": 5,
                    "RecoverableErrorThrottling": true,
                    "RecoverableErrorThrottlingMax": 1800,
                    "ApplyErrorDeletePolicy": "IGNORE_RECORD",
                    "ApplyErrorInsertPolicy": "LOG_ERROR",
                    "ApplyErrorUpdatePolicy": "LOG_ERROR",
                    "ApplyErrorEscalationPolicy": "LOG_ERROR",
                    "ApplyErrorEscalationCount": 0,
                    "ApplyErrorFailOnTruncationDdl": false,
                    "FullLoadIgnoreConflicts": true,
                    "FailOnTransactionConsistencyBreached": false,
                    "FailOnNoTablesCaptured": false
                },
                "ValidationSettings": {
                    "EnableValidation": false,
                    "ValidationMode": "ROW_LEVEL",
                    "ThreadCount": 5,
                    "PartitionSize": 10000,
                    "FailureMaxCount": 10000,
                    "RecordFailureDelayInMinutes": 0,
                    "RecordSuspendDelayInMinutes": 30,
                    "MaxKeyColumnSize": 8096,
                    "TableFailureMaxCount": 1000,
                    "ValidationOnly": false,
                    "HandleCollationDiff": false,
                    "RecordFailureDelayLimitInMinutes": 0
                }
            }
            '''
        )
        print("Tarefa de replicação criada com sucesso!")
    except dms.exceptions.ResourceAlreadyExistsException:
        print("Tarefa de replicação já existe. Continuando...")
    except Exception as e:
        print(f"Erro ao criar tarefa de replicação: {e}")
        return

    print("\n✅ Configuração do DMS concluída com sucesso!")
    print("\nPróximos passos:")
    print("1. Inicie a tarefa de replicação com o comando:")
    print("   aws --endpoint-url=http://localhost:4566 dms start-replication-task \\")
    print("     --replication-task-arn arn:aws:dms:us-east-1:000000000000:task:mysql-to-s3-task \\")
    print("     --start-replication-task-type start-replication")
    print("\n2. Monitore o status da tarefa com:")
    print("   aws --endpoint-url=http://localhost:4566 dms describe-replication-tasks")
    print("\n3. Acesse os dados no bucket S3 'raw-data/dms/'")

if __name__ == "__main__":
    print("Configurando ambiente DMS no LocalStack...")
    create_dms_resources()
