# Conics para Ipe

[Read in English](README.md)

Conics é um Ipelet Lua autônomo para construir, ajustar, classificar, intersectar, recortar, inspecionar e anotar cônicas. Ele contempla elipses, circunferências, parábolas, hipérboles e lugares geométricos degenerados explícitos. Preserva a geometria exata do Ipe quando possível, utiliza splines adaptativas compactas nos ramos abertos de hipérboles e mantém todo resultado visível editável e compatível com desfazer.

## Fluxo principal: cinco pontos viram uma cônica estruturada

Selecione cinco marcas e escolha `Conic through five points`. O Conics resolve diretamente o sistema homogêneo dos cinco pontos, rejeita dados duplicados, mal condicionados ou degenerados, classifica o resultado e escolhe automaticamente a melhor representação no Ipe: elipse nativa, spline quadrática exata de parábola ou ramos contínuos e adaptativos de hipérbole em splines cúbicas.

Selecione o resultado e abra `Property guides` para criar sua geometria significativa: centro ou vértice, eixos, vértices, focos, diretrizes e assíntotas, usando marcas, retas e rótulos opcionais nativos.

O fluxo de diretriz e focos pode criar várias parábolas exatas em uma única operação, preservando uma única etapa limpa de desfazer.

A versão 1.1 também trabalha com o lado dual da geometria das cônicas: cinco retas tangentes determinam uma cônica, condições mistas de pontos e tangentes podem ser combinadas, e um ponto exterior produz as duas tangentes e sua corda de contato. Duas cônicas selecionadas podem ser intersectadas diretamente, enquanto uma curva existente pode ser recortada em um arco conexo ou ajustada e substituída em uma única transação de desfazer.

## Destaques

- Um único arquivo autônomo de execução: `conics.lua`.
- Nenhuma dependência do Ipelet Geometry, de bridge auxiliar, da rede ou de pacotes Lua externos.
- Elipses nativas exatas e splines compactas e exatas de parábolas.
- Ramos contínuos de hipérboles subdivididos por tolerância de erro geométrico.
- Construção dual exata por cinco retas e condições mistas de pontos e tangentes.
- Ajuste por mínimos quadrados a partir de 6–512 marcas de amostra, com verificação de condicionamento e resíduo.
- Polos, polares, tangentes por ponto exterior, cordas de contato, cordas focais e interseções entre cônicas.
- Arcos de cônicas exatos ou adaptativos e ajuste com substituição transacional de caminhos selecionados.
- Lugares degenerados explícitos: par de retas, reta dupla, reta única, ponto e conjunto vazio.
- Lados retos, circunferências auxiliares ou diretora, equações, área e rótulos de parâmetros.
- Validação estrita de seleção, opções, metadados e números finitos.
- Pré-visualização automática e botão manual Preview.
- Criação na camada ativa, uso seguro dos atributos atuais do Ipe, controles de agrupamento e desfazer/refazer em uma única etapa.
- Cálculos sensíveis à escala para coordenadas muito pequenas ou muito grandes.
- Leitura compatível dos metadados de cônicas escritos pela implementação anterior no Geometry.

## Ferramentas

O menu `Ipelets → Conics` contém sete entradas:

| Entrada do menu | Operações incluídas |
| --- | --- |
| Construct: conic | Elipses de Steiner; construção exata por cinco pontos; melhor ajuste por muitos pontos; cinco retas tangentes; cinco condições mistas de pontos e tangentes; foco–diretriz com ponto ou excentricidade numérica; elipse canônica pelos pontos médios; e lugares degenerados explícitos. |
| Construct: ellipse | Elipse nativa por dois focos e um ponto ou por um centro e dois extremos perpendiculares dos semieixos. |
| Construct: hyperbola | Hipérbole por dois focos e um ponto, centro e semieixos, semieixos iguais ou duas assíntotas e um ponto. |
| Construct: parabola | Uma parábola exata para cada foco combinado com uma diretriz ou uma parábola pelo vértice e foco. |
| Features: conic | Tangente/normal, polar e polo, tangentes por um ponto, corda de contato, corda focal, interseções com reta ou cônica, arcos de cônicas, ajuste com substituição e guias editáveis de propriedades e equações. |
| Inspect: conic | Calcula coeficientes e propriedades padrão sem alterar o documento. |
| Metadata: revalidate selected conic | Reajusta e substitui metadados obsoletos depois de uma edição estrutural do caminho. |

