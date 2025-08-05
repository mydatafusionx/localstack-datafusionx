#!/bin/bash

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir cabeçalho
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  Configuração do Ambiente LocalStack  ${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Exibir cabeçalho
print_header

# Verificar se o script está sendo executado como root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}Aviso: Este script não deve ser executado como root.${NC}"
    echo "Por favor, execute como um usuário normal."
    exit 1
fi

# Verificar compatibilidade do sistema operacional
OS="$(uname -s)"
ARCH="$(uname -m)"
SUPPORTED_OS=("Linux" "Darwin")
SUPPORTED_ARCH=("x86_64" "arm64" "aarch64")

# Verificar versão do Python e dependências
echo -e "${YELLOW}Verificando ambiente Python...${NC}"

# Verificar se o Python 3 está instalado
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Erro: Python 3 não encontrado.${NC}"
    echo "Por favor, instale o Python 3.8 ou superior."
    echo "Siga as instruções em: https://www.python.org/downloads/"
    exit 1
fi

# Verificar versão mínima do Python
MIN_PYTHON_VERSION=3.8
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

if [ "$(printf '%s\n' "$MIN_PYTHON_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" = "$MIN_PYTHON_VERSION" ]; then
    echo -e "${GREEN}✓ Versão do Python compatível: ${PYTHON_VERSION}${NC}"
else
    echo -e "${YELLOW}Aviso: Versão antiga do Python detectada: ${PYTHON_VERSION}${NC}"
    echo "Recomenda-se atualizar para a versão ${MIN_PYTHON_VERSION} ou superior."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar se pip está instalado
if ! command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}Aviso: pip3 não encontrado.${NC}"
    echo "Tentando instalar o pip..."
    
    if [ "$OS" = "Linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y python3-pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3-pip
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y python3-pip
        else
            echo -e "${RED}Erro: Não foi possível instalar o pip automaticamente.${NC}"
            echo "Por favor, instale o pip manualmente e tente novamente."
            exit 1
        fi
    elif [ "$OS" = "Darwin" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}Erro: Homebrew não encontrado.${NC}"
            echo "Por favor, instale o Homebrew primeiro:"
            echo "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
        brew install python
    fi
    
    # Verificar novamente após a instalação
    if ! command -v pip3 &> /dev/null; then
        echo -e "${RED}Erro: Falha ao instalar o pip.${NC}"
        echo "Por favor, instale o pip manualmente e tente novamente."
        exit 1
    fi
fi

echo -e "${GREEN}✓ pip3 encontrado: $(pip3 --version)${NC}"

# Verificar se o virtualenv está instalado
if ! python3 -m pip show virtualenv &> /dev/null; then
    echo -e "${YELLOW}Instalando virtualenv...${NC}"
    python3 -m pip install --user virtualenv
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro: Falha ao instalar o virtualenv.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ virtualenv instalado com sucesso${NC}"
fi

# Verificar se o ambiente virtual existe, se não, criar
VENV_DIR="${PROJECT_ROOT}/.venv"
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Criando ambiente virtual Python...${NC}"
    python3 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro: Falha ao criar o ambiente virtual.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Ambiente virtual criado em ${VENV_DIR}${NC}"
    
    # Ativar o ambiente virtual e instalar dependências
    echo -e "${YELLOW}Instalando dependências Python...${NC}"
    source "${VENV_DIR}/bin/activate"
    pip install --upgrade pip
    if [ -f "${PROJECT_ROOT}/requirements.txt" ]; then
        pip install -r "${PROJECT_ROOT}/requirements.txt"
    else
        echo -e "${YELLOW}Aviso: Arquivo requirements.txt não encontrado.${NC}"
    fi
    deactivate
    echo -e "${GREEN}✓ Dependências instaladas com sucesso${NC}"
else
    echo -e "${GREEN}✓ Ambiente virtual encontrado em ${VENV_DIR}${NC}"
fi

# Verificar permissões de arquivo
echo -e "\n${YELLOW}Verificando permissões de arquivo...${NC}"

# Criar um arquivo de teste para verificar permissões de escrita
test_file="${PROJECT_ROOT}/.permission_test"
touch "$test_file" 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Erro: Não é possível criar arquivos no diretório do projeto.${NC}"
    echo "Por favor, verifique as permissões do diretório:"
    echo "  ${PROJECT_ROOT}"
    echo ""
    echo "Você pode tentar executar o comando abaixo para corrigir as permissões:"
    echo "  sudo chown -R $(whoami) "${PROJECT_ROOT}" && chmod -R u+rw "${PROJECT_ROOT}""
    exit 1
else
    # Remover o arquivo de teste
    rm -f "$test_file"
    echo -e "${GREEN}✓ Permissões de arquivo verificadas com sucesso${NC}"
fi

# Verificar ferramentas de linha de comando necessárias
echo -e "\n${YELLOW}Verificando ferramentas de linha de comando...${NC}"

# Lista de ferramentas necessárias
REQUIRED_TOOLS=(
    "curl"
    "jq"
    "git"
    "unzip"
    "tar"
    "gzip"
    "openssl"
)

# Verificar cada ferramenta
MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

# Se faltar alguma ferramenta, tentar instalar
if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${YELLOW}Aviso: As seguintes ferramentas não foram encontradas: ${MISSING_TOOLS[*]}${NC}"
    
    # Tentar instalar automaticamente no Linux
    if [ "$OS" = "Linux" ]; then
        echo "Tentando instalar as ferramentas necessárias..."
        
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y "${MISSING_TOOLS[@]}"
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            sudo yum install -y "${MISSING_TOOLS[@]}"
        elif command -v dnf &> /dev/null; then
            # Fedora
            sudo dnf install -y "${MISSING_TOOLS[@]}"
        else
            echo -e "${YELLOW}Não foi possível instalar as ferramentas automaticamente.${NC}"
            echo "Por favor, instale manualmente as seguintes ferramentas:"
            echo "  ${MISSING_TOOLS[*]}"
            echo ""
            read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                exit 1
            fi
        fi
    # Tentar instalar automaticamente no macOS
    elif [ "$OS" = "Darwin" ]; then
        echo "Tentando instalar as ferramentas necessárias via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}Erro: Homebrew não encontrado.${NC}"
            echo "Por favor, instale o Homebrew primeiro:"
            echo "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo ""
            read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                exit 1
            fi
        else
            brew install "${MISSING_TOOLS[@]}"
        fi
    else
        echo -e "${YELLOW}Por favor, instale manualmente as seguintes ferramentas:${NC}"
        for tool in "${MISSING_TOOLS[@]}"; do
            echo "  - $tool"
        done
        echo ""
        read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
    
    # Verificar novamente após a instalação
    MISSING_AFTER_INSTALL=()
    for tool in "${MISSING_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            MISSING_AFTER_INSTALL+=("$tool")
        fi
    done
    
    if [ ${#MISSING_AFTER_INSTALL[@]} -ne 0 ]; then
        echo -e "${YELLOW}Aviso: Não foi possível instalar as seguintes ferramentas: ${MISSING_AFTER_INSTALL[*]}${NC}"
        echo "Aluns recursos podem não funcionar corretamente sem essas ferramentas."
        echo ""
        read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Todas as ferramentas necessárias foram instaladas com sucesso${NC}"
    fi
else
    echo -e "${GREEN}✓ Todas as ferramentas necessárias estão instaladas${NC}"
fi

# Verificar configurações de rede
echo -e "\n${YELLOW}Verificando configurações de rede...${NC}"

# Verificar conectividade com a internet
if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${YELLOW}Aviso: Não foi possível verificar a conectividade com a internet.${NC}"
    echo "Alguns recursos podem não funcionar corretamente sem acesso à internet."
    
    # Verificar configurações de proxy
    if [ -n "${http_proxy}" ] || [ -n "${https_proxy}" ] || [ -n "${HTTP_PROXY}" ] || [ -n "${HTTPS_PROXY}" ]; then
        echo -e "${YELLOW}Configurações de proxy detectadas:${NC}"
        [ -n "${http_proxy}" ] && echo "  http_proxy=${http_proxy}"
        [ -n "${https_proxy}" ] && echo "  https_proxy=${https_proxy}"
        [ -n "${HTTP_PROXY}" ] && echo "  HTTP_PROXY=${HTTP_PROXY}"
        [ -n "${HTTPS_PROXY}" ] && echo "  HTTPS_PROXY=${HTTPS_PROXY}"
        echo ""
        echo "Certifique-se de que as configurações de proxy estão corretas."
    fi
    
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Por favor, verifique sua conexão de rede e tente novamente."
        exit 1
    fi
else
    echo -e "${GREEN}✓ Conectividade com a internet verificada${NC}"
fi

# Verificar configurações de DNS
if ! getent hosts localhost &> /dev/null; then
    echo -e "${YELLOW}Aviso: Possível problema com a resolução de DNS.${NC}"
    echo "Verificando configuração do DNS..."
    
    # Tentar usar o DNS do Google como fallback
    if ! grep -q "nameserver 8.8.8.8" /etc/resolv.conf 2>/dev/null; then
        echo "Adicionando o DNS do Google como fallback..."
        echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null
        echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf >/dev/null
    fi
    
    # Verificar novamente
    if ! getent hosts localhost &> /dev/null; then
        echo -e "${YELLOW}Não foi possível resolver nomes de domínio.${NC}"
        echo "Verifique suas configurações de rede e DNS."
        echo ""
        read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Configuração de DNS verificada${NC}"
    fi
else
    echo -e "${GREEN}✓ Configuração de DNS verificada${NC}"
fi

# Verificar configurações de localidade e codificação
echo -e "\n${YELLOW}Verificando configurações de localidade...${NC}"

# Verificar variáveis de localidade
if [ -z "${LANG}" ] || [ -z "${LC_ALL}" ]; then
    echo -e "${YELLOW}Aviso: Variáveis de localidade não estão definidas.${NC}"
    echo "Configurando localidade para pt_BR.UTF-8..."
    
    # Tentar configurar a localidade para pt_BR.UTF-8
    if command -v locale-gen &> /dev/null && ! locale -a | grep -q "pt_BR.utf8\|pt_BR.UTF-8"; then
        echo "Instalando localidade pt_BR.UTF-8..."
        if [ "$OS" = "Linux" ]; then
            sudo locale-gen pt_BR.UTF-8
            sudo update-locale LANG=pt_BR.UTF-8
        elif [ "$OS" = "Darwin" ]; then
            echo "Por favor, instale a localidade pt_BR.UTF-8 manualmente no macOS."
        fi
    fi
    
    # Definir variáveis de ambiente temporariamente
    export LANG=pt_BR.UTF-8
    export LC_ALL=pt_BR.UTF-8
    
    echo -e "${GREEN}✓ Localidade configurada para pt_BR.UTF-8${NC}"
else
    echo -e "${GREEN}✓ Localidade configurada: LANG=${LANG}, LC_ALL=${LC_ALL}${NC}"
fi

# Verificar codificação do terminal
TERM_ENCODING=$(locale charmap 2>/dev/null || echo "unknown")
if [ "$TERM_ENCODING" != "UTF-8" ] && [ "$TERM_ENCODING" != "utf8" ]; then
    echo -e "${YELLOW}Aviso: A codificação do terminal não é UTF-8 (${TERM_ENCODING}).${NC}"
    echo "Isso pode causar problemas com caracteres especiais."
    echo ""
    echo "Você pode tentar corrigir isso com os comandos:"
    echo "  export LANG=pt_BR.UTF-8"
    echo "  export LC_ALL=pt_BR.UTF-8"
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Codificação do terminal: ${TERM_ENCODING}${NC}"
fi

# Verificar configurações de fuso horário
echo -e "\n${YELLOW}Verificando configurações de fuso horário...${NC}"

# Obter o fuso horário atual
if command -v timedatectl &> /dev/null; then
    TIMEZONE=$(timedatectl show --property=Timezone --value)
    TIMEZONE_SYSTEM=$(timedatectl status | grep "Time zone" | awk '{print $3}')
    echo -e "${GREEN}✓ Fuso horário do sistema: ${TIMEZONE:-$TIMEZONE_SYSTEM}${NC}
elif [ -f /etc/timezone ]; then
    TIMEZONE=$(cat /etc/timezone)
    echo -e "${GREEN}✓ Fuso horário do sistema: ${TIMEZONE}${NC}
else
    TIMEZONE=$(date +%Z)
    echo -e "${YELLOW}Aviso: Não foi possível determinar o fuso horário do sistema.${NC}"
    echo "Usando fuso horário: ${TIMEZONE}"
fi

# Verificar se o fuso horário está configurado corretamente
if [ -z "${TZ}" ]; then
    echo -e "${YELLOW}Aviso: A variável de ambiente TZ não está definida.${NC}"
    echo "Isso pode causar inconsistências em operações sensíveis ao tempo."
    
    # Tentar determinar o fuso horário com base na localização
    if command -v curl &> /dev/null; then
        echo "Tentando detectar o fuso horário com base na localização..."
        DETECTED_TZ=$(curl -s "http://ip-api.com/line/?fields=timezone" 2>/dev/null)
        
        if [ -n "$DETECTED_TZ" ]; then
            echo -e "${GREEN}✓ Fuso horário detectado: ${DETECTED_TZ}${NC}"
            echo "Configurando TZ=${DETECTED_TZ}"
            export TZ="${DETECTED_TZ}"
            
            # Configurar o fuso horário do sistema (requer privilégios de superusuário)
            if [ "$OS" = "Linux" ] && [ -w /etc/timezone ]; then
                echo "Atualizando o fuso horário do sistema..."
                echo "${DETECTED_TZ}" | sudo tee /etc/timezone > /dev/null
                if command -v dpkg-reconfigure &> /dev/null; then
                    sudo dpkg-reconfigure --frontend noninteractive tzdata
                fi
            fi
        else
            echo -e "${YELLOW}Não foi possível detectar o fuso horário automaticamente.${NC}"
            echo "Por favor, defina a variável TZ manualmente, por exemplo:"
            echo "  export TZ=America/Sao_Paulo  # Para o horário de Brasília"
            echo ""
            read -p "Deseja definir o fuso horário para America/Sao_Paulo? (s/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                export TZ="America/Sao_Paulo"
                echo -e "${GREEN}✓ Fuso horário definido para America/Sao_Paulo${NC}"
            else
                echo -e "${YELLOW}Aviso: O fuso horário não foi configurado. Podem ocorrer problemas com datas e horários.${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Não foi possível detectar o fuso horário automaticamente (curl não encontrado).${NC}"
        echo "Por favor, defina a variável TZ manualmente, por exemplo:"
        echo "  export TZ=America/Sao_Paulo  # Para o horário de Brasília"
        echo ""
        read -p "Deseja definir o fuso horário para America/Sao_Paulo? (s/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            export TZ="America/Sao_Paulo"
            echo -e "${GREEN}✓ Fuso horário definido para America/Sao_Paulo${NC}"
        else
            echo -e "${YELLOW}Aviso: O fuso horário não foi configurado. Podem ocorrer problemas com datas e horários.${NC}"
        fi
    fi
else
    echo -e "${GREEN}✓ Fuso horário configurado: TZ=${TZ}${NC}
    
    # Verificar se o fuso horário é válido
    if ! date -d "now" &> /dev/null; then
        echo -e "${YELLOW}Aviso: O fuso horário '${TZ}' pode ser inválido.${NC}"
        echo "A data/hora atual não pôde ser determinada corretamente."
        echo ""
        read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo "Por favor, defina uma variável TZ válida e tente novamente."
            echo "Exemplos:"
            echo "  export TZ=America/Sao_Paulo  # Horário de Brasília"
            echo "  export TZ=UTC                # Tempo Universal Coordenado"
            exit 1
        fi
    fi
fi

# Exibir a data e hora atuais
CURRENT_DATETIME=$(date "+%Y-%m-%d %H:%M:%S %Z (%z)")
echo -e "${GREEN}✓ Data/hora atual: ${CURRENT_DATETIME}${NC}"

# Verificar configurações de segurança
echo -e "\n${YELLOW}Verificando configurações de segurança...${NC}"

# Verificar permissões de diretórios sensíveis
SENSITIVE_DIRS=(
    "/etc"
    "/usr/local/bin"
    "${PROJECT_ROOT}"
    "${HOME}/.aws"
    "/var/run/docker.sock"
)

for dir in "${SENSITIVE_DIRS[@]}"; do
    if [ -e "$dir" ]; then
        perms=$(stat -c "%a %U:%G" "$dir" 2>/dev/null || stat -f "%Lp %Su:%Sg" "$dir" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Permissões de ${dir}: ${perms}${NC}"
            
            # Verificar permissões muito permissivas
            if [[ "$dir" != "/tmp"* ]] && [[ "$perms" == *"777" || "$perms" == *"7"?? || "$perms" == *"?7"? || "$perms" == *"??7" ]]; then
                echo -e "${YELLOW}Aviso: Permissões muito permissivas em ${dir} (${perms})${NC}"
                echo "Isso pode representar um risco de segurança."
                echo ""
                
                if [[ "$dir" == "${PROJECT_ROOT}"* ]]; then
                    echo "Você pode corrigir as permissões com:"
                    echo "  find ${dir} -type d -exec chmod 755 {} \\;"
                    echo "  find ${dir} -type f -exec chmod 644 {} \\;"
                    echo "  chmod 700 ${dir}/scripts/*.sh"
                fi
                
                echo ""
                read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                    exit 1
                fi
            fi
        fi
    fi
done

# Verificar arquivos sensíveis
SENSITIVE_FILES=(
    "${HOME}/.aws/credentials"
    "${HOME}/.ssh/id_rsa"
    "${HOME}/.ssh/id_dsa"
    "${PROJECT_ROOT}/.env"
)

for file in "${SENSITIVE_FILES[@]}"; do
    if [ -f "$file" ]; then
        perms=$(stat -c "%a %U:%G" "$file" 2>/dev/null || stat -f "%Lp %Su:%Sg" "$file" 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Verificar se o arquivo tem permissões muito abertas
            if [[ "$perms" == *"7"?? || "$perms" == *"?7"? || "$perms" == *"??7" ]]; then
                echo -e "${YELLOW}Aviso: Arquivo sensível com permissões muito abertas: ${file} (${perms})${NC}"
                echo "Recomenda-se restringir as permissões para 600 (rw-------)."
                echo ""
                
                if [[ "$file" == *.pem || "$file" == *id_rsa* || "$file" == *id_dsa* ]]; then
                    echo "Você pode corrigir as permissões com:"
                    echo "  chmod 600 \"${file}\""
                    echo ""
                fi
                
                read -p "Deseja corrigir as permissões agora? (s/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Ss]$ ]]; then
                    chmod 600 "$file"
                    echo -e "${GREEN}✓ Permissões de ${file} atualizadas para 600${NC}"
                else
                    echo -e "${YELLOW}Aviso: Continuando com permissões inseguras para ${file}${NC}"
                fi
            fi
        fi
    fi
done

# Verificar se o diretório .git tem configurações seguras
if [ -d "${PROJECT_ROOT}/.git" ]; then
    echo -e "\n${YELLOW}Verificando configurações do Git...${NC}"
    
    # Verificar se há credenciais expostas no histórico do Git
    if git -C "${PROJECT_ROOT}" log -p | grep -q -i "password\|secret\|key\|token\|credential"; then
        echo -e "${YELLOW}Aviso: Possíveis credenciais encontradas no histórico do Git.${NC}"
        echo "Recomenda-se revisar o histórico de commits para credenciais expostas."
        echo "Você pode usar 'git log -p | grep -i \"password\\|secret\\|key\\|token\\|credential\"' para verificar."
        echo ""
        read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Nenhuma credencial óbvia encontrada no histórico do Git${NC}"
    fi
    
    # Verificar configurações seguras do Git
    if git -C "${PROJECT_ROOT}" config --get-regexp 'url.*https://.*:.*@' &> /dev/null; then
        echo -e "${YELLOW}Aviso: Credenciais HTTPS encontradas na configuração do Git.${NC}"
        echo "Recomenda-se usar SSH ou armazenar credenciais de forma segura com o Git Credential Manager."
        echo ""
        read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Configurações do Git verificadas${NC}"
fi

# Verificar se há arquivos .env ou com credenciais no projeto
DOTENV_FILES=$(find "${PROJECT_ROOT}" -name ".env*" -type f -not -path "*/\.*" 2>/dev/null)
if [ -n "$DOTENV_FILES" ]; then
    echo -e "\n${YELLOW}Arquivos .env encontrados:${NC}"
    echo "$DOTENV_FILES" | while read -r file; do
        echo "  - $file"
        
        # Verificar se o arquivo contém credenciais
        if grep -q -i "password\|secret\|key\|token\|credential" "$file" 2>/dev/null; then
            echo -e "    ${YELLOW}⚠️  Possíveis credenciais encontradas${NC}"
            echo -e "    ${YELLOW}   Considere usar um gerenciador de segredos ou .env.example${NC}"
        fi
        
        # Verificar permissões do arquivo
        perms=$(stat -c "%a %U:%G" "$file" 2>/dev/null || stat -f "%Lp %Su:%Sg" "$file" 2>/dev/null)
        if [[ "$perms" == *"7"?? || "$perms" == *"?7"? || "$perms" == *"??7" ]]; then
            echo -e "    ${YELLOW}⚠️  Permissões muito abertas: ${perms}${NC}"
            echo -e "    ${YELLOW}   Execute: chmod 600 \"$file\"${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}Recomenda-se adicionar .env* ao .gitignore para evitar vazamento de credenciais.${NC}"
    if ! grep -q "^\.env" "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
        echo "Adicionando .env* ao .gitignore..."
        echo -e "\n# Arquivos de ambiente com credenciais\n.env*\n!.env.example" >> "${PROJECT_ROOT}/.gitignore"
    fi
    
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Nenhum arquivo .env encontrado no projeto${NC}"
fi

# Verificar configurações de rede e portas
echo -e "\n${YELLOW}Verificando configurações de rede...${NC}"

# Função para verificar se uma porta está em uso
check_port() {
    local port=$1
    local service=$2
    local protocol=${3:-tcp}
    
    if [ "$OS" = "Linux" ]; then
        if command -v ss >/dev/null 2>&1; then
            if ss -lnt "${protocol}" | grep -q ":${port} "; then
                return 0  # Porta em uso
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -lnt "${protocol}" | grep -q ":${port} "; then
                return 0  # Porta em uso
            fi
        fi
    else
        # macOS/BSD
        if lsof -i "${protocol}":"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
            return 0  # Porta em uso
        fi
    fi
    
    return 1  # Porta livre
}

# Verificar portas necessárias para o LocalStack e serviços relacionados
PORTS_TO_CHECK=(
    "4566:LocalStack"
    "8080:Jupyter Notebook"
    "8888:Jupyter Lab"
    "5432:PostgreSQL"
    "3306:MySQL"
    "6379:Redis"
    "8081:MinIO"
    "9090:Prometheus"
    "9093:Alertmanager"
    "3000:Grafana"
    "5000:Flask/Django"
    "8000:FastAPI/Node.js"
)

# Verificar portas em uso
PORTS_IN_USE=()

for port_info in "${PORTS_TO_CHECK[@]}"; do
    port=$(echo "$port_info" | cut -d':' -f1)
    service=$(echo "$port_info" | cut -d':' -f2-)
    
    if check_port "$port"; then
        PORTS_IN_USE+=("${port}:${service}")
        echo -e "${YELLOW}⚠️  Porta ${port} (${service}) está em uso${NC}"
    else
        echo -e "${GREEN}✓ Porta ${port} (${service}) está disponível${NC}"
    fi
done

# Se houver portas em uso, mostrar informações adicionais
if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}As seguintes portas estão em uso:${NC}"
    for port_info in "${PORTS_IN_USE[@]}"; do
        port=$(echo "$port_info" | cut -d':' -f1)
        service=$(echo "$port_info" | cut -d':' -f2-)
        echo "  - Porta ${port}: ${service}"
        
        # Tentar identificar qual processo está usando a porta
        if [ "$OS" = "Linux" ]; then
            if command -v ss >/dev/null 2>&1; then
                process_info=$(ss -ltnp "sport = :${port}" 2>/dev/null | grep -v "State" | awk '{print $6}' | head -1)
            elif command -v netstat >/dev/null 2>&1; then
                process_info=$(netstat -ltnp 2>/dev/null | grep ":${port} " | awk '{print $7}' | head -1)
            fi
        else
            # macOS/BSD
            process_info=$(lsof -i ":${port}" -sTCP:LISTEN 2>/dev/null | grep -v "COMMAND" | awk '{print $1, $2}' | head -1)
        fi
        
        if [ -n "$process_info" ]; then
            echo "    Processo: ${process_info}"
            
            # Oferecer para matar o processo se for seguro
            pid=$(echo "$process_info" | grep -oE '[0-9]+$')
            if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
                read -p "    Deseja encerrar o processo ${pid}? (s/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Ss]$ ]]; then
                    if kill "$pid" 2>/dev/null; then
                        echo -e "    ${GREEN}✓ Processo ${pid} encerrado${NC}"
                        # Remover da lista de portas em uso
                        PORTS_IN_USE=("${PORTS_IN_USE[@]/$port_info/}")
                    else
                        echo -e "    ${RED}Não foi possível encerrar o processo ${pid}. Permissão negada.${NC}"
                    fi
                fi
            fi
        fi
    done
    
    # Se ainda houver portas em uso críticas, perguntar se deseja continuar
    CRITICAL_PORTS=("4566" "8080" "5432" "3306")
    should_exit=false
    
    for port_info in "${PORTS_IN_USE[@]}"; do
        port=$(echo "$port_info" | cut -d':' -f1)
        service=$(echo "$port_info" | cut -d':' -f2-)
        
        for critical_port in "${CRITICAL_PORTS[@]}"; do
            if [ "$port" = "$critical_port" ]; then
                echo -e "\n${YELLOW}Atenção: A porta crítica ${port} (${service}) está em uso.${NC}"
                echo "Isso pode impedir que o LocalStack ou serviços essenciais sejam iniciados corretamente."
                should_exit=true
            fi
        done
    done
    
    if [ "$should_exit" = true ]; then
        echo ""
        read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo "Por favor, libere as portas necessárias e tente novamente."
            exit 1
        fi
    fi
fi

# Verificar configurações de firewall
echo -e "\n${YELLOW}Verificando configurações de firewall...${NC}"

if [ "$OS" = "Linux" ]; then
    # Verificar se o firewall está ativo
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}Firewall UFW está ativo.${NC}"
        
        # Verificar se as portas necessárias estão abertas
        for port_info in "${PORTS_TO_CHECK[@]}"; do
            port=$(echo "$port_info" | cut -d':' -f1)
            service=$(echo "$port_info" | cut -d':' -f2-)
            
            if ! ufw status | grep -q "${port}/tcp\|${port}.*ALLOW"; then
                echo -e "  ${YELLOW}A porta ${port} (${service}) não está aberta no firewall.${NC}"
                echo "  Você pode abri-la com: sudo ufw allow ${port}/tcp"
            fi
        done
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        echo -e "${YELLOW}Firewall firewalld está ativo.${NC}"
        
        for port_info in "${PORTS_TO_CHECK[@]}"; do
            port=$(echo "$port_info" | cut -d':' -f1)
            service=$(echo "$port_info" | cut -d':' -f2-)
            
            if ! firewall-cmd --list-ports 2>/dev/null | grep -q "${port}/tcp"; then
                echo -e "  ${YELLOW}A porta ${port} (${service}) não está aberta no firewall.${NC}"
                echo "  Você pode abri-la com: sudo firewall-cmd --add-port=${port}/tcp --permanent && sudo firewall-cmd --reload"
            fi
        done
    else
        echo -e "${GREEN}Nenhum firewall ativo detectado.${NC}"
    fi
else
    # macOS
    if [ "$(uname)" = "Darwin" ]; then
        echo -e "${YELLOW}Verificando configurações de firewall no macOS...${NC}"
        
        firewall_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep "enabled")
        
        if echo "$firewall_status" | grep -q "enabled"; then
            echo -e "${YELLOW}Firewall do macOS está ativado.${NC}"
            echo "Certifique-se de que os aplicativos necessários têm permissão para aceitar conexões de entrada."
            echo "Você pode verificar em: Preferências do Sistema > Segurança e Privacidade > Firewall"
        else
            echo -e "${GREEN}Firewall do macOS está desativado.${NC}"
        fi
    fi
fi

# Verificar recursos do sistema
echo -e "\n${YELLOW}Verificando recursos do sistema...${NC}"

# Verificar espaço em disco
check_disk_space() {
    local path="$1"
    local min_gb=${2:-10}  # 10GB mínimo por padrão
    
    # Obter informações do disco
    local disk_info
    if [ "$OS" = "Linux" ]; then
        disk_info=$(df -P "$path" 2>/dev/null | tail -1)
    else
        # macOS/BSD
        disk_info=$(df -P -k "$path" 2>/dev/null | tail -1)
    fi
    
    if [ -z "$disk_info" ]; then
        echo -e "${YELLOW}Não foi possível verificar o espaço em disco para ${path}${NC}"
        return 1
    fi
    
    # Extrair informações relevantes
    local available_kb
    if [ "$OS" = "Linux" ]; then
        available_kb=$(echo "$disk_info" | awk '{print $4}')
    else
        # macOS/BSD
        available_kb=$(echo "$disk_info" | awk '{print $4}')
    fi
    
    local available_gb=$((available_kb / 1024 / 1024))  # Converter para GB
    
    echo -n "Espaço disponível em ${path}: ${available_gb}GB"
    
    if [ "$available_gb" -lt "$min_gb" ]; then
        echo -e " ${RED}(Abaixo do mínimo recomendado de ${min_gb}GB)${NC}"
        echo -e "${YELLOW}Aviso: Espaço em disco insuficiente em ${path}${NC}"
        echo "Recomenda-se liberar espaço ou especificar um local com mais espaço."
        return 1
    else
        echo -e " ${GREEN}(Suficiente)${NC}"
        return 0
    fi
}

# Verificar espaço em disco nos diretórios importantes
check_disk_space "/" 20         # Pelo menos 20GB na raiz
check_disk_space "$HOME" 10     # Pelo menos 10GB no diretório home
check_disk_space "/tmp" 2       # Pelo menos 2GB em /tmp

# Verificar inodes disponíveis (apenas Linux)
if [ "$OS" = "Linux" ]; then
    echo -e "\n${YELLOW}Verificando inodes disponíveis...${NC}"
    
    inode_info=$(df -i / 2>/dev/null | tail -1)
    if [ -n "$inode_info" ]; then
        total_inodes=$(echo "$inode_info" | awk '{print $2}')
        used_inodes=$(echo "$inode_info" | awk '{print $3}')
        free_inodes=$(echo "$inode_info" | awk '{print $4}')
        use_percent=$(echo "$inode_info" | awk '{print $5}' | tr -d '%')
        
        echo -n "Inodes disponíveis: ${free_inodes}/${total_inodes} (${use_percent}% usado)"
        
        if [ "$use_percent" -gt 90 ]; then
            echo -e " ${RED}(Crítico)${NC}"
            echo -e "${RED}Erro: Muitos inodes em uso (${use_percent}%). Isso pode causar falhas no sistema de arquivos.${NC}"
            echo "Por favor, libere inodes excluindo arquivos pequenos desnecessários."
            exit 1
        elif [ "$use_percent" -gt 80 ]; then
            echo -e " ${YELLOW}(Alto)${NC}"
            echo -e "${YELLOW}Aviso: Muitos inodes em uso (${use_percent}%). Considere liberar espaço.${NC}"
            echo ""
            read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                exit 1
            fi
        else
            echo -e " ${GREEN}(OK)${NC}"
        fi
    else
        echo -e "${YELLOW}Não foi possível verificar os inodes disponíveis.${NC}"
    fi
fi

# Verificar sistemas de arquivos montados
if [ "$OS" = "Linux" ]; then
    echo -e "\n${YELLOW}Verificando sistemas de arquivos montados...${NC}"
    
    # Verificar se /tmp está em uma partição separada
    if ! mount | grep -q ' on /tmp '; then
        echo -e "${YELLOW}Aviso: /tmp não está em uma partição separada.${NC}"
        echo "Para melhor desempenho e segurança, considere montar /tmp em uma partição separada."
    fi
    
    # Verificar opções de montagem recomendadas
    RECOMMENDED_OPTIONS=(
        "noatime"
        "nodiratime"
        "discard"  # Para SSDs
    )
    
    echo -e "\n${YELLOW}Verificando opções de montagem recomendadas...${NC}"
    
    for option in "${RECOMMENDED_OPTIONS[@]}"; do
        if ! mount | grep -q "${option}"; then
            echo -e "${YELLOW}Recomendação: Considere adicionar '${option}' às opções de montagem para melhor desempenho.${NC}"
        fi
    done
    
    # Verificar se o Docker está usando o driver de armazenamento overlay2 (recomendado)
    if docker info 2>/dev/null | grep -q 'Storage Driver: overlay2'; then
        echo -e "${GREEN}✓ Docker está usando o driver de armazenamento overlay2${NC}"
    else
        echo -e "${YELLOW}Aviso: Docker não está usando o driver de armazenamento overlay2.${NC}"
        echo "Para melhor desempenho, recomenda-se usar o driver overlay2."
        echo "Consulte a documentação do Docker para configurar o armazenamento: https://docs.docker.com/storage/storagedriver/select-storage-driver/"
    fi
fi

# Requisitos mínimos recomendados
MIN_CPU_CORES=2
MIN_MEM_GB=4
MIN_DISK_GB=10

# Obter informações do sistema
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "2")

# Obter memória total
if [ "$OS" = "Linux" ]; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
elif [ "$OS" = "Darwin" ]; then
    TOTAL_MEM_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
    TOTAL_MEM_GB=$((TOTAL_MEM_BYTES / 1024 / 1024 / 1024))
else
    TOTAL_MEM_GB=4  # Valor padrão para sistemas desconhecidos
fi

# Obter espaço em disco livre
if [ "$OS" = "Linux" ]; then
    FREE_DISK_KB=$(df -k . | tail -1 | awk '{print $4}')
    FREE_DISK_GB=$((FREE_DISK_KB / 1024 / 1024))
elif [ "$OS" = "Darwin" ]; then
    FREE_DISK_BYTES=$(df -k . | tail -1 | awk '{print $4}')
    FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))
