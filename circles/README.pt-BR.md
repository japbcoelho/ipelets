# Circles para Ipe

[Read in English](README.md)

![Visão geral das construções do Circles](docs/images/circles-overview.svg)

Circles é um Ipelet Lua autônomo para construções geométricas com circunferências. Ele reúne janelas de configuração, pré-visualização ao vivo, algoritmos analíticos estáveis, resultados compatíveis com desfazer e objetos nativos editáveis do Ipe em um único arquivo.

## Fluxo principal: escolha uma circunferência tangente

Selecione três circunferências e escolha `All` em `Circle tangency`. O Circles calcula todas as soluções exatas e mostra as oito candidatas diretamente sobre a área de desenho. Ao mover o ponteiro, a candidata mais próxima recebe um contorno duplo; a barra de estado informa a candidata atual e os comandos disponíveis pelo teclado e pelo mouse.

![Oito circunferências tangentes candidatas na pré-visualização ao vivo do Ipe](docs/images/tangent-circles-live-preview.png)

Clique na candidata destacada para criar somente aquela circunferência. As marcas de tangência e os raios auxiliares opcionais são objetos nativos do Ipe, portanto o resultado completo continua editável e pode ser desfeito normalmente.

![Circunferência tangente escolhida e criada como geometria editável no Ipe](docs/images/tangent-circle-result.png)

## Destaques

- Um único arquivo autônomo: `circles.lua`.
- Nenhuma dependência do Ipelet Geometry, de bridge auxiliar, da internet ou de pacotes Lua externos.
- Seletor interativo de circunferências tangentes com todas as soluções exatas visíveis simultaneamente.
- Caminhos, marcas, textos e grupos nativos e editáveis do Ipe.
- Pré-visualização automática e botão manual de pré-visualização.
- Validação explícita e mensagens úteis para seleções inválidas.
- Proteções numéricas para coordenadas em escalas muito pequenas ou muito grandes.

## Ferramentas

O menu `Ipelets → Circles` contém cinco entradas:

| Entrada do menu | Operações incluídas |
| --- | --- |
| Construct: circle | Centro e ponto, centro e raio, diâmetro, três pontos, arco por três pontos, dois pontos e raio, reta polar, polo de uma reta e centros de homotetia. |
| Construct: tangent circle | Três circunferências; duas circunferências e um ponto ou uma reta; dois pontos e uma circunferência ou reta; ponto-reta-circunferência; duas retas e uma circunferência ou ponto; e três retas. |
| Construct: tangent lines | De um ponto para uma circunferência, tangentes comuns entre circunferências e retas paralelas ou perpendiculares a uma reta de referência. |
| Inversion/radicals: operations | Inversão de ponto, reta ou circunferência; eixo radical; centro radical; e circunferência ortogonal. |
| Mark center: circle/ellipse/arc | Marca o centro transformado da circunferência, elipse ou arco circular selecionado. |

## Requisitos

- Ipe com suporte a Ipelets em Lua.
- Verificado com Ipe 7.2.30 e Lua 5.4 no Linux.

O Ipelet utiliza objetos documentados da API Lua do Ipe e não exige compilação.

## Instalação

Baixe o pacote autocontido na [versão 1.0.0 de Circles](https://github.com/japbcoelho/ipelets/releases/tag/v1.0.0) ou utilize um dos métodos abaixo.

### Utilitário do repositório no Linux

Na raiz do repositório:

```bash
./scripts/install.sh circles
```

Reinicie o Ipe depois que a cópia terminar.

### Instalação manual

Copie [`circles.lua`](circles.lua) para uma das pastas de Ipelets do usuário:

- Linux, instalação nativa: `~/.ipe/ipelets/`
- Linux, instalação Flatpak: `~/.var/app/org.otfried.Ipe/.ipe/ipelets/`
- macOS: `~/.ipe/ipelets/` ou `~/Library/Ipe/Ipelets/`
- Windows: `%USERPROFILE%\Ipelets\`

Crie a pasta se necessário, copie o arquivo e reinicie o Ipe. O novo submenu `Circles` aparecerá em `Ipelets`.

## Uso básico

1. Desenhe ou selecione os objetos de entrada pedidos pela ferramenta. A janela informa a seleção necessária.
2. Abra `Ipelets → Circles` e escolha uma operação.
3. Ajuste as opções enquanto observa a pré-visualização.
4. Escolha Create. O resultado continuará editável e poderá ser desfeito normalmente.

A seleção primária é importante nas operações que distinguem uma entrada, como a inversão de circunferência. A própria janela informa essa ordem quando necessário.

## Funcionamento da pré-visualização

A pré-visualização ao vivo fica ativada por padrão e não modifica o documento. Ela é atualizada quando os campos da janela mudam. Desative a opção para um fluxo mais discreto ou utilize o botão Preview para uma atualização explícita. Cancelar a janela remove a prévia sem criar objetos.

## Exemplos

- [`circles-overview.ipe`](examples/circles-overview.ipe) é a fonte limpa e editável da imagem principal em duas etapas. Ela contém a prévia com oito candidatas e o resultado escolhido com os raios de tangência.
- As duas capturas da seção de fluxo principal vieram de uma sessão real do Ipe: o seletor interativo e o objeto final após o clique.

O exemplo e as capturas versionados foram gerados por uma sessão real do Ipe 7.2.30.

## Atalho

`Alt+T` abre o terceiro método do Circles, `Construct: tangent lines`, quando essa combinação estiver disponível na configuração atual do Ipe.

## Testes

Na raiz do repositório:

```bash
./scripts/validate.sh
```

A suíte é executada sem serviços externos de automação. Ela verifica a geometria analítica, os contratos de criação de objetos, regressões numéricas, o isolamento de entradas explícitas e os limites do código de publicação.

## Solução de problemas

### Circles não aparece

Confirme que `circles.lua` está diretamente dentro de uma pasta de Ipelets do usuário, e não dentro de outra subpasta chamada `circles/`. Depois, reinicie completamente o Ipe.

### Uma construção informa que a seleção é inválida

Confira a linha de seleção necessária na janela. Marcas fornecem pontos, elipses de caminho fornecem circunferências e um caminho reto formado por um único segmento fornece uma restrição de reta.

### O objeto criado não aparece

Circles cria o resultado na camada ativa. Torne essa camada visível ou ative uma camada visível antes da construção.

## Licença

Copyright (C) 2026 japbcoelho. Circles é licenciado sob a GNU General Public License, versão 3 ou qualquer versão posterior. Consulte [LICENSE](../LICENSE).
