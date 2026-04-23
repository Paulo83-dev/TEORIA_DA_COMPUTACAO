## Laboratório 01: Linguagens Regulares

Teoria da Computação

Prof. Dr. Jefferson O. Andrade

Semestre 2026.1

## 1 Objetivos

1. Implementar algoritmos fundamentais de conversão entre modelos de autômatos finitios.
2. Explorar a equivalência entre Expressões Regulares (RE) e Autômatos.
3. Desenvolver habilidades práticas em manipulação de linguagens formais e ferramentas de reprodução ( Nix ).

## 2 Parte 1: Conversão de Autômatos (NFAɛ → DFA)

Você deve implementar um programa que realize as seguintes transformações:

- NFAɛ → NFA: Remoção de transições vazias.
- NFA → DFA: Construção de subconjuntos (Subset Construction).

O programa deve ser capaz de ler a definição de um autômato a partir de um arquivo YAML e exportar o resultado equivalente no mesmo formato.

## 2.1 Especificação YAML do Autômato

Os arquivos de entrada e saída devem seguir a estrutura abaixo:

```
# Exemplo de um NFA type : nfae # Pode ser 'dfa', 'nfa', 'nfae' alphabet : [0, 1] states : [q0, q1, q2] initial_state : q0 final_states : [q2] transitions : -from : q0 symbol : 0 to : [q0, q1] -from : q0 symbol : epsilon # Use 'epsilon' para transições vazias to : [q1] -from : q1 symbol : 1 to : [q2]
```

## 3 Parte 2: Implementação de Expressões Regulares

Desenvolva um motor de reconhecimento ou um gerador de autômatos baseado em expressões regulares. A sintaxe aceita deve seguir os padrões:

- Concatenação: Justaposição ( ab ).
- União: Barra vertical ( a|b ).
- Fecho de Kleene: Asterisco ( a* ).
- Uma ou mais repetições: Sinal de soma ( a+ ).
- Opcional: Ponto de interrogação ( a? ), equivalente a (a|epsilon) .

Dica: Utilize o paradigma funcional (Haskell, F#, Clojure ou Scala) para facilitar a construção da árvore sintática e a conversão para autômatos via construção de Thompson .

## 4 Parte 3: Regex Crossword

1. Resolva de 5 quebra-cabeças da seção 'Challenges' no site Regex Crossword.
2. Crie um novo quebra-cabeça na seção Player Puzzles :
- Deve possuir no mínimo 25 células (ex: 5×5).
- Será avaliado pela complexidade das expressões e criatividade do resultado.

## 5 Instruções de Entrega

O trabalho deve ser enviado via AVA (Moodle) em um arquivo .zip contendo:

1. Código Fonte: Incluindo o arquivo flake.nix ou shell.nix para garantir a reprodutibilidade do ambiente.
2. Relatório (PDF): Contendo as capturas de tela das soluções do Regex Crossword e o link/detalhes do quebra-cabeça criado.

## 5.1 Critérios de Avaliação

- Correção algorítmica das conversões.
- Robustez do parser de Expressões Regulares.
- Variedade e complexidade no quebra-cabeça autoral.