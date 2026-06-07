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
        move_str = "$(square_to_chess(move.from))$(square_to_chess(move.to))"

    # Castling move
    elseif typeof(move) == Castle
        move_str = "$(square_to_chess(move.king_from))$(square_to_chess(move.king_to))"

    # Promotion move
    elseif typeof(move) == Promotion 
        letterDictionary = "xrnbqx"
        move_str = "$(square_to_chess(move.from))$(square_to_chess(move.to))$(letterDictionary[Int(move.promotes_to)])"
    end

    return move_str
end

function UCI_to_move(UCI_move, game_state)

    """Translate a move from UCI protocol to our native language"""

    # Parse incoming move
    UCI_from = UCI_move[1:2]  
    UCI_to   = UCI_move[3:4]  

    # Get all legal moves
    allmoves = get_legal_moves(game_state)

    # Find matching move
    matched_move = nothing
    for move in allmoves
        if typeof(move) == SimpleMove || typeof(move) == EnPassant
            if square_to_chess(move.from) == UCI_from && square_to_chess(move.to) == UCI_to
                matched_move = move
                break
            end

        elseif typeof(move) == Castle
            if square_to_chess(move.king_from) == UCI_from && square_to_chess(move.king_to) == UCI_to
                matched_move = move
                break
            end


        elseif typeof(move) == Promotion
            letterDictionary = "xrnbqx"
            if square_to_chess(move.from) == UCI_from && square_to_chess(move.to) == UCI_to && letterDictionary[Int(move.promotes_to)] == UCI_move[5] 
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
    playercolor = black
    computercolor = white
    game_state = initalize_board()
    display(game_state)
    println()
    
    for i in 1:100
        allmoves = get_legal_moves(game_state)
        if length(allmoves)==0
            if first(game_state.check_stack)
                print("checkmate")
            else
                print("stalemate")
            end
            break
        end
        show_moves(allmoves)
        if game_state.turn == playercolor
            
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
    
    for i in 1:1000
        allmoves = get_all_moves(game_state)
        if length(allmoves)==0
            if game_state.check
                print("checkmate")
            else
                print("stalemate")
            end
            break
        end
        
        print("Calculating... ")
        move, score = negamax2(game_state, 5)
        println("Done")
        #readline()
        println("\033c")
        println(game_state.turn, " move: ", move, " score: ", score)

        make_move!(game_state,move)
        println(first(game_state.move_stack))
        display(game_state)

    end

end

function play_with_UCI(sim_type, depth)

    """Minimal function to play with CuteChess using UCI protocol"""

    # Initialize first game
    game_state = initalize_board()

    # Initialize the connection between engine and UI
    UI_message = readline()
    if UI_message == "uci"
        println("id name $engineName")
        println("id author FelipeLaRiataBenavides") #jajajaj
        println("uciok")
        flush(stdout) 
    end

    # Continous loop for engine - UI communication
    try 
        while true
            UI_message = readline()
            log("received: $UI_message")

            # UI asking if engine is alive
            if UI_message == "isready"                  
                println("readyok")
                flush(stdout)

            # Create new game
            elseif UI_message == "ucinewgame"          
                game_state = initalize_board()

            # Current position after their move
            elseif startswith(UI_message, "position")   
                UI_message_parts = split(UI_message)
                last_move = UI_message_parts[end]  

                # Handle the edge case where we are playing against a human playing white pieces
                if last_move == "startpos"
                    continue
                end

                move = UCI_to_move(last_move, game_state)
                log("Interpreted move as: $move")
                make_move!(game_state,move)

            # It is our turn
            elseif startswith(UI_message, "go")    
                if sim_type == "rand"     
                    allmoves = get_legal_moves(game_state)

                    # Decide our move
                    moveindex = rand(1:length(allmoves)) 
                    move = allmoves[moveindex]
                elseif sim_type == "negamax"
                    move, score = negamax2(game_state, depth)
                end

                # Make our move for us and communicate to UI
                make_move!(game_state,move)
                UCI_move = move_to_UCI(move)
                println("bestmove ", UCI_move)
                flush(stdout)
                log("sent: bestmove $UCI_move")

            # Connection stopped
            elseif UI_message == "quit"                 
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

    play_with_UCI("negamax", 5)
end

main()