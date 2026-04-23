{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

import Data.Yaml (FromJSON(..), decodeFileEither, ParseException, encode)
import Data.Aeson (genericParseJSON, defaultOptions, fieldLabelModifier, ToJSON(..), object, (.=))
import GHC.Generics (Generic)
import Data.Text (Text)
import System.Process (callCommand)
import System.Directory (listDirectory)
import System.FilePath (takeBaseName)
import Control.Monad (forM_)
import Control.Exception (catch, SomeException)
import Data.Char (isSpace)
import Data.List (sort, isPrefixOf, isSuffixOf)
import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Map as Map
import Data.Map (Map)
import qualified Data.ByteString.Char8 as BS

-- | Representa uma transição individual do autômato
data Transition = Transition
  { from   :: String
  , symbol :: String
  , to     :: [String]
  } deriving (Show, Generic)

instance FromJSON Transition

-- | Estrutura principal que espelha o YAML do Professor Jefferson
data Automaton = Automaton
  { autoType     :: String
  , alphabet     :: [String]
  , states       :: [String]
  , initialState :: String
  , finalStates  :: [String]
  , transitions  :: [Transition]
  } deriving (Show, Generic)

-- Mapeamento para aceitar nomes com underscore no Haskell e nomes limpos no YAML
instance FromJSON Automaton where
  parseJSON = genericParseJSON defaultOptions 
    { fieldLabelModifier = \s -> case s of
        "autoType"     -> "type"
        "initialState" -> "initial_state"
        "finalStates"  -> "final_states"
        _              -> s 
    }

-- Instâncias ToJSON para exportar YAML
instance ToJSON Transition where
  toJSON t = object
    [ "from" .= from t
    , "symbol" .= symbol t
    , "to" .= to t
    ]

instance ToJSON Automaton where
  toJSON a = object
    [ "type" .= autoType a
    , "alphabet" .= alphabet a
    , "states" .= states a
    , "initial_state" .= initialState a
    , "final_states" .= finalStates a
    , "transitions" .= transitions a
    ]

-- | Valida um autômato e retorna erros ou sucesso
validateAutomaton :: Automaton -> Either String ()
validateAutomaton auto = do
    let stateSet = Set.fromList (states auto)
    let alphabetSet = Set.fromList (alphabet auto)
    let finalSet = Set.fromList (finalStates auto)
    
    -- Verificar se estado inicial existe
    if not (Set.member (initialState auto) stateSet)
        then Left $ "Estado inicial '" ++ initialState auto ++ "' não está na lista de estados"
        else Right ()
    
    -- Verificar se todos os estados finais existem
    let invalidFinals = Set.difference finalSet stateSet
    if not (Set.null invalidFinals)
        then Left $ "Estados finais inválidos: " ++ show (Set.toList invalidFinals)
        else Right ()
    
    -- Verificar transições
    let checkTransition t = do
            if not (Set.member (from t) stateSet)
                then Left $ "Estado origem '" ++ from t ++ "' não existe"
                else if symbol t /= "epsilon" && not (Set.member (symbol t) alphabetSet)
                    then Left $ "Símbolo '" ++ symbol t ++ "' não está no alfabeto"
                    else if any (\dest -> not (Set.member dest stateSet)) (to t)
                        then Left $ "Estado destino inválido em transição de '" ++ from t ++ "'"
                        else Right ()
    
    case mapM checkTransition (transitions auto) of
        Left err -> Left err
        Right _ -> Right ()

-- | Calcula o epsilon-closure de um estado (todos os estados alcançáveis por transições epsilon)
epsilonClosure :: Automaton -> String -> Set String
epsilonClosure auto startState = closure Set.empty [startState]
  where
    -- Mapa de transições epsilon para busca rápida: estado -> lista de listas de destinos
    epsilonTransitions = Map.fromListWith (++) 
        [(from t, [to t]) | t <- transitions auto, symbol t == "epsilon"]
    
    -- BFS para encontrar todos os estados alcançáveis
    closure :: Set String -> [String] -> Set String
    closure visited [] = visited
    closure visited (current:queue)
        | Set.member current visited = closure visited queue
        | otherwise = 
            let newVisited = Set.insert current visited
                epsilonDestLists = Map.findWithDefault [] current epsilonTransitions :: [[String]]
                epsilonDestinations = concat epsilonDestLists :: [String]
                newQueue = queue ++ epsilonDestinations
            in closure newVisited newQueue

-- | Converte NFAɛ para NFA (remove transições epsilon)
nfaeToNfa :: Automaton -> Either String Automaton
nfaeToNfa auto = do
    -- Verificar se é NFAɛ
    if autoType auto /= "nfae"
        then Left "Autômato deve ser do tipo 'nfae' para conversão"
        else Right ()
    
    -- Calcular novos estados finais (incluindo aqueles alcançáveis por epsilon dos finais originais)
    let originalFinals = Set.fromList (finalStates auto)
    let extendedFinals = Set.unions [epsilonClosure auto final | final <- finalStates auto]
    let newFinalStates = Set.toList $ Set.union originalFinals extendedFinals
    
    -- Calcular novas transições (remover epsilon e adicionar transições diretas)
    let nonEpsilonTransitions = [t | t <- transitions auto, symbol t /= "epsilon"]
    
    -- Para cada transição não-epsilon, calcular os destinos considerando epsilon-closure
    let newTransitions = concatMap (expandTransition auto) nonEpsilonTransitions
    
    Right auto
        { autoType = "nfa"
        , finalStates = newFinalStates
        , transitions = newTransitions
        }

-- | Expande uma transição considerando epsilon-closure
expandTransition :: Automaton -> Transition -> [Transition]
expandTransition auto trans = 
    let fromClosure = epsilonClosure auto (from trans)
        symbol = Main.symbol trans
        -- Para cada estado no closure de origem, encontrar destinos diretos
        directDestinations = concat [to t | t <- transitions auto, 
                                         from t `Set.member` fromClosure, 
                                         Main.symbol t == symbol]
        -- Aplicar epsilon-closure aos destinos diretos
        destinationClosures = Set.unions [epsilonClosure auto dest | dest <- directDestinations]
        newTo = Set.toList destinationClosures
    in if null newTo 
       then [] 
       else [trans { to = newTo }]

-- | Representação de expressões regulares
data Regex
    = REmpty
    | REpsilon
    | RSymbol Char
    | RConcat Regex Regex
    | RAlt Regex Regex
    | RStar Regex
    | RPlus Regex
    | ROpt Regex
    deriving (Show, Eq)

-- | Parser simples para expressões regulares
parseRegexString :: String -> Either String Regex
parseRegexString input =
    let cleaned = filter (not . isSpace) input
    in case parseAlt cleaned of
        Right (regex, "") -> Right regex
        Right (_, rest) -> Left $ "Entrada não consumida: " ++ rest
        Left err -> Left err
  where
    parseAlt s = do
        (term, rest1) <- parseConcat s
        parseAlt' term rest1
    parseAlt' left ('|':rest) = do
        (right, rest2) <- parseAlt rest
        Right (RAlt left right, rest2)
    parseAlt' left rest = Right (left, rest)

    parseConcat s = do
        (first, rest1) <- parseFactor s
        parseConcat' first rest1
    parseConcat' left rest@(')':_) = Right (left, rest)
    parseConcat' left rest@('|':_) = Right (left, rest)
    parseConcat' left rest@[] = Right (left, rest)
    parseConcat' left rest = do
        (next, rest2) <- parseFactor rest
        parseConcat' (RConcat left next) rest2

    parseFactor s = do
        (base, rest) <- parseBase s
        parsePostfix base rest
    parsePostfix base ('*':rest) = parsePostfix (RStar base) rest
    parsePostfix base ('+':rest) = parsePostfix (RPlus base) rest
    parsePostfix base ('?':rest) = parsePostfix (ROpt base) rest
    parsePostfix base rest = Right (base, rest)

    parseBase [] = Left "Expressão vazia ou parênteses faltando"
    parseBase ('(':rest) = do
        (inner, rest2) <- parseAlt rest
        case rest2 of
            (')':rest3) -> Right (inner, rest3)
            _ -> Left "Parênteses não fechados"
    parseBase (c:rest)
        | c `elem` ("|)*+?" :: String) = Left $ "Símbolo inesperado: " ++ [c]
        | otherwise = Right (RSymbol c, rest)