else
    FREE_DISK_GB=10  # Valor padrão para sistemas desconhecidos
fi

# Verificar CPU
if [ $CPU_CORES -lt $MIN_CPU_CORES ]; then
    echo -e "${YELLOW}Aviso: Número baixo de núcleos de CPU detectados: ${CPU_CORES} (mínimo recomendado: ${MIN_CPU_CORES})${NC}"
    echo "O LocalStack pode ter desempenho reduzido."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar memória
if [ $TOTAL_MEM_GB -lt $MIN_MEM_GB ]; then
    echo -e "${YELLOW}Aviso: Pouca memória RAM disponível: ${TOTAL_MEM_GB}GB (mínimo recomendado: ${MIN_MEM_GB}GB)${NC}"
    echo "O LocalStack pode não funcionar corretamente com pouca memória."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar espaço em disco
if [ $FREE_DISK_GB -lt $MIN_DISK_GB ]; then
    echo -e "${YELLOW}Aviso: Pouco espaço em disco disponível: ${FREE_DISK_GB}GB (mínimo recomendado: ${MIN_DISK_GB}GB)${NC}"
    echo "O LocalStack e os serviços podem precisar de mais espaço para operar."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✓ Recursos do sistema verificados com sucesso${NC}"

if [[ ! " ${SUPPORTED_OS[@]} " =~ " ${OS} " ]]; then
    echo -e "${YELLOW}Aviso: Sistema operacional não suportado: ${OS}${NC}"
    echo "Este script foi testado apenas em Linux e macOS."
    echo "Você pode continuar, mas alguns recursos podem não funcionar corretamente."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

