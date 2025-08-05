# Use a imagem base do Python
FROM python:3.9-slim

# Define variáveis de ambiente
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    POETRY_VERSION=1.4.2

# Instala dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Instala o Poetry
RUN pip install "poetry==$POETRY_VERSION"

# Configura o diretório de trabalho
WORKDIR /app

# Copia os arquivos de dependências
COPY pyproject.toml poetry.lock* ./

# Instala as dependências do projeto
RUN poetry config virtualenvs.create false \
    && poetry install --no-interaction --no-ansi --no-root

# Copia o código-fonte
COPY . .

# Instala o projeto
RUN poetry install --no-interaction --no-ansi

# Expõe a porta do Jupyter
EXPOSE 8888

# Comando padrão para iniciar o Jupyter Lab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