-- | Constrói um NFA a partir de uma expressão regular
regexToAutomaton :: Regex -> Automaton
regexToAutomaton regex =
    let (frag, _) = buildRegexFragment regex 0
        allStates = Set.toList $ Set.fromList (fragStates frag)
        allSymbols = Set.toList $ Set.fromList [ [c] | c <- fragAlphabet frag ]
    in Automaton
        { autoType = "nfae"
        , alphabet = allSymbols
        , states = allStates
        , initialState = fragStart frag
        , finalStates = [fragAccept frag]
        , transitions = fragTransitions frag
        }

data RegexFrag = RegexFrag
    { fragStates :: [String]
    , fragTransitions :: [Transition]
    , fragStart :: String
    , fragAccept :: String
    , fragAlphabet :: [Char]
    }

buildRegexFragment :: Regex -> Int -> (RegexFrag, Int)
buildRegexFragment REmpty n =
    let s = "q" ++ show n
        f = "q" ++ show (n+1)
    in (RegexFrag [s, f] [Transition s "epsilon" [f]] s f [], n+2)
buildRegexFragment REpsilon n =
    let s = "q" ++ show n
        f = "q" ++ show (n+1)
    in (RegexFrag [s, f] [Transition s "epsilon" [f]] s f [], n+2)