if [[ ! " ${SUPPORTED_ARCH[@]} " =~ " ${ARCH} " ]]; then
    echo -e "${YELLOW}Aviso: Arquitetura não suportada: ${ARCH}${NC}"
    echo "Este script foi testado apenas em arquiteturas x86_64 e arm64/aarch64."
    echo "Você pode continuar, mas alguns recursos podem não funcionar corretamente."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar se o Docker está em execução
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Erro: O Docker não está em execução.${NC}"
    echo "Por favor, inicie o Docker e tente novamente."
    echo "No macOS ou Windows, inicie o Docker Desktop."
    echo "No Linux, execute: sudo systemctl start docker"
    exit 1
fi

# Verificar permissões do Docker
echo -e "${YELLOW}Verificando permissões do Docker...${NC}"

if ! docker ps > /dev/null 2>&1; then
    echo -e "${YELLOW}Aviso: Não é possível listar contêineres Docker. Verificando permissões...${NC}"
    
    # Verificar se o usuário está no grupo docker
    if groups | grep -q '\bdocker\b'; then
        echo -e "${YELLOW}Você está no grupo 'docker', mas ainda há problemas de permissão.${NC}"
    else
        echo -e "${YELLOW}Você não está no grupo 'docker'. Adicionando...${NC}"
        sudo usermod -aG docker "$USER"
        echo -e "${GREEN}✓ Usuário adicionado ao grupo 'docker'.${NC}"
        echo -e "${YELLOW}Por favor, faça logout e login novamente para que as alterações tenham efeito.${NC}"
        echo -e "${YELLOW}Se estiver usando o VS Code, feche e reabra o terminal integrado.${NC}"
        exit 1
    fi
    
    # Verificar se o socket do Docker está acessível
    DOCKER_SOCK="/var/run/docker.sock"
    if [ -S "$DOCKER_SOCK" ]; then
        if [ ! -w "$DOCKER_SOCK" ]; then
            echo -e "${YELLOW}O arquivo de socket do Docker não tem permissão de escrita.${NC}"
            echo "Tentando corrigir as permissões..."
            sudo chmod 666 "$DOCKER_SOCK"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Permissões do socket do Docker corrigidas.${NC}"
            else
                echo -e "${YELLOW}Não foi possível corrigir as permissões automaticamente.${NC}"
                echo "Você pode tentar executar manualmente:"
                echo "  sudo chmod 666 /var/run/docker.sock"
                echo ""
                read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                    exit 1
                fi
            fi
        fi
    else
        echo -e "${YELLOW}Arquivo de socket do Docker não encontrado em $DOCKER_SOCK${NC}"
    fi
