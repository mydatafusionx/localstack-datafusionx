# Pipeline de Dados com LocalStack

Este projeto implementa um pipeline de dados completo utilizando LocalStack para simular serviços AWS localmente. O pipeline inclui:

- **Ingestão de dados** com AWS DMS (Database Migration Service)
- **Armazenamento** com S3
- **Processamento** com Glue e PyIceberg
- **Modelagem** com dbt
- **Consulta** com Athena
- **Orquestração** com Step Functions

## Estrutura do Projeto

```
.
├── dbt/                    # Modelos dbt
│   ├── models/            
│   │   ├── staging/       # Modelos de staging
│   │   └── marts/         # Modelos analíticos
│   ├── tests/             # Testes de dados
│   └── dbt_project.yml    # Configuração do dbt
├── glue_scripts/          # Scripts do AWS Glue
├── notebooks/             # Jupyter notebooks para análise
├── scripts/               # Scripts de inicialização
├── step_functions/        # Definições de máquinas de estado
├── docker-compose.yml     # Configuração do Docker Compose
├── Dockerfile             # Configuração do ambiente de desenvolvimento
├── pyproject.toml         # Dependências do projeto
└── README.md              # Este arquivo
```

## Pré-requisitos

- Docker e Docker Compose
- Python 3.9+
- AWS CLI (opcional, para interação com LocalStack)

## Configuração Inicial

1. Clone o repositório:
   ```bash
   git clone <seu-repositorio>
   cd data-pipeline-localstack
   ```

2. Crie um ambiente virtual e instale as dependências:
   ```bash
   python -m venv venv
   source venv/bin/activate  # No Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. Inicie os contêineres:
   ```bash
   docker-compose up -d
   ```

4. Execute o script de inicialização para configurar os recursos:
   ```bash
   docker exec -it localstack /docker-entrypoint-initaws.d/init.sh
   ```

## Como Usar

### Ingestão de Dados com DMS

1. Configure uma conexão de origem (source) para o banco de dados MySQL local
2. Crie um endpoint de destino (target) para o S3
3. Crie e inicie uma tarefa de replicação

### Processamento com PyIceberg

Execute o script de processamento:

```bash
python glue_scripts/process_with_iceberg.py
```

### Modelagem com dbt

1. Navegue até o diretório dbt:
   ```bash
   cd dbt
   ```

2. Execute os modelos dbt:
   ```bash
   dbt run
   ```

3. Execute os testes:
   ```bash
   dbt test
   ```

### Análise com Jupyter Notebooks

1. Acesse o Jupyter Lab em: http://localhost:8888
2. Navegue até `notebooks/data_analysis.ipynb`
3. Execute as células para análise interativa

## Orquestração com Step Functions

O projeto inclui uma máquina de estado do Step Functions que pode ser visualizada e gerenciada através do console do LocalStack em:

http://localhost:8080/aws/stepfunctions

## Monitoramento

- **LocalStack Web UI**: http://localhost:8080
- **Jupyter Lab**: http://localhost:8888

## Solução de Problemas

### Limpar o ambiente

Para reiniciar completamente o ambiente:

```bash
docker-compose down -v
rm -rf .localstack/
```

### Verificar logs

```bash
docker-compose logs -f
```

## Licença

MIT