buildRegexFragment (RSymbol c) n =
    let s = "q" ++ show n
        f = "q" ++ show (n+1)
    in (RegexFrag [s, f] [Transition s [c] [f]] s f [c], n+2)
buildRegexFragment (RConcat r1 r2) n =
    let (frag1, n1) = buildRegexFragment r1 n
        (frag2, n2) = buildRegexFragment r2 n1
        trans = fragTransitions frag1 ++ fragTransitions frag2 ++ [Transition (fragAccept frag1) "epsilon" [fragStart frag2]]
        states = fragStates frag1 ++ fragStates frag2
        alpha = fragAlphabet frag1 ++ fragAlphabet frag2
    in (RegexFrag states trans (fragStart frag1) (fragAccept frag2) alpha, n2)
buildRegexFragment (RAlt r1 r2) n =
    let s = "q" ++ show n
        f = "q" ++ show (n+1)
        (frag1, n1) = buildRegexFragment r1 (n+2)
        (frag2, n2) = buildRegexFragment r2 n1
        trans = fragTransitions frag1 ++ fragTransitions frag2 ++
                [ Transition s "epsilon" [fragStart frag1]
                , Transition s "epsilon" [fragStart frag2]
                , Transition (fragAccept frag1) "epsilon" [f]
                , Transition (fragAccept frag2) "epsilon" [f]
                ]
        states = s : f : fragStates frag1 ++ fragStates frag2
        alpha = fragAlphabet frag1 ++ fragAlphabet frag2
    in (RegexFrag states trans s f alpha, n2)
buildRegexFragment (RStar r) n =
    let s = "q" ++ show n
        f = "q" ++ show (n+1)
        (frag, n1) = buildRegexFragment r (n+2)
        trans = fragTransitions frag ++
                [ Transition s "epsilon" [fragStart frag]
                , Transition s "epsilon" [f]
                , Transition (fragAccept frag) "epsilon" [fragStart frag]
                , Transition (fragAccept frag) "epsilon" [f]
                ]
        states = s : f : fragStates frag
        alpha = fragAlphabet frag
    in (RegexFrag states trans s f alpha, n1)