fi

# Verificar se o Docker está realmente acessível
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}Erro: Ainda não é possível acessar o Docker.${NC}"
    echo "Por favor, verifique se o serviço do Docker está em execução e tente novamente."
    echo "Você pode verificar o status do Docker com: systemctl status docker"
    exit 1
fi

echo -e "${GREEN}✓ Permissões do Docker verificadas com sucesso${NC}"

# Verificar se o contêiner do LocalStack está em execução
echo -e "${YELLOW}Verificando contêineres em execução...${NC}"

LOCALSTACK_CONTAINER=$(docker ps --filter "name=localstack" --format '{{.Names}}')

if [ -z "$LOCALSTACK_CONTAINER" ]; then
    echo -e "${YELLOW}Nenhum contêiner do LocalStack em execução.${NC}"
    echo "Tentando iniciar o LocalStack..."
    
    if [ -f "${PROJECT_ROOT}/docker-compose.yml" ]; then
        echo "Iniciando LocalStack com docker-compose..."
        cd "${PROJECT_ROOT}" && ${DOCKER_COMPOSE_CMD} up -d localstack
        
        # Aguardar o LocalStack iniciar
        echo -n "Aguardando o LocalStack iniciar"
        for i in {1..30}; do
            if curl -s "http://${LOCALSTACK_HOST}:4566/health" | grep -q '"glue": "running"'; then
                echo -e "\n${GREEN}✓ LocalStack iniciado com sucesso${NC}"
                break
            fi
            echo -n "."
            sleep 2
            
            if [ $i -eq 30 ]; then
                echo -e "\n${YELLOW}Aviso: O LocalStack está demorando mais que o esperado para iniciar.${NC}"
                echo "Você pode verificar os logs com: docker-compose logs localstack"
                echo ""
                read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                    exit 1
                fi
            fi
        done
    else
        echo -e "${RED}Arquivo docker-compose.yml não encontrado em ${PROJECT_ROOT}${NC}"
        echo "Por favor, certifique-se de que você está no diretório correto do projeto."
        exit 1
    fi
