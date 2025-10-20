# Deploy RAGFlow no Railway.com

Este guia explica como resolver o erro de cache mounts ao fazer deploy no Railway.com.

## Problema

O Railway.com tem requisitos mais rígidos para cache mounts e pode exigir o formato:
```
--mount=type=cache,id=<cache-id>,target=<path>,sharing=locked
```

## Soluções

### Solução 1: Usar o Dockerfile principal atualizado (Recomendado)

O `Dockerfile` principal foi atualizado com o parâmetro `sharing=locked` em todos os cache mounts. Esta é a solução preferida pois mantém as otimizações de cache.

**No Railway.com:**
1. Vá para as configurações do seu projeto
2. Certifique-se de que está usando `Dockerfile` (padrão)
3. Faça o deploy normalmente

### Solução 2: Usar Dockerfile.railway (Sem cache)

Se a Solução 1 ainda não funcionar, use o `Dockerfile.railway` que remove completamente os cache mounts.

**No Railway.com:**
1. Vá para as configurações do seu projeto
2. Em "Build Configuration" → "Dockerfile Path"
3. Altere de `Dockerfile` para `Dockerfile.railway`
4. Salve e faça o deploy

**Nota:** Esta solução será mais lenta no build, mas garantida para funcionar.

## Diferenças entre os Dockerfiles

### Dockerfile (Principal)
- ✅ Usa cache mounts com `sharing=locked`
- ✅ Builds mais rápidos
- ✅ Menor uso de rede
- ⚠️  Requer suporte a cache mounts no Railway

### Dockerfile.railway
- ✅ Sem cache mounts (compatível com qualquer plataforma)
- ✅ 100% compatível com Railway.com
- ⚠️  Builds mais lentos
- ⚠️  Maior uso de rede (re-download de pacotes)

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