## Requisitos

- Ipe com suporte a Ipelets em Lua 5.4.
- Projetado e testado para o Ipe 7.2.30 no Linux.

O Ipelet utiliza objetos documentados da API Lua do Ipe e não exige compilação.

## Instalação

Baixe o pacote autocontido na [versão 1.1.1 de Conics](https://github.com/japbcoelho/ipelets/releases/tag/conics-v1.1.1) ou utilize um dos métodos abaixo.

### Utilitário do repositório no Linux

Na raiz do repositório:

```bash
./scripts/install.sh conics
```

Reinicie o Ipe depois que a cópia terminar.

### Instalação manual

Copie [`conics.lua`](conics.lua) para uma das pastas de Ipelets do usuário:

- Linux, instalação nativa: `~/.ipe/ipelets/`
- Linux, instalação Flatpak: `~/.var/app/org.otfried.Ipe/.ipe/ipelets/`
- macOS: `~/.ipe/ipelets/` ou `~/Library/Ipe/Ipelets/`
- Windows: `%USERPROFILE%\Ipelets\`

Coloque o arquivo diretamente na pasta de Ipelets, reinicie o Ipe e abra o novo submenu `Conics` em `Ipelets`.

## Contratos de seleção

As janelas mostram estes requisitos diretamente na interface:

| Fluxo | Seleção necessária |
| --- | --- |
| Elipses de Steiner | Exatamente três marcas. |
| Cônica por cinco pontos | Exatamente cinco marcas. |
| Cônica por melhor ajuste | De 6 a 512 marcas. |
| Cônica tangente a cinco retas | Exatamente cinco segmentos. |
| Cinco condições mistas | Cinco marcas; ou quatro marcas e um segmento tangente; ou três marcas e dois segmentos tangentes. Cada segmento tangente deve passar por exatamente uma marca selecionada no ponto de tangência. |
| Foco, diretriz e ponto | Duas marcas e um segmento; o ponto da cônica deve ser primário, a outra marca é o foco e o segmento é a diretriz. |
| Foco, diretriz e excentricidade | Uma marca primária no foco e um segmento secundário na diretriz; informe `e<1`, `e=1` ou `e>1` para obter elipse, parábola ou hipérbole. |
| Elipse canônica pelos pontos médios | Exatamente quatro marcas. |
| Elipse por focos e ponto | Três marcas; o ponto da elipse deve ser primário e as duas marcas secundárias são os focos. |
| Elipse por centro e semieixos | Três marcas; o centro deve ser primário e os dois extremos devem definir semieixos não nulos e perpendiculares. |
| Hipérbole por focos e ponto | Três marcas; o ponto da hipérbole deve ser primário e as duas marcas secundárias são os focos. |
| Hipérbole por parâmetros | Uma marca primária para o centro e, opcionalmente, um segmento secundário que fornece a direção do eixo transverso. |
| Hipérbole por assíntotas e ponto | Uma marca primária no ponto e dois segmentos secundários que definem assíntotas concorrentes. |
| Parábola por diretriz e focos | Um segmento primário para a diretriz e uma ou mais marcas secundárias para os focos. |
| Parábola por vértice e foco | Duas marcas; o vértice deve ser primário. |
| Lugares degenerados | Dois segmentos para um par de retas, um segmento para reta dupla ou única, uma marca para um ponto e nenhuma seleção para o conjunto vazio. |
| Tangente, normal ou polar | Uma cônica primária e uma marca secundária. O ponto de tangente ou normal deve pertencer à cônica. |
| Tangentes por um ponto | Uma cônica primária e uma marca secundária; o resultado distingue corretamente zero, uma ou duas tangentes reais. |
| Polo de uma reta | Uma cônica primária e um segmento secundário. Um polo no infinito é informado sem criar um ponto finito falso. |
| Corda focal | Uma cônica não circular primária e uma marca secundária que define a reta por um foco escolhido. |
| Interseções com reta | Uma cônica primária e um segmento secundário. |
| Interseções de duas cônicas | Exatamente duas cônicas; a primeira deve ser primária. O resultado distingue de zero a quatro interseções reais finitas e cônicas coincidentes. |
| Recortar cônica em arco | Uma cônica primária e duas marcas secundárias no mesmo arco conexo. |
| Ajustar e substituir caminho | Exatamente um caminho primário. |
| Guias de propriedades, inspeção ou revalidação | Exatamente uma cônica primária ou um grupo que contenha uma única cônica lógica. |

Entradas explícitas da API têm precedência sobre a seleção do documento. Quando um fluxo precisa ler a seleção, objetos extras ou de tipo incorreto são rejeitados em vez de ignorados silenciosamente.

## Extensão, qualidade e agrupamento

- `extent` define uma extensão simétrica da curva aberta. Em hipérboles, ela é medida no eixo transverso e deve ser maior que o semieixo transverso.
- A construção geral também aceita `bounds={left,bottom,right,top}`. `extent` e `bounds` são mutuamente exclusivos.
- `padding` amplia uma extensão de curva aberta calculada automaticamente.
- `tolerance` controla o erro geométrico máximo usado para subdividir um ramo de hipérbole.
- `max_segments` é o limite de segurança para cada ramo adaptativo de hipérbole; o alias legado `samples` continua aceito como limite de segmentos, com mínimo de quatro.
- `expected_kind` pode restringir um ajuste por mínimos quadrados a `ellipse`, `parabola` ou `hyperbola`; o ajuste é recusado quando o resíduo ou o condicionamento não é confiável.
- `arc_mode` escolhe o arco menor, maior, horário ou anti-horário de uma elipse. As extremidades de uma parábola ou hipérbole devem pertencer ao mesmo ramo conexo.
- `group_output` escolhe se ramos relacionados, auxiliares, múltiplas parábolas ou vários elementos serão agrupados. Quando permanecem separados, somente o primeiro objeto recebe seleção primária e os demais recebem seleção secundária.

## Propriedades analíticas e equações

`Property guides` pode criar centro ou vértice, eixos, vértices, focos, diretrizes, assíntotas, lados retos, circunferências auxiliares e circunferência diretora, quando forem aplicáveis. Também pode inserir rótulos LaTeX editáveis para a equação geral normalizada, uma equação canônica e parâmetros como `a`, `b`, `c`, excentricidade, parâmetro focal, semilado reto, raio focal e área da elipse. Os controles que não pertencem à operação escolhida ficam desabilitados na janela.

## Pré-visualização e comportamento no documento

A pré-visualização ao vivo fica ativada por padrão e nunca altera o documento. Ela acompanha as opções da janela, a geometria dos objetos selecionados e suas matrizes afins. O botão manual Preview informa um estado ou erro útil na área de status do Ipe. Cancelar ou ocorrer uma exceção sempre encerra o timer e remove a sobreposição da prévia.

Os objetos são criados na camada ativa. O Conics avisa quando essa camada está invisível. Os atributos de caminhos, marcas e textos partem dos atributos atuais do Ipe, mas atributos incompatíveis com caminhos de cônicas, como preenchimento, setas e decorações, são filtrados. O Ipelet não exige stylesheet pessoal; todos os nomes simbólicos padrão pertencem aos estilos básicos do Ipe.

## Metadados e edição

As curvas criadas utilizam metadados versionados `conics:v1`, com papel do objeto, identificador da cônica, tipo, origem, sistema de coordenadas, coeficientes e impressão digital da geometria. Eixos, marcas, rótulos, diretrizes, assíntotas, polos, cordas, lados retos, circunferências auxiliares ou diretora, equações e lugares degenerados têm papéis próprios e nunca são confundidos com uma curva cônica comum.

Mover, girar, redimensionar ou cisalhar uma cônica é suportado: a inspeção transforma os coeficientes armazenados pela matriz afim do objeto. Editar os nós internos de um caminho aproximado altera a geometria sem mudar essa matriz, então o Conics detecta uma impressão digital obsoleta. Use `Metadata: revalidate selected conic` para reajustar o caminho selecionado; o comando recusa o reparo quando a forma editada não é uma cônica confiável.

## Exemplos

- [`conics-overview.ipe`](examples/conics-overview.ipe) é a fonte editável da apresentação do fluxo de cinco pontos, da extração básica de propriedades, da construção por foco e diretriz, dos ramos de hipérbole e das múltiplas parábolas.
- [`conics-feature-gallery.ipe`](examples/conics-feature-gallery.ipe) é uma galeria editável de 32 páginas gerada pela auditoria viva de aceitação. Ela cobre todas as famílias de construção, os fluxos avançados de elementos, lugares degenerados, previews, ajuste, inspeção e revalidação de metadados.
- Os dois documentos de exemplo carregam internamente todos os estilos necessários e continuam sendo as demonstrações editáveis de referência para esses fluxos.

## API pública

`_G.CONICS` expõe a versão de API `1`. Os criadores aceitam entradas guiadas por seleção ou tabelas estruturadas. Nas operações de elementos, prefira blocos separados para `definition` e `feature_input`:

```lua
local result = CONICS.create_conic_features(model, {
  operation = "conic_intersections",
  definition = { coefficients = { 1, 0, 1, 0, 0, -100 } },
  feature_input = {
    second_coefficients = { 1, 0, 1, -12, 0, -64 },
  },
  marks = false,
})
```

Esse exemplo devolve um resultado calculado com dois pontos e não altera o documento. Os nomes canônicos dos criadores são `create_conic`, `create_ellipse`, `create_hyperbola`, `create_parabola` e `create_conic_features`; os aliases da versão 1.0, `create_ellipse_from_foci` e `create_parabolas`, continuam disponíveis. Todos os criadores públicos informam consistentemente `created`, `status`, `operation`, `element_count`, `object_count`, `metadata` e `result`.

## Testes

Na raiz do repositório:

```bash
./scripts/validate.sh conics
```

A suíte portátil carrega apenas `conics.lua` em um ambiente Lua mínimo e compatível com o Ipe. Ela cobre contratos de construção, regressões numéricas, migração e corrupção de metadados, pré-visualizações, transações, conteúdo do pacote e ausência de dependências locais de desenvolvimento.

## Solução de problemas

### Conics não aparece

Confirme que `conics.lua` está diretamente dentro de uma pasta de Ipelets do usuário, e não dentro de outra pasta chamada `conics/`, e reinicie completamente o Ipe.

### Uma seleção é rejeitada

Confira a linha `Required selection` na janela. Entradas de pontos devem ser referências `mark/*`, e uma entrada de reta deve ser um caminho aberto com exatamente um segmento. Textos, caminhos ou referências adicionais são rejeitados intencionalmente.

### O objeto foi criado, mas não está visível

O Conics usa a camada ativa. Torne essa camada visível ou ative uma camada visível antes de criar o resultado.

### A inspeção informa que os metadados estão obsoletos

A forma interna da curva foi editada. Use o comando de revalidação se o caminho alterado ainda for uma cônica ou reconstrua a curva a partir de suas entradas definidoras.

## Licença e atribuição

Copyright (C) 2026 japbcoelho. Conics é licenciado sob a GNU General Public License, versão 3 ou qualquer versão posterior. As fórmulas de elipse por focos e de parábola foram adaptadas do `goodies.lua` do Ipe, licenciado sob GPL. Consulte [LICENSE](../LICENSE) e [NOTICE.md](../NOTICE.md).
