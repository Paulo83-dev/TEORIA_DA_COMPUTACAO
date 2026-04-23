# Relatório da Parte 2 — Expressões Regulares

## Objetivo

A Parte 2 implementa a conversão de expressões regulares para autômatos finitos não determinísticos com epsilon-transições (NFAɛ).

## O que foi implementado

- Parser de expressões regulares com suporte a:
  - concatenação por justaposição
  - união (`|`)
  - fecho de Kleene (`*`)
  - repetição uma ou mais vezes (`+`)
  - opcional (`?`)
- Construção de NFAɛ usando a técnica de Thompson.
- Geração automática de saída YAML para cada regex em `data/`.
- Geração automática de diagramas Graphviz (`.dot`, `.png`, `.svg`) para cada regex processada.
- Processamento em lote de todos os arquivos `data/regex*.txt`.

## Arquivos usados

- `src/Main.hs` — código principal do projeto.
- `data/regex.txt` — regex de exemplo original.
- `data/regex1.txt` a `data/regex5.txt` — exemplos adicionais criados para a Parte 2.

## Como rodar

```bash
cd /workspaces/TEORIA_DA_COMPUTACAO
nix develop --command runghc src/Main.hs
```

Isso executa toda a Parte 1 e também processa todas as regex encontradas em `data/regex*.txt`.

## Saídas geradas

Para cada arquivo `data/regex*.txt`, o sistema gera:

- `data/<base>_nfa.yaml` — o NFAɛ convertido da expressão regular.
- `outputs/visualizations/<base>_nfa.dot` — representação Graphviz do NFA.
- `outputs/visualizations/<base>_nfa.png` — diagrama PNG.
- `outputs/visualizations/<base>_nfa.svg` — diagrama SVG.

Além disso, a execução da Parte 1 continua a gerar:

- `data/saida_nfa.yaml`
- `data/saida_dfa.yaml`
- `outputs/visualizations/entrada.*`
- `outputs/visualizations/nfa.*`
- `outputs/visualizations/dfa.*`

## Exemplos de regex adicionados

- `data/regex.txt`: `(0|1)*1`
- `data/regex1.txt`: `(0|1)*1`
- `data/regex2.txt`: `a(b|c)+`
- `data/regex3.txt`: `(a|b)c?d*`
- `data/regex4.txt`: `ab|cd`
- `data/regex5.txt`: `(0|1)(0|1)(0|1)`

## Observações

- A abordagem adotada mantém cada regex em um arquivo separado para facilitar a visualização e a comparação de resultados.
- O processamento em lote permite adicionar novos exemplos sem alterar o código do `Main.hs`.
- O relatório pode ser usado como evidência de que a Parte 2 foi implementada e testada com múltiplos casos.
