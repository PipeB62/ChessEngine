include("Evaluation.jl")
include("BoardAndPieces.jl")
using Random

global const engineName = "Chessinator 3000"

const LOG = open("debug.txt", "w")

function log(msg)

    """Create a log in the LOG file for debugging"""

    println(LOG, msg)
    flush(LOG)
end

function move_to_UCI(move)

    """Translate a move from our native language to the format required by UCI"""

    # Simple moves 
    if typeof(move) == SimpleMove || typeof(move) == EnPassant
        move_str = "$(cartesian_to_chess(move.from))$(cartesian_to_chess(move.to))"

    # Castling move
    elseif typeof(move) == Castle
        if move.color == white
            if move.side == queenside # Queenside castle
                move_str = "e1c1"
            else              # Kingside castle
                move_str = "e1g1"
            end
        else
            if move.side == queenside # Queenside castle
                move_str = "e8c8"
            else              # Kingside castle
                move_str = "e8g8"
            end
        end

    # Promotion move
    elseif typeof(move) == Promotion 
        letterDictionary = "xrnbqx"
        move_str = "$(cartesian_to_chess(move.from))$(cartesian_to_chess(move.to))$(letterDictionary[Int(move.promotes_to)])"
    end

    return move_str
end

function UCI_to_move(UCI_move, game_state)

    """Translate a move from UCI protocol to our native language"""

    # Parse incoming move
    UCI_from = UCI_move[1:2]  
    UCI_to   = UCI_move[3:4]  

    # Get all legal moves
    allmoves = get_all_moves(game_state)

    # Find matching move
    matched_move = nothing
    for move in allmoves

        if typeof(move) == SimpleMove || typeof(move) == EnPassant
            if cartesian_to_chess(move.from) == UCI_from && cartesian_to_chess(move.to) == UCI_to
                matched_move = move
                break
            end

        elseif typeof(move) == Castle
            if move.color == white
                if move.side == queenside # Queenside castle
                    if "e1" == UCI_from && "c1" == UCI_to
                        matched_move = move
                        break
                    end
                else              # Kingside castle
                    if "e1" == UCI_from && "g1" == UCI_to
                        matched_move = move
                        break
                    end
                end
            else
                if move.side == queenside # Queenside castle
                    if "e8" == UCI_from && "c8" == UCI_to
                        matched_move = move
                        break
                    end
                else              # Kingside castle
                    if "e8" == UCI_from && "g8" == UCI_to
                        matched_move = move
                        break
                    end
                end
            end


        elseif typeof(move) == Promotion
            letterDictionary = "xrnbqx"
            if cartesian_to_chess(move.from) == UCI_from && cartesian_to_chess(move.to) == UCI_to && letterDictionary[Int(move.promotes_to)] == UCI_move[5] 
                matched_move = move
                break
            end

        end
    end

    return matched_move
end

function show_moves(moves)
    for (i,move) in enumerate(moves)
        println(i," ", move)
    end
end 

function pvc()
    playercolor = white
    computercolor = black
    game_state = initalize_board()
    display(game_state)
    println()
    
    for i in 1:100
        allmoves = get_all_moves(game_state)
        if length(allmoves)==0
            if game_state.check
                print("checkmate")
            else
                print("stalemate")
            end
            break
        end
        
        if game_state.turn == playercolor
            show_moves(allmoves)
            println("Choose a move")
            moveindex = parse(Int, readline())
        else
            moveindex = rand(1:length(allmoves))  
        end

        move = allmoves[moveindex]
        if game_state.turn == computercolor
            readline()
            println("\033c")
            println("Computer move: ", move)
        end
        make_move!(game_state,move)
        display(game_state)
    end

end

function cvc()

    game_state = initalize_board()
    display(game_state)
    println()
    
    for i in 1:100
        allmoves = get_all_moves(game_state)
        if length(allmoves)==0
            if game_state.check
                print("checkmate")
            else
                print("stalemate")
            end
            break
        end
        
        move = negamax(game_state, 4)
        readline()
        println("\033c")
        println(game_state.turn, " move: ", move)

        make_move!(game_state,move)
        display(game_state)

        #consistensy check
        vision_graph_check = create_vision_graph(game_state.board, game_state.pieces)
        println("Vision graph consistent: ",vision_graph_check==game_state.vision_graph)
    end

end

function play_with_UCI()

    """Minimal function to play with CuteChess using UCI protocol"""

    # Initialize first game
    game_state = initalize_board()

    # Initialize the connection between engine and UI
    UI_message = readline()
    if UI_message == "uci"
        println("id name $engineName")
        println("id author FelipeLaRiataBenavides")
        println("uciok")
        flush(stdout) 
    end

    # Continous loop for engine - UI communication
    try 
        while true
            UI_message = readline()
            log("received: $UI_message")

            if UI_message == "isready"                  # UI asking if engine is alive
                println("readyok")
                flush(stdout)

            elseif UI_message == "ucinewgame"           # Create new game
                game_state = initalize_board()

            elseif startswith(UI_message, "position")   # Current position after their move
                UI_message_parts = split(UI_message)
                last_move = UI_message_parts[end]  

                # Handle the edge case where we are playing against a human playing white pieces
                if last_move == "startpos"
                    continue
                end

                move = UCI_to_move(last_move, game_state)
                log("Interpreted move as: $move")
                make_move!(game_state,move)

            elseif startswith(UI_message, "go")         # It is our turn
                allmoves = get_all_moves(game_state)

                # Decide our move
                moveindex = rand(1:length(allmoves)) 
                move = allmoves[moveindex]

                # Make our move for us and communicate to UI
                make_move!(game_state,move)
                UCI_move = move_to_UCI(move)
                println("bestmove ", UCI_move)
                flush(stdout)
                log("sent: bestmove $UCI_move")

            elseif UI_message == "quit"                 # Connection stopped
                break
            end

        end
    catch e
        log("ERROR: $e")
        log(stacktrace(catch_backtrace()))
    end

end

function main()
    # cvc()
    # pvc()

    play_with_UCI()
end

main()