buildRegexFragment (RPlus r) n =
    let s = "q" ++ show n
        f = "q" ++ show (n+1)
        (frag, n1) = buildRegexFragment r (n+2)
        trans = fragTransitions frag ++
                [ Transition s "epsilon" [fragStart frag]
                , Transition (fragAccept frag) "epsilon" [fragStart frag]
                , Transition (fragAccept frag) "epsilon" [f]
                ]
        states = s : f : fragStates frag
        alpha = fragAlphabet frag
    in (RegexFrag states trans s f alpha, n1)
buildRegexFragment (ROpt r) n =
    let s = "q" ++ show n
        f = "q" ++ show (n+1)
        (frag, n1) = buildRegexFragment r (n+2)
        trans = fragTransitions frag ++
                [ Transition s "epsilon" [fragStart frag]
                , Transition s "epsilon" [f]
                , Transition (fragAccept frag) "epsilon" [f]
                ]
        states = s : f : fragStates frag
        alpha = fragAlphabet frag
    in (RegexFrag states trans s f alpha, n1)

-- | Converte NFA para DFA usando construção de subconjuntos
subsetConstruction :: Automaton -> Either String Automaton
subsetConstruction auto = do
    if autoType auto /= "nfa"
        then Left "Autômato deve ser do tipo 'nfa' para conversão"
        else Right ()
    let alphabetSymbols = alphabet auto
    let initialClosure = epsilonClosure auto (initialState auto)
    let initialStateName = stateSetToString initialClosure
    let (allStates, allTransitions) = buildDFATransitions auto alphabetSymbols initialClosure
    let originalFinals = Set.fromList (finalStates auto)
    let finalStatesDFA = [state | state <- allStates,
                           let stateSet = stringToStateSet state,
                           not $ Set.null $ Set.intersection stateSet originalFinals]
    Right auto
        { autoType = "dfa"
        , states = allStates
        , initialState = initialStateName
        , finalStates = finalStatesDFA
        , transitions = allTransitions
        }

-- | Constrói as transições do DFA usando BFS
buildDFATransitions :: Automaton -> [String] -> Set String -> ([String], [Transition])
buildDFATransitions auto alphabet initialStateSet = 
    let initialStateName = stateSetToString initialStateSet
        (finalStates, finalTransitions) = bfs [(initialStateSet, initialStateName)] Set.empty []
    in (finalStates, finalTransitions)
  where
    bfs [] visited transitions = (Set.toList visited, transitions)
    bfs ((currentSet, currentName):queue) visited transitions
        | Set.member currentName visited = bfs queue visited transitions
        | otherwise = 
            let newVisited = Set.insert currentName visited
                newTransitions = concatMap (createDFATransition auto currentSet currentName) alphabet
                newStates = [(destSet, destName) | Transition _ _ [destName] <- newTransitions, 
                           let destSet = stringToStateSet destName,
                           not $ Set.member destName newVisited]
            in bfs (queue ++ newStates) newVisited (transitions ++ newTransitions)

-- | Cria uma transição DFA para um símbolo específico
createDFATransition :: Automaton -> Set String -> String -> String -> [Transition]
createDFATransition auto fromSet fromName symbol =
    let -- Para cada estado no conjunto, encontrar destinos diretos para o símbolo
        directDestinations = concat [to t | t <- transitions auto, 
                                         from t `Set.member` fromSet, 
                                         Main.symbol t == symbol]
        -- Aplicar epsilon-closure aos destinos
        destinationClosure = Set.unions [epsilonClosure auto dest | dest <- directDestinations]
        destName = stateSetToString destinationClosure
    in if Set.null destinationClosure
       then [] 
       else [Transition fromName symbol [destName]]

-- | Converte um conjunto de estados para string representativa
stateSetToString :: Set String -> String
stateSetToString stateSet = 
    let sortedStates = Set.toAscList stateSet
    in "{" ++ unwords sortedStates ++ "}"