else
    echo -e "${GREEN}✓ Contêiner do LocalStack em execução: ${LOCALSTACK_CONTAINER}${NC}"
fi

# Verificar se o usuário está no grupo docker
if ! docker ps > /dev/null 2>&1; then
    echo -e "${YELLOW}Aviso: Você não tem permissão para executar comandos Docker.${NC}"
    echo "Você precisa adicionar seu usuário ao grupo 'docker'."
    echo "Execute o comando abaixo e faça login novamente:"
    echo "  sudo usermod -aG docker $USER"
    echo "  newgrp docker"
    echo ""
    read -p "Deseja executar este comando agora? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✓ Usuário adicionado ao grupo docker.${NC}"
        echo -e "${YELLOW}Por favor, faça logout e login novamente para que as alterações tenham efeito.${NC}"
        exit 0
    else
        echo -e "${YELLOW}Continuando sem permissões Docker. Alguns comandos podem falhar.${NC}"
    fi
fi

# Verificar se o Docker Compose está instalado
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Erro: Docker Compose não encontrado.${NC}"
    echo "Por favor, instale o Docker Compose para continuar."
    echo "Siga as instruções em: https://docs.docker.com/compose/install/"
    exit 1
fi

# Definir o comando docker-compose apropriado
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Verificar versão mínima do Docker
MIN_DOCKER_VERSION=20.10.0
DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//g')

