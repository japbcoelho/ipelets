# Triangles

[Read in English](README.md)

Triangles é uma extensão autônoma do [Ipe](https://ipe.otfried.org/) para centros de triângulos e construções euclidianas derivadas. A instalação utiliza um único arquivo Lua e não depende do Geometry, de uma ponte MCP nem de outro Ipelet do usuário.

![Centros fundamentais do triângulo e reta de Euler](docs/images/01_fundamental_centers_euler_line.png)

## Ferramentas

O Ipelet adiciona duas entradas ao menu:

- **Construct: triangle centers** permite escolher qualquer combinação de 24 centros ou um de quatro conjuntos matemáticos: fundamentais, de contato/cevianos, da reta de Euler e isogonais/de Napoleão.
- **Construct: derived triangle geometry** cria uma das nove construções derivadas e mostra uma origem explícita para o ponto de referência quando ele é necessário.

## Centros

Estão disponíveis: baricentro, incentro, circuncentro, ortocentro, centro dos nove pontos, três excentros, centro de Spieker, Mittenpunkt, ponto de Feuerbach, ponto simediano, ponto de Gergonne, ponto de Nagel, ponto de de Longchamps, dois pontos de Brocard, primeiro e segundo centros isogônicos (X13 e X14), dois pontos isodinâmicos, dois pontos de Napoleão e ponto de Exeter.

Cada centro pode gerar marca e rótulo. A opção **Defining lines** desenha somente uma construção que define matematicamente o centro escolhido: medianas, bissetrizes, mediatrizes, alturas, simedianas ou cevianas de Gergonne e Nagel. O diálogo de centros cria apenas a circunferência dos nove pontos; incírculo e excírculos continuam na construção do triângulo de contato, em que são pertinentes. A reta de Euler permanece disponível de forma independente.

Centros coincidentes compartilham uma única marca, em vez de formar uma pilha ilegível. Os rótulos são posicionados ao redor dos pontos e da geometria existente para conservar uma associação visual clara. Centros ideais, indefinidos ou numericamente indisponíveis são informados sem criar geometria infinita.

## Construções derivadas

O diálogo de construções derivadas oferece:

- triângulos medial, órtico, de contato, excentral e pedal;
- os nove pontos da circunferência dos nove pontos;
- extremidades das cevianas;
- conjugados isogonal e isotômico.

As construções pedal, ceviana, isogonal e isotômica exigem um ponto de referência real. É possível usar uma marca adicional selecionada, baricentro, incentro, circuncentro, ortocentro, ponto simediano ou coordenadas explícitas. O ponto nunca é silenciosamente substituído pelo baricentro.

Os rótulos não dependem das marcas e usam nomes semânticos, como `H_a`, `M_{AB}` e `D_a`. O controle de circunferência associada só fica habilitado para as construções de contato e dos nove pontos.

## Galeria

Todas as imagens abaixo foram renderizadas pelo Ipe a partir do documento editável [`triangles-feature-gallery.ipe`](examples/triangles-feature-gallery.ipe). O documento chama os mesmos criadores públicos utilizados pelas ferramentas do menu.

Para manter uma hierarquia visual clara, cada triângulo de origem usa a espessura `semithick` do Ipe, enquanto os segmentos das construções mantêm a espessura `normal`.

### Retas definidoras

![Medianas, bissetrizes, mediatrizes e alturas](docs/images/02_defining_lines.png)

### Geometria de contato e cevianas

![Triângulo de contato, cevianas de Gergonne e cevianas de Nagel](docs/images/03_contact_and_cevian_geometry.png)

### Circunferência dos nove pontos

![Circunferência dos nove pontos com seus nove pontos definidores](docs/images/04_nine_point_circle.png)

### Construções dependentes de ponto

![Triângulo pedal e extremidades de cevianas a partir de um ponto selecionado](docs/images/05_reference_point_constructions.png)

### Conjugados

![Conjugados isogonal e isotômico de um ponto selecionado](docs/images/06_isogonal_isotomic_conjugates.png)

### Centros nomeados

![Centros de Brocard, isogônicos, isodinâmicos, simediano e de Napoleão](docs/images/07_selected_named_centers.png)

## Seleções aceitas

Antes de abrir um diálogo, selecione exatamente uma destas entradas:

1. Um caminho triangular fechado formado por segmentos retos.
2. Três marcas do Ipe posicionadas nos vértices.
3. Três segmentos retos que formem um único triângulo fechado.

Para uma construção dependente de ponto, acrescente uma marca ao caminho ou aos três lados selecionados. Com quatro marcas selecionadas, torne o ponto de referência a seleção primária; as outras três marcas definem o triângulo.

Não é necessário criar marcas auxiliares, e o Ipelet também não as insere. Para um caminho ou três lados, o vértice mais alto é `A` (em um empate horizontal, escolhe-se o mais à esquerda), e `B` e `C` seguem no sentido anti-horário. Com três marcas nos vértices, a marca primária é `A`; as demais seguem no sentido anti-horário. Essa ordem só interfere em resultados ligados a um vértice específico, como excentros e extremidades rotuladas das cevianas.

Coordenadas explícitas passadas pela API têm precedência sobre a seleção atual. A saída é criada na camada ativa por padrão; o diálogo também permite usar a camada do triângulo de origem. Camadas de saída invisíveis ou bloqueadas são informadas.

## Comportamento numérico

Todos os cálculos são executados em um sistema de coordenadas local normalizado. Os comprimentos usam uma versão escalonada de `hypot`, os pesos baricêntricos são normalizados antes da soma, a colinearidade é avaliada relativamente à escala do triângulo e cada ponto ou raio é verificado antes da criação do objeto no Ipe.

Assim, uma mesma forma triangular mantém o comportamento em escalas finitas muito pequenas ou muito grandes. Um triângulo realmente colinear ou excessivamente mal condicionado é recusado, em vez de produzir `NaN` ou coordenadas infinitas. Alguns centros são matematicamente não únicos ou ideais em casos simétricos; esse estado aparece explicitamente no resultado.

## Instalação

Na raiz do repositório, no Linux:

```bash
./scripts/install.sh triangles
```

O utilitário detecta a pasta do Ipe instalado por Flatpak. Para instalar manualmente, coloque `triangles.lua` na pasta de Ipelets do usuário e reinicie o Ipe.

## API pública

O arquivo exporta `_G.TRIANGLES` com versão de API 1. As funções de geometria pura podem ser utilizadas sem um modelo:

```lua
local result = TRIANGLES.triangle_center(
  { x = 0, y = 0 },
  { x = 4, y = 0 },
  { x = 1, y = 3 },
  "symmedian_point"
)
assert(result.status == "finite")
```

Os criadores públicos são `create_triangle_centers`, `create_triangle_derived` e `create_triangle_constructions`. Eles contêm erros de entrada e execução e retornam uma estrutura estável com `created`, `status`, contagens, estados por construção, papéis da saída, ordenação dos vértices e avisos. A inspeção de metadados continua disponível pela API Lua sem ocupar outra entrada no menu do Ipe.

## Validação

Execute a suíte específica com:

```bash
./scripts/validate.sh triangles
```

A suíte confere sintaxe, fórmulas, escalas extremas, triângulos especiais, todas as construções derivadas, contratos de seleção, afastamento dos rótulos, pré-visualização, estilos, camadas, transações, metadados, empacotamento e isolamento do arquivo autônomo. Quando o Flatpak do Ipe está disponível, ela também cria, salva e reabre um documento descartável pelo runtime real do Ipelib.

Os exemplos editáveis estão em [`examples/`](examples/README.md). O histórico está em [`CHANGELOG.md`](CHANGELOG.md).

## Licença

Triangles é licenciado sob a GNU General Public License, versão 3 ou qualquer versão posterior. Consulte [LICENSE](../LICENSE) e [NOTICE](../NOTICE.md).