-- | Converte string representativa de volta para conjunto
stringToStateSet :: String -> Set String
stringToStateSet s = 
    let statesStr = take (length s - 2) (drop 1 s)  -- Remove { e }
    in if null statesStr 
       then Set.empty 
       else Set.fromList (words statesStr)

automatonToDot :: Automaton -> String
automatonToDot auto = unlines
    [ "digraph Automaton {"
    , "  rankdir=LR;"
    , "  node [shape=circle];"
    , "  " ++ nodeDeclarations auto
    , "  " ++ initialStateArrow auto
    , unlines $ map transitionToDot (transitions auto)
    , "}"
    ]

nodeDeclarations :: Automaton -> String
nodeDeclarations auto = 
    let finalStatesStr = unwords $ map (\s -> "\"" ++ s ++ "\"") (finalStates auto)
    in "node [shape=doublecircle] " ++ finalStatesStr ++ ";"

initialStateArrow :: Automaton -> String
initialStateArrow auto = 
    "init -> \"" ++ initialState auto ++ "\" [label=\" \"];"

transitionToDot :: Transition -> String
transitionToDot trans =
    let fromState = from trans
        symbolStr = symbol trans
        toStates = to trans
    in unwords $ map (\toState -> "\"" ++ fromState ++ "\" -> \"" ++ toState ++ "\" [label=\"" ++ symbolStr ++ "\"];") toStates

generateVisualization :: String -> IO ()
generateVisualization dotContent = do
    writeFile "automaton.dot" dotContent
    putStrLn "✓ Arquivo 'automaton.dot' gerado"
    
    putStrLn "Gerando PNG..."
    catch
        (callCommand "dot -Tpng automaton.dot -o automaton.png")
        (\e -> putStrLn $ "Aviso: PNG não gerado: " ++ show (e :: SomeException))
    putStrLn "✓ Arquivo 'automaton.png' gerado"
    
    putStrLn "Gerando SVG..."
    catch
        (callCommand "dot -Tsvg automaton.dot -o automaton.svg")
        (\e -> putStrLn $ "Aviso: SVG não gerado: " ++ show (e :: SomeException))
    putStrLn "✓ Arquivo 'automaton.svg' gerado"

-- | Salva um autômato em arquivo YAML
automatonToYaml :: Automaton -> String -> IO ()
automatonToYaml auto filename = do
    let yamlContent = BS.unpack $ encode auto
    writeFile filename yamlContent
    putStrLn $ "✓ Arquivo '" ++ filename ++ "' gerado"

main :: IO ()
main = do
    let arquivo = "data/entrada.yaml"
    resultado <- decodeFileEither arquivo :: IO (Either ParseException Automaton)
    case resultado of
        Left err -> putStrLn $ "Erro ao processar o arquivo: " ++ show err
        Right entrada -> do
            putStrLn "### Autômato de Entrada Carregado ###"
            print entrada
            
            -- Validar entrada
            case validateAutomaton entrada of
                Left validationErr -> putStrLn $ "Erro de validação: " ++ validationErr
                Right _ -> do
                    putStrLn "✓ Autômato validado com sucesso"
                    
                    -- Gerar visualização da entrada
                    putStrLn "\n### Gerando Visualização da Entrada ###"
                    let dotEntrada = automatonToDot entrada
                    generateVisualizationWithPrefix dotEntrada "entrada"
                    
                    -- Converter NFAɛ → NFA
                    putStrLn "\n### Convertendo NFAɛ → NFA ###"
                    case nfaeToNfa entrada of
                        Left nfaErr -> putStrLn $ "Erro na conversão NFAɛ→NFA: " ++ nfaErr
                        Right nfa -> do
                            putStrLn "✓ Conversão NFAɛ→NFA concluída"
                            print nfa
                            automatonToYaml nfa "data/saida_nfa.yaml"
                            
                            -- Gerar visualização do NFA
                            let dotNfa = automatonToDot nfa
                            generateVisualizationWithPrefix dotNfa "nfa"
                            
                            -- Converter NFA → DFA
                            putStrLn "\n### Convertendo NFA → DFA ###"
                            case subsetConstruction nfa of
                                Left dfaErr -> putStrLn $ "Erro na conversão NFA→DFA: " ++ dfaErr
                                Right dfa -> do
                                    putStrLn "✓ Conversão NFA→DFA concluída"
                                    print dfa
                                    automatonToYaml dfa "data/saida_dfa.yaml"
                                    
                                    -- Gerar visualização do DFA
                                    let dotDfa = automatonToDot dfa
                                    generateVisualizationWithPrefix dotDfa "dfa"
                                    
                                    putStrLn "\n✓ Processo completo finalizado!"
                                    putStrLn "Arquivos gerados:"
                                    putStrLn "  - data/saida_nfa.yaml (NFA resultante)"
                                    putStrLn "  - data/saida_dfa.yaml (DFA resultante)"
                                    putStrLn "  - outputs/visualizations/entrada.png/svg (visualização da entrada)"
                                    putStrLn "  - outputs/visualizations/nfa.png/svg (visualização do NFA)"
                                    putStrLn "  - outputs/visualizations/dfa.png/svg (visualização do DFA)"
                                    
                                    -- Parte 2: processar todos os arquivos regex em data/
                                    putStrLn "\n### Processando expressões regulares para NFA (Parte 2) ###"
                                    processRegexFiles

