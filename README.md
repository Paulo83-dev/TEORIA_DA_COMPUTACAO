# TEORIA DA COMPUTAÇÃO

Projeto de laboratório para a disciplina de Teoria da Computação.

## Estrutura do repositório

- `src/` — código fonte Haskell do trabalho
- `data/` — arquivos YAML de entrada e saída
- `outputs/visualizations/` — diagramas gerados em DOT, PNG e SVG
- `docs/` — enunciado da atividade e evidências da parte 3
- `puzzles_resolvidos/` — imagens dos puzzles resolvidos do Regex Crossword
- `flake.nix` / `flake.lock` — ambiente Nix reproduzível

## Conteúdo principal

- `src/Main.hs` — código que lê `data/entrada.yaml`, converte NFAɛ → NFA → DFA, e salva os resultados em YAML e imagens.
- `data/entrada.yaml` — exemplo de autômato de entrada.
- `data/saida_nfa.yaml` — resultado da conversão NFAɛ → NFA.
- `data/saida_dfa.yaml` — resultado da conversão NFA → DFA.
- `docs/ATIVIDADE_LINGUAGENS_REGULARES.md` — enunciado da atividade.
- `docs/RELATORIO_PARTE2.md` — relatório da Parte 2 com regex, conversão para NFAɛ e saídas geradas.
- `docs/Player Puzzles.md` — link do regex crossword autoral e comprovante da parte 3.
- `puzzles_resolvidos/` — capturas das telas dos exercícios resolvidos no Regex Crossword.

## Como executar

Execute no ambiente Nix:

```bash
cd /workspaces/TEORIA_DA_COMPUTACAO
nix develop --command runghc src/Main.hs
```

Saídas geradas em:

- `data/saida_nfa.yaml`
- `data/saida_dfa.yaml`
- `outputs/visualizations/entrada.png`
- `outputs/visualizations/nfa.png`
- `outputs/visualizations/dfa.png`

## Observações

- A parte 1 está implementada com a conversão completa de NFAɛ → NFA → DFA.
- A parte 2 implementa conversão de expressões regulares para NFAɛ com parser de regex e geração de saídas em `data/` e `outputs/visualizations/`.
- A parte 3 está registrada em `docs/Player Puzzles.md` e as imagens estão em `puzzles_resolvidos/`.

