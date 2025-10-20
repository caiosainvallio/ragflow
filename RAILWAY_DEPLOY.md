# Deploy RAGFlow no Railway.com

Este guia explica como fazer deploy do RAGFlow no Railway.com.

## ✅ Correções Implementadas

O `Dockerfile` foi otimizado para Railway.com com as seguintes mudanças:

1. **Removidos todos os `--mount` cache mounts** - Railway não suporta essa sintaxe
2. **Substituídos bind mounts por `COPY --from=deps`** - Usa sintaxe Docker padrão
3. **Removida dependência do `.git`** - Versão gerada automaticamente no build
4. **Adicionado `.dockerignore`** - Otimiza o contexto de build

## 🚀 Como Fazer Deploy

### No Railway.com:

1. Conecte seu repositório no Railway
2. O Railway detectará automaticamente o `Dockerfile`
3. O deploy será feito automaticamente

**Pronto!** Não precisa de configurações adicionais.

## 📋 Arquivos Importantes

### Dockerfile
- ✅ Compatível com Railway.com
- ✅ Sem sintaxe `--mount`
- ✅ Usa `COPY --from=deps` (sintaxe padrão)
- ✅ Não depende do `.git`
- ✅ Gera versão automaticamente: `v2.0-railway-YYYYMMDD-HHMMSS`

### .dockerignore
- Otimiza o contexto de build
- Exclui `.git`, `node_modules`, `__pycache__`, etc.
- Reduz tempo de upload e build

### Dockerfile.railway (Backup)
- Versão alternativa caso necessário
- Funcionalidade idêntica ao `Dockerfile` principal

## Testando Localmente

Antes de fazer deploy no Railway, você pode testar localmente:

```bash
# Testar Dockerfile principal
docker build -t ragflow:latest .

# Testar Dockerfile.railway
docker build -f Dockerfile.railway -t ragflow:railway .
```

## Suporte

Se ambas as soluções falharem:
1. Verifique os logs do Railway para erros específicos
2. Certifique-se de que a imagem base `infiniflow/ragflow_deps:latest` está acessível
3. Verifique se há limitações de recursos no seu plano do Railway

## Build Arguments

Ambos os Dockerfiles suportam os mesmos build arguments:

```bash
# Usar mirrors chineses para downloads
--build-arg NEED_MIRROR=1

# Versão "light" sem alguns modelos
--build-arg LIGHTEN=1
```

No Railway, você pode adicionar estes em "Build Configuration" → "Build Arguments".

