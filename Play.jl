include("Evaluation.jl")
include("BoardAndPieces.jl")
using Random

global const ENGINE_NAME = "Chessinator 3000"

const LOG = open("debug.txt", "w")

# Optimizations: Using FEN can be optimized if we loosen the of certain pieces having certain id's  

function log(msg)

    """Create a log in the LOG file for debugging"""

    println(LOG, msg)
    flush(LOG)
end

function parse_position(position_msg::String)
    
    """
    Parse a message when the first word is 'position' to get the game state.

    This obtains the current position by starting from starpos or fen_str and doing all the moves described
    by the position_msg. This approach, where we create a new board each time, allows us to start from any 
    arbitrary position, go back and analyze a position as well as play fisher chess in the future. 
    """

    parts = split(position_msg)

    # Check what type of positional decription we received
    if parts[2] == "startpos"
        game_state = initalize_board()
        idx = 3  # After "position startpos" we would have "moves" or nothing
    
    elseif parts[2] == "fen"
        # Parse the position message to work out the initial position
        moves_idx = findfirst(==("moves"), parts)
        fen_end = isnothing(moves_idx) ? length(parts) : moves_idx - 1
        fen_str = join(parts[3:fen_end], " ")
        game_state = board_from_fen(fen_str) 

        # Where is "moves"?
        idx = isnothing(moves_idx) ? length(parts) + 1 : moves_idx  

    else
        throw(ErrorException("Unknown position type: $(parts[2])"))

    end

    # Replay all moves listed after "moves"
    if idx <= length(parts) && parts[idx] == "moves"
        for i in (idx + 1):length(parts)
            move = UCI_to_move(parts[i], game_state)
            make_move!(game_state, move)
        end
    end

    return game_state
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
        move_str = "$(square_to_chess(move.from))$(square_to_chess(move.to))$(get_letter_from_piece(move.promotes_to) == UCI_move[5])"
    
    else
        throw(ErrorException("Invalid type of move: $(typeof(move))"))

    end

    return move_str
end

function UCI_to_move(UCI_move, game_state)

    """Translate a move from UCI protocol to our native language by constructing the move"""

    # Parse incoming move
    square_from = chess_to_square(UCI_move[1:2])  
    square_to = chess_to_square(UCI_move[3:4])  

    # Get move information
    moving_piece = game_state.pieces[square_from]
    moving_piece_id = findfirst(x->x==square_from, game_state.piece_list)
    captured_piece = game_state.pieces[square_to]
    captured_piece_id = captured_piece == no_piece ? 0 : findfirst(x->x==square_to, game_state.piece_list)

    # Promotion (Checks if there is a piece promoted indicator)
    matched_move = Nothing
    if length(UCI_move) == 5                                   
        promotes_to = get_piece_from_letter("$(UCI_move[5])")
        matched_move = Promotion(moving_piece_id, square_from, square_to, captured_piece_id, captured_piece, promotes_to)

    # EnPassant (Checks if it is a pawn move that does not directly capture a piece and is diagonal)
    elseif moving_piece == pawn && captured_piece == no_piece && is_diagonal(square_from, square_to)
        # Offset because we don't capture where we go but one rank up/down depending on what color we are
        offset = game_state.turn == white ? 8 : -8
        captured_square = square_to - offset
        captured_piece_id = findfirst(x->x==captured_square, game_state.piece_list)
        matched_move = EnPassant(moving_piece_id, square_from, square_to, captured_square, captured_piece_id)

    # Castle (Checks if the king moved more than 1 position)
    elseif moving_piece == king && square_distance(square_from, square_to) > 1 
        if UCI_move[3] == "c"
            side = queenside
            rook_from = chess_to_square("a$(UCI_move[2])")
            rook_to = chess_to_square("d$(UCI_move[2])")
        else 
            side = kingside
            rook_from = chess_to_square("h$(UCI_move[2])")
            rook_to = chess_to_square("f$(UCI_move[2])")
        end
        rook_id = findfirst(x->x==rook_from, game_state.piece_list)
        matched_move = Castle(moving_piece_id, rook_id, square_from, square_to, rook_from, rook_to, side)

    # SimpleMove
    else  
        matched_move = SimpleMove(moving_piece_id, moving_piece, square_from, square_to, captured_piece_id, captured_piece)

    end

    if isnothing(matched_move)
        throw(ErrorException("Could not create move from: $UCI_move"))
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
        
        print("Calculating... ")
        move, score = negamax2(game_state, 4)
        println("Done")
        readline()
        println("\033c")
        println(game_state.turn, " move: ", move, " score: ", score)

        make_move!(game_state,move)
        println(first(game_state.move_stack))
        display(game_state)

    end

end

function play_with_UCI(engine_type, depth)

    """Minimal function to play with CuteChess using UCI protocol"""

    # Initialize first game
    game_state = initalize_board()

    # Initialize the connection between engine and UI
    UI_message = readline()
    if UI_message == "uci"
        println("id name $ENGINE_NAME")
        println("id author FelipeLaRiataBenavides") #jajajaj
        println("uciok")
        flush(stdout) 
    end

    # Continous loop for engine - UI communication
    try 
        while true
            UI_message = readline()
            log("Received: $UI_message")

            # UI asking if engine is alive
            if UI_message == "isready"                  
                println("readyok")
                flush(stdout)

            # Create new game
            elseif UI_message == "ucinewgame"          
                game_state = initalize_board()

            # Current position after their move
            elseif startswith(UI_message, "position")  
                game_state = parse_position(UI_message) 

            # It is our turn
            elseif startswith(UI_message, "go")  
                if engine_type == "rand"
                    allmoves = get_legal_moves(game_state)
                    score = 0
                    moveindex = rand(1:length(allmoves))
                    move = allmoves[moveindex]
                elseif engine_type == "negamax"
                    # Get best move and score
                    move, score = negamax2(game_state, depth)
                end
                UCI_move = move_to_UCI(move)

                # Communicate move and score
                println("info score cp $(Int(score*100))")
                println("bestmove ", UCI_move)
                flush(stdout)

                log("Game evaluated as cp: $(Int(score*100))")
                log("Sent: bestmove $UCI_move")

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

    play_with_UCI("negamax", 4)
end

main()