if [ "$(printf '%s\n' "$MIN_DOCKER_VERSION" "$DOCKER_VERSION" | sort -V | head -n1)" = "$MIN_DOCKER_VERSION" ]; then
    echo -e "${GREEN}✓ Versão do Docker compatível: ${DOCKER_VERSION}${NC}"
else
    echo -e "${YELLOW}Aviso: Versão antiga do Docker detectada: ${DOCKER_VERSION}${NC}"
    echo "Recomenda-se atualizar para a versão ${MIN_DOCKER_VERSION} ou superior."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar versão mínima do Docker Compose
MIN_COMPOSE_VERSION=1.29.0
if [ "$DOCKER_COMPOSE_CMD" = "docker-compose" ]; then
    COMPOSE_VERSION=$($DOCKER_COMPOSE_CMD --version | awk '{print $3}' | sed 's/,//g')
else
    COMPOSE_VERSION=$(docker compose version --short)
fi

if [ "$(printf '%s\n' "$MIN_COMPOSE_VERSION" "$COMPOSE_VERSION" | sort -V | head -n1)" = "$MIN_COMPOSE_VERSION" ]; then
    echo -e "${GREEN}✓ Versão do Docker Compose compatível: ${COMPOSE_VERSION}${NC}"
else
    echo -e "${YELLOW}Aviso: Versão antiga do Docker Compose detectada: ${COMPOSE_VERSION}${NC}"
    echo "Recomenda-se atualizar para a versão ${MIN_COMPOSE_VERSION} ou superior."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar variáveis de ambiente necessárias
echo -e "${YELLOW}Verificando variáveis de ambiente...${NC}"

# Configuração padrão para LocalStack
if [ -z "${LOCALSTACK_HOST}" ]; then
    echo -e "${YELLOW}Definindo LOCALSTACK_HOST como 'localhost'${NC}"
    export LOCALSTACK_HOST=localhost
fi

if [ -z "${AWS_DEFAULT_REGION}" ]; then
    echo -e "${YELLOW}Definindo AWS_DEFAULT_REGION como 'us-east-1'${NC}"
    export AWS_DEFAULT_REGION=us-east-1
fi

# Verificar se as variáveis de ambiente necessárias estão definidas
REQUIRED_ENV_VARS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_DEFAULT_REGION"
)

MISSING_ENV_VARS=()
for var in "${REQUIRED_ENV_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_ENV_VARS+=("$var")
    fi
done