-- | Processa todos os arquivos data/regex*.txt
processRegexFiles :: IO ()
processRegexFiles = do
    files <- listDirectory "data"
    let regexFiles = sort ["data/" ++ f | f <- files, "regex" `isPrefixOf` f, ".txt" `isSuffixOf` f]
    if null regexFiles
        then putStrLn "Nenhum arquivo data/regex*.txt encontrado. Pulando Parte 2."
        else forM_ regexFiles $ \path -> do
            let base = takeBaseName path
            putStrLn $ "- Processando " ++ path
            regexText <- readFile path
            case parseRegexString regexText of
                Left parseErr -> putStrLn $ "  Erro ao parsear " ++ path ++ ": " ++ parseErr
                Right regexAst -> do
                    putStrLn $ "  Regex parseado: " ++ show regexAst
                    let regexNfa = regexToAutomaton regexAst
                    automatonToYaml regexNfa ("data/" ++ base ++ "_nfa.yaml")
                    let dotRegex = automatonToDot regexNfa
                    generateVisualizationWithPrefix dotRegex (base ++ "_nfa")
                    putStrLn $ "  ✓ Gerado data/" ++ base ++ "_nfa.yaml e outputs/visualizations/" ++ base ++ "_nfa.*"

-- | Gera visualização com prefixo nos nomes dos arquivos
generateVisualizationWithPrefix :: String -> String -> IO ()
generateVisualizationWithPrefix dotContent prefix = do
    let dotFile = "outputs/visualizations/" ++ prefix ++ ".dot"
        pngFile = "outputs/visualizations/" ++ prefix ++ ".png"
        svgFile = "outputs/visualizations/" ++ prefix ++ ".svg"
    
    writeFile dotFile dotContent
    putStrLn $ "✓ Arquivo '" ++ dotFile ++ "' gerado"
    
    putStrLn $ "Gerando " ++ prefix ++ ".png..."
    catch
        (callCommand $ "dot -Tpng " ++ dotFile ++ " -o " ++ pngFile)
        (\e -> putStrLn $ "Aviso: PNG não gerado: " ++ show (e :: SomeException))
    putStrLn $ "✓ Arquivo '" ++ pngFile ++ "' gerado"
    
    putStrLn $ "Gerando " ++ prefix ++ ".svg..."
    catch
        (callCommand $ "dot -Tsvg " ++ dotFile ++ " -o " ++ svgFile)
        (\e -> putStrLn $ "Aviso: SVG não gerado: " ++ show (e :: SomeException))
    putStrLn $ "✓ Arquivo '" ++ svgFile ++ "' gerado"