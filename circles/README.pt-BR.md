# Circles para Ipe

[Read in English](README.md)

Circles é um Ipelet Lua autônomo para construções geométricas com circunferências. Ele reúne janelas de configuração, pré-visualização ao vivo, algoritmos analíticos estáveis, resultados compatíveis com desfazer e objetos nativos editáveis do Ipe em um único arquivo.

## Fluxo principal: escolha uma circunferência tangente

Selecione três circunferências, abra `Construct: tangent circle`, escolha o conjunto de restrições com três circunferências e defina `Circle tangency` como `All`. As circunferências podem ter raios diferentes e não precisam estar distribuídas simetricamente. O Circles calcula as oito soluções exatas e as exibe diretamente na área de desenho.

Os contornos vermelhos do primeiro painel representam as oito soluções válidas. Ao mover o ponteiro, a candidata ativa muda e recebe um contorno duplo. Clique nela para criar somente a circunferência escolhida; as marcas de tangência e os raios auxiliares opcionais permanecem como objetos nativos e editáveis do Ipe.

![As oito circunferências tangentes candidatas e o resultado editável selecionado](docs/images/01_all_tangent_circle_candidates.png)

## Guia visual

A galeria omite deliberadamente as construções básicas de circunferências e arcos que já existem no Ipe. Ela se concentra nas operações que acrescentam um fluxo próprio ou revelam várias soluções geométricas.

### Inversões e construções radicais

Os seis painéis mostram inversão de ponto, reta e circunferência; o eixo radical de duas circunferências; o centro radical de três circunferências; e uma circunferência ortogonal a uma referência. Os objetos tracejados em azul-escuro são as entradas, enquanto os objetos pretos são os resultados criados pelo ipelet.

![Seis inversões e construções radicais](docs/images/02_inversion_and_radicals.png)

### Retas tangentes

É possível construir tangentes de um ponto para uma circunferência, entre duas circunferências ou paralelas e perpendiculares a uma reta selecionada. O fluxo de tangentes comuns pode retornar as quatro tangentes ou apenas o par externo ou interno. Os pontos pretos identificam os contatos.

![Operações de retas tangentes e seus pontos de contato](docs/images/03_tangent_lines.png)

### Conjuntos de restrições para circunferências tangentes

Cada operação combina três restrições escolhidas entre circunferências, pontos e retas. A janela pode expor todas as candidatas válidas; a galeria mostra um resultado selecionado para cada conjunto de restrições, enquanto o fluxo principal acima expande o caso de três circunferências para as oito candidatas.

![Oito conjuntos de restrições para circunferências tangentes](docs/images/04_tangent_circle_constraints.png)

### Centro de uma elipse transformada

Em uma elipse submetida a uma transformação afim, o comando insere o centro geométrico como uma marca editável. Os exemplos de centro de circunferência e arco circular foram omitidos porque o próprio Ipe já fornece esses centros diretamente.

![Centro marcado em uma elipse transformada](docs/images/05_mark_ellipse_center.png)

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

Baixe o pacote autocontido na [versão 1.0.1 de Circles](https://github.com/japbcoelho/ipelets/releases/tag/circles-v1.0.1) ou utilize um dos métodos abaixo.

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

- [`circles-overview.ipe`](examples/circles-overview.ipe) é a fonte editável de 23 páginas das cinco pranchas. Ela contém a pré-visualização com oito candidatas, o resultado escolhido com raios de tangência, todos os painéis de inversões, construções radicais e retas tangentes, os oito conjuntos restantes de restrições para circunferências tangentes e o exemplo do centro da elipse transformada.
- Todos os diagramas foram gerados e renderizados em uma sessão real do Ipe 7.2.30. As pranchas utilizam essas renderizações do Ipe, sem ilustrações vetoriais substitutas.

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