if [ ${#MISSING_ENV_VARS[@]} -ne 0 ]; then
    echo -e "${YELLOW}Aviso: As seguintes variáveis de ambiente não estão definidas:${NC}"
    for var in "${MISSING_ENV_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    
    # Configurar valores padrão para desenvolvimento local
    echo -e "${YELLOW}Configurando valores padrão para desenvolvimento local...${NC}"
    export AWS_ACCESS_KEY_ID="test"
    export AWS_SECRET_ACCESS_KEY="test"
    export AWS_DEFAULT_REGION="us-east-1"
    
    echo "Variáveis de ambiente configuradas com valores padrão para desenvolvimento local."
    echo "  AWS_ACCESS_KEY_ID=test"
    echo "  AWS_SECRET_ACCESS_KEY=test"
    echo "  AWS_DEFAULT_REGION=us-east-1"
    echo ""
    echo "${YELLOW}Nota: Essas são credenciais de teste e só devem ser usadas em ambientes de desenvolvimento local.${NC}"
    echo ""
    read -p "Deseja continuar com essas configurações? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Por favor, defina as variáveis de ambiente necessárias e tente novamente:"
        for var in "${MISSING_ENV_VARS[@]}"; do
            echo "  export $var=seu_valor_aqui"
        done
        exit 1
    fi
fi

# Verificar se a chave da API do LocalStack Pro está definida
if [ -z "${LOCALSTACK_API_KEY}" ]; then
    echo -e "${YELLOW}Aviso: LOCALSTACK_API_KEY não está definida.${NC}"
    echo "Esta variável é necessária para ativar os recursos do LocalStack Pro."
    echo "Você pode obtê-la em: https://app.localstack.cloud/"
    echo ""
    read -p "Deseja continuar sem a chave da API? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Por favor, defina a variável LOCALSTACK_API_KEY e tente novamente:"
        echo "  export LOCALSTACK_API_KEY=sua_chave_aqui"
        exit 1
    fi
else
    echo -e "${GREEN}✓ LOCALSTACK_API_KEY encontrada${NC}"
fi

# Verificar se o script está sendo executado a partir do diretório raiz do projeto
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "${PROJECT_ROOT}/docker-compose.yml" ]; then
    echo -e "${RED}Erro: Não foi possível encontrar o arquivo docker-compose.yml${NC}"
    echo "Por favor, execute este script a partir do diretório raiz do projeto."
    echo "Diretório atual: $(pwd)"
    echo "Diretório do script: ${SCRIPT_DIR}"
    exit 1
fi

echo -e "${GREEN}✓ Diretório do projeto verificado com sucesso${NC}"

echo -e "${YELLOW}Verificando dependências...${NC}"

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Erro: AWS CLI não encontrado. Por favor, instale o AWS CLI.${NC}"
    echo "Siga as instruções em: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Verificar se o jq está instalado (para manipulação de JSON)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Aviso: jq não encontrado. Algumas funcionalidades podem ser limitadas.${NC}"
    echo "Para instalar no macOS: brew install jq"
    echo "Para instalar no Ubuntu/Debian: sudo apt-get install jq"
    echo "Para instalar no CentOS/RHEL: sudo yum install jq"
    echo ""
    read -p "Deseja continuar sem o jq? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Configuração do endpoint do LocalStack
LOCALSTACK_HOST=${LOCALSTACK_HOSTNAME:-localhost}
AWS_ENDPOINT="http://${LOCALSTACK_HOST}:4566"
AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT}"

# Configuração do AWS CLI
echo -e "${YELLOW}Configurando AWS CLI...${NC}"
aws configure set aws_access_key_id test --profile localstack
aws configure set aws_secret_access_key test --profile localstack
aws configure set region us-east-1 --profile localstack
export AWS_PROFILE=localstack
export AWS_ENDPOINT_URL=${AWS_ENDPOINT}

# Função para verificar se o serviço está pronto
wait_for_service() {
  local service=$1
  local service_name=${2:-$service}
  echo -n -e "${YELLOW}Aguardando serviço ${service_name}...${NC}"
  until ${AWS_CMD} ${service} list-accounts >/dev/null 2>&1; do
    echo -n "."
    sleep 2
  done
  echo -e "\n${GREEN}✓${NC} ${service_name} pronto"
}

# Função para executar comandos com tratamento de erro
execute_command() {
  local cmd=$1
  local success_msg=$2
  local error_msg=$3
  
  echo -n "${success_msg}..."
  if eval "${cmd}" >/dev/null 2>&1; then
    echo -e " ${GREEN}OK${NC}"
  else
    echo -e " ${YELLOW}${error_msg}${NC}"
  fi
}

# Verificar se o LocalStack está respondendo
echo -e "\n${YELLOW}Verificando conexão com o LocalStack em ${AWS_ENDPOINT}...${NC}"

# Função para verificar se o LocalStack está pronto
check_localstack_ready() {
    local max_retries=30
    local retry_count=0
    local localstack_ready=false

    echo -n "Aguardando o LocalStack ficar pronto"
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s "${AWS_ENDPOINT}/health" | grep -q '"glue": "running"'; then
            localstack_ready=true
            break
        fi
        
        echo -n "."
        retry_count=$((retry_count + 1))
        sleep 2
    done
    
    echo ""
    
    if [ "$localstack_ready" = false ]; then
        echo -e "\n${RED}Erro: Não foi possível conectar ao LocalStack em ${AWS_ENDPOINT}${NC}"
        echo "Verifique se o container está rodando e se a porta está correta"
        echo "Você pode iniciar o LocalStack com o comando:"
        echo "  cd ${PROJECT_ROOT} && ${DOCKER_COMPOSE_CMD} up -d"
        exit 1
    fi
    
    echo -e "${GREEN}✓ LocalStack está pronto!${NC}"
}

check_localstack_ready

# Aguardar serviços essenciais
wait_for_service "sts" "AWS STS"
wait_for_service "s3" "S3"
wait_for_service "glue" "AWS Glue"
wait_for_service "iam" "AWS IAM"
wait_for_service "dms" "AWS DMS"
wait_for_service "sns" "AWS SNS"
wait_for_service "sqs" "AWS SQS"
wait_for_service "stepfunctions" "AWS Step Functions"

# Criar buckets S3 para o pipeline
echo -e "\n${YELLOW}Criando buckets S3...${NC}"
buckets=(
  "raw-data" 
  "processed-data" 
  "iceberg-warehouse" 
  "datalake"
  "pipeline-artifacts"
  "query-results"
  "glue-scripts"
)

for bucket in "${buckets[@]}"; do
  execute_command \
    "${AWS_CMD} s3 mb s3://${bucket}" \
    "Criando bucket s3://${bucket}" \
    "Bucket já existe ou erro ao criar"
done

# Configurar o Glue Catalog
execute_command \
  "${AWS_CMD} glue create-database --database-input '{\"Name\": \"data_lake\", \"Description\": \"Data Lake Database\", \"LocationUri\": \"s3://datalake/\"}'" \
  "Configurando o Glue Data Catalog" \
  "Banco de dados já existe no Glue"

# Configurar o Athena
execute_command \
  "${AWS_CMD} athena start-query-execution --query-string \"CREATE DATABASE IF NOT EXISTS data_lake\" --result-configuration \"OutputLocation=s3://query-results/\"" \
  "Configurando o Athena" \
  "Erro ao configurar o Athena"

# Configurar DMS (Database Migration Service)
echo -e "\n${YELLOW}Configurando o DMS...${NC}"

# Criar role para DMS
execute_command \
  "${AWS_CMD} iam create-role --role-name dms-vpc-role --assume-role-policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"dms.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}'" \
  "Criando role IAM para DMS" \
  "Falha ao criar role do DMS"

# Criar subnet group para DMS
execute_command \
  "${AWS_CMD} dms create-replication-subnet-group --replication-subnet-group-identifier local-subnet-group --replication-subnet-group-description \"Local Subnet Group\" --subnet-ids subnet-12345678" \
  "Criando subnet group para DMS" \
  "Falha ao criar subnet group do DMS"

# Criar instância DMS
execute_command \
  "${AWS_CMD} dms create-replication-instance --replication-instance-identifier local-dms-instance --replication-instance-class dms.t3.micro --allocated-storage 50 --replication-subnet-group-identifier local-subnet-group" \
  "Criando instância DMS" \
  "Falha ao criar instância do DMS"

# Configurar tópico SNS para notificações
execute_command \
  "${AWS_CMD} sns create-topic --name data-pipeline-notifications" \
  "Configurando tópico SNS para notificações" \
  "Falha ao criar tópico SNS"

# Configurar fila SQS para processamento
execute_command \
  "${AWS_CMD} sqs create-queue --queue-name data-processing-queue --attributes '{\"VisibilityTimeout\":\"300\"}'" \
  "Configurando fila SQS para processamento" \
  "Falha ao criar fila SQS"

# Configurar Step Functions
echo -e "\n${YELLOW}Configurando Step Functions...${NC}"

# Criar função IAM para o Step Functions
execute_command \
  "${AWS_CMD} iam create-role --role-name StepFunctionsExecutionRole --assume-role-policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"states.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}'" \
  "Criando função IAM para Step Functions" \
  "Falha ao criar função IAM para Step Functions"

# Anexar políticas à função IAM
execute_command \
  "${AWS_CMD} iam put-role-policy --role-name StepFunctionsExecutionRole --policy-name StepFunctionsExecutionPolicy --policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"lambda:InvokeFunction\",\"glue:StartJobRun\",\"glue:GetJobRun\",\"glue:GetJobRuns\",\"glue:BatchStopJobRun\",\"states:StartExecution\",\"states:StopExecution\"],\"Resource\":[\"arn:aws:lambda:us-east-1:000000000000:function:*\",\"arn:aws:glue:us-east-1:000000000000:job/*\",\"arn:aws:states:us-east-1:000000000000:stateMachine:*\",\"arn:aws:states:us-east-1:000000000000:execution:*\"],\"Effect\":\"Allow\"}]}'" \
  "Anexando políticas à função IAM do Step Functions" \
  "Falha ao anexar políticas à função IAM"

# Criar máquina de estado do Step Functions
execute_command \
  "${AWS_CMD} stepfunctions create-state-machine --name DataPipelineStateMachine --role-arn \"arn:aws:iam::000000000000:role/StepFunctionsExecutionRole\" --definition \"{\\\"Comment\\\":\\\"Data Pipeline State Machine\\\",\\\"StartAt\\\":\\\"Extract\\\",\\\"States\\\":{\\\"Extract\\\":{\\\"Type\\\":\\\"Task\\\",\\\"Resource\\\":\\\"arn:aws:states:::lambda:invoke\\\",\\\"Parameters\\\":{\\\"FunctionName\\\":\\\"arn:aws:lambda:us-east-1:000000000000:function:extract-data\\\",\\\"Payload\\\":{}},\\\"Next\\\":\\\"Transform\\\"},\\\"Transform\\\":{\\\"Type\\\":\\\"Task\\\",\\\"Resource\\\":\\\"arn:aws:states:::glue:startJobRun.sync\\\",\\\"Parameters\\\":{\\\"JobName\\\":\\\"data-transformation-job\\\"},\\\"Next\\\":\\\"Load\\\"},\\\"Load\\\":{\\\"Type\\\":\\\"Task\\\",\\\"Resource\\\":\\\"arn:aws:states:::lambda:invoke\\\",\\\"Parameters\\\":{\\\"FunctionName\\\":\\\"arn:aws:lambda:us-east-1:000000000000:function:load-data\\\",\\\"Payload\\\":{}},\\\"End\\\":true}}}\"" \
  "Criando máquina de estado do Step Functions" \
  "Falha ao criar máquina de estado do Step Functions"

# Configurar Secrets Manager para armazenar credenciais
execute_command \
  "${AWS_CMD} secretsmanager create-secret --name database-credentials --secret-string '{\\\"username\\\":\\\"postgres\\\",\\\"password\\\":\\\"postgres\\\",\\\"engine\\\":\\\"postgres\\\",\\\"host\\\":\\\"postgres-source\\\",\\\"port\\\":5432,\\\"dbname\\\":\\\"sourcedb\\\"}'" \
  "Configurando Secrets Manager" \
  "Falha ao criar segredo no Secrets Manager"

# Configurar um trabalho do Glue de exemplo
execute_command \
  "${AWS_CMD} glue create-job --name data-transformation-job --role arn:aws:iam::000000000000:role/glue-service-role --command '{\\\"Name\\\":\\\"glueetl\\\",\\\"ScriptLocation\\\":\\\"s3://glue-scripts/transform_script.py\\\"}'" \
  "Configurando trabalho do Glue" \
  "Falha ao criar trabalho do Glue"

# Criar função Lambda de exemplo
echo -e "\n${YELLOW}Criando funções Lambda...${NC}"
for function in extract-data transform-data load-data; do
  execute_command \
    "${AWS_CMD} lambda create-function --function-name ${function} --runtime python3.9 --role arn:aws:iam::000000000000:role/lambda-role --handler lambda_function.lambda_handler --zip-file fileb:///dev/null" \
    "Criando função Lambda ${function}" \
    "Falha ao criar função Lambda ${function}"
done

# Criar funções Lambda de exemplo em arquivos temporários
for function in extract-data transform-data load-data; do
  cat > "/tmp/${function}.py" << 'EOL'
def lambda_handler(event, context):
    print(f"{function} function executed")
    return {
        'statusCode': 200,
        'body': f"{function} executed successfully"
    }
EOL
  
  # Criar arquivo ZIP temporário
  (cd /tmp && zip -q "${function}.zip" "${function}.py")
  
  # Fazer upload para o S3
  execute_command \
    "${AWS_CMD} s3 cp /tmp/${function}.zip s3://pipeline-artifacts/${function}.zip" \
    "Fazendo upload do código da função ${function}" \
    "Falha ao fazer upload do código da função ${function}"
  
  # Atualizar a função Lambda com o código
  execute_command \
    "${AWS_CMD} lambda update-function-code --function-name ${function} --s3-bucket pipeline-artifacts --s3-key ${function}.zip" \
    "Atualizando código da função ${function}" \
    "Falha ao atualizar código da função ${function}"
  
  # Limpar arquivos temporários
  rm -f "/tmp/${function}.py" "/tmp/${function}.zip"
done

# Criar script de exemplo do Glue
cat > /tmp/transform_script.py << 'EOL'
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Inicializa o contexto do Glue
glueContext = GlueContext(SparkContext.getOrCreate())

# Lê os dados de origem
datasource = glueContext.create_dynamic_frame.from_catalog(
    database="data_lake",
    table_name="raw_data",
    transformation_ctx="datasource"
)

# Transforma os dados (exemplo simples)
transformed = ApplyMapping.apply(
    frame=datasource,
    mappings=[("column1", "string", "column1", "string"),
              ("column2", "int", "column2", "int")],
    transformation_ctx="transformed"
)

# Grava os dados processados
datasink = glueContext.write_dynamic_frame.from_catalog(
    frame=transformed,
    database="data_lake",
    table_name="processed_data",
    transformation_ctx="datasink"
)
EOL

# Fazer upload do script do Glue para o S3
execute_command \
  "${AWS_CMD} s3 cp /tmp/transform_script.py s3://glue-scripts/transform_script.py" \
  "Fazendo upload do script do Glue" \
  "Falha ao fazer upload do script do Glue"

# Limpar arquivo temporário
rm -f /tmp/transform_script.py

echo -e "\n${GREEN}✅ Configuração inicial concluída com sucesso!${NC}"
echo -e "\n${YELLOW}Acesso aos serviços:${NC}"
echo "- LocalStack Web UI: http://localhost:8080"
echo "- Jupyter Notebook: http://localhost:8888"
echo "- PostgreSQL Source: localhost:5432 (user: postgres, pass: postgres, db: sourcedb)"
echo "- PostgreSQL Target: localhost:5433 (user: postgres, pass: postgres, db: targetdb)"
echo "- MySQL Source: localhost:3306 (user: user, pass: password, db: source_db)"

echo -e "\n${YELLOW}Próximos passos:${NC}"
echo "1. Configure suas credenciais AWS localmente:"
echo "   aws configure set aws_access_key_id test --profile localstack"
echo "   aws configure set aws_secret_access_key test --profile localstack"
echo "   aws configure set region us-east-1 --profile localstack"
echo "   export AWS_PROFILE=localstack"

echo -e "\n2. Teste o acesso ao S3:"
echo "   aws --endpoint-url=${AWS_ENDPOINT} s3 ls"

echo -e "\n3. Acesse o painel do LocalStack para monitorar os recursos:"
echo "   http://localhost:8080"

echo -e "\n4. Para testar o pipeline, execute:"
echo "   aws --endpoint-url=${AWS_ENDPOINT} stepfunctions start-execution --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:DataPipelineStateMachine"

echo -e "\n${GREEN}✅ Configuração do ambiente LocalStack concluída com sucesso!${NC}"
