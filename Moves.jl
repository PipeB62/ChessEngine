include("BoardAndPieces.jl")

# Pseudo-legal move = Move that follows the ruled of the pieces and stays in the board but may allow a discovered check. Except castle

#Directions for move generation in mailbox 
global const UP = 10
global const DOWN = -10
global const RIGHT = 1
global const LEFT = -1
global const ALL_DIRECTIONS = [UP, UP+RIGHT, RIGHT, DOWN+RIGHT, DOWN, DOWN+LEFT, LEFT, UP+LEFT]
global const KNIGHT_JUMPS = [UP+UP+RIGHT, UP+UP+LEFT, 
                             RIGHT+RIGHT+UP, RIGHT+RIGHT+DOWN,
                             LEFT+LEFT+UP, LEFT+LEFT+DOWN,
                             DOWN+DOWN+RIGHT, DOWN+DOWN+LEFT]
global const ROOK_DIRECTIONS = [UP, DOWN, RIGHT, LEFT]
global const BISHOP_DIRECTIONS = [UP+RIGHT, DOWN+RIGHT, UP+LEFT, DOWN+LEFT]

struct SimpleMove <: AbstractMove #Everything except castling, enpassant and promotions
    piece_id::Int  
    piece::Piece
    from::Int
    to::Int
    captured_piece_id::Int #0 for no capture
    captured_piece::Piece
end

function Base.show(io::IO, move::SimpleMove) 
    """
    Printing simple moves using julia's print function
    """
    from_text = square_to_chess(move.from)
    to_text = square_to_chess(move.to)
    if move.captured_piece_id == 0
        print(io, move.piece, " ", from_text, " to ", to_text)
    else
        print(io, move.piece, " ", from_text, " takes ", to_text)
    end
end 

@enum CastleSide queenside=1 kingside=2
struct Castle <: AbstractMove
    king_id::Int
    rook_id::Int
    king_from::Int
    king_to::Int
    rook_from::Int
    rook_to::Int
    side::CastleSide
end

function Base.show(io::IO, move::Castle)
    """
    Printing castle moves using julia's print function
    """
    print(io, "Castle ", move.side)
end 

struct Promotion <: AbstractMove
    piece_id::Int
    from::Int
    to::Int
    captured_piece_id::Int #0 for no capture
    captured_piece::Piece
    promotes_to::Piece
end

function Base.show(io::IO, move::Promotion)
    """
    Printing promotions using julia's print function
    """
    from_text = square_to_chess(move.from)
    to_text = square_to_chess(move.to)
    if move.captured_piece_id == 0
        print(io, "pawn ", from_text, " to ", to_text, ", promotes to ", move.promotes_to)
    else
        print(io, "pawn ", from_text, " takes ", to_text, ", promotes to ", move.promotes_to)
    end
end 

struct EnPassant <: AbstractMove
    piece_id::Int
    from::Int
    to::Int
    captured_square::Int 
    captured_piece_id::Int #0 for no capture
end

function Base.show(io::IO, move::EnPassant)
    """
    Printing en-passant using julia's print function
    """
    from_text = square_to_chess(move.from)
    to_text = square_to_chess(move.to)
    capture_text = square_to_chess(move.captured_square)
    print(io, "pawn ", from_text, " t0 ", to_text, " takes ", capture_text, " en-passant")
end 

function is_under_attack(square::Int, attacked_by_color::Color, game_state::GameState)
    """
    Returns true if square is under attack by a piece of color "attacked_by_color" in the board of the given game_state
    Checks for all possible attacks
    """

    mailbox_index = mailbox64[square]
    color = get_opposite_color(attacked_by_color)

    #check knight attacks
    for d in KNIGHT_JUMPS
        newsquare = mailbox[mailbox_index+d]
        if newsquare>0 #check if it is inside the board
            if game_state.pieces[newsquare]==knight && game_state.colors[newsquare]==attacked_by_color 
                return true
            end
        end
    end

    #check pawn attacks
    if color==white
        infront = UP
    else
        infront = DOWN
    end
    for d in [RIGHT,LEFT]
        newsquare = mailbox[mailbox_index+d+infront]
        if newsquare>0 #check if it is inside the board
            if game_state.pieces[newsquare]==pawn && game_state.colors[newsquare]==attacked_by_color 
                return true
            end
        end
    end

    #check long range attacks
    for d in ROOK_DIRECTIONS
        v = d
        inside = true
        while inside
            newsquare = mailbox[mailbox_index+v]
            if newsquare>0 # check if it is inside the board
                piece = game_state.pieces[newsquare]
                if piece==no_piece # empty square
                    v += d
                    continue
                elseif (piece==rook || piece==queen) && game_state.colors[newsquare]==attacked_by_color
                    return true
                else
                    break
                end
            else
                inside = false
            end
        end
    end

    for d in BISHOP_DIRECTIONS
        v = d
        inside = true
        while inside
            newsquare = mailbox[mailbox_index+v]
            if newsquare>0 #check if it is inside the board
                piece = game_state.pieces[newsquare]
                if piece==no_piece #empty square
                    v += d
                    continue
                elseif (piece==bishop || piece==queen) && game_state.colors[newsquare]==attacked_by_color
                    return true
                else
                    break
                end
            else
                inside = false
            end
        end
    end

    #king attacks
    for d in ALL_DIRECTIONS
        newsquare = mailbox[mailbox_index+d]
        if newsquare>0 #check if it is inside the board
            if game_state.pieces[newsquare]==king && game_state.colors[newsquare]==attacked_by_color 
                return true
            end
        end
    end

    return false
end

function discovered_attack(attacked_by_color::Color, game_state::GameState)
    """
    Returns true if king is under attack by a piece of color "attacked_by_color" in the board of the given game_state, but
    only checks for attacks from slider pieces (queen, rook, bishop). Used to determine if the king is exposed by a discovered attack
    after a pseudo legal move in make_move!
    """
    king_id = get_king_id(get_opposite_color(attacked_by_color))
    square = game_state.piece_list[king_id]

    mailbox_index = mailbox64[square]
        
    #check long range attacks
    for d in ROOK_DIRECTIONS
        v = d
        inside = true
        while inside
            newsquare = mailbox[mailbox_index+v]
            if newsquare>0 # check if it is inside the board
                piece = game_state.pieces[newsquare]
                if piece==no_piece # empty square
                    v += d
                    continue
                elseif (piece==rook || piece==queen) && game_state.colors[newsquare]==attacked_by_color #It is attacked by opponent slider.
                    return true
                else #It encounters a same color piece or non-attacking opponent piece
                    break
                end
            else #It reaches the end of the board
                inside = false
            end
        end
    end

    for d in BISHOP_DIRECTIONS
        v = d
        inside = true
        while inside
            newsquare = mailbox[mailbox_index+v]
            if newsquare>0 #check if it is inside the board
                piece = game_state.pieces[newsquare]
                if piece==no_piece #empty square
                    v += d #Move one more square in direction d
                    continue
                elseif (piece==bishop || piece==queen) && game_state.colors[newsquare]==attacked_by_color #It is attacked by opponent slider.
                    return true
                else #It encounters a same color piece or non-attacking opponent piece
                    break
                end
            else #It reaches the end of the board
                inside = false 
            end
        end
    end

    return false
end 

function is_in_check(color::Color, game_state::GameState)
    """
    Returns true if the king of color "color" is under attack in the given game_state
    """

    king_id = get_king_id(color)
    king_square = game_state.piece_list[king_id] #Get current position of the king

    if king_square == 0
        println("What")
        display(game_state.move_stack)
        display(game_state)
        readline()
    end
    
    return is_under_attack(king_square, get_opposite_color(color), game_state) #check if the king's square is under attack
end

"""
Following are all the make_move! functions for the different move types. 
Takes as input the game_state and a pseudo-legal move. 
If the pseudo-legal move is illegal, it will not change the game_state and return false.
If the pseudo-legal move is legal, it will apply the changes and return true
"""
function make_move!(game_state::GameState, move::SimpleMove)

    color = game_state.turn
    opposite_color = get_opposite_color(color)

    #Update piece board
    game_state.pieces[move.from] = no_piece
    game_state.pieces[move.to] = move.piece

    #Update color board
    game_state.colors[move.from] = no_color
    game_state.colors[move.to] = color

    #Update piece list
    game_state.piece_list[move.piece_id] = move.to
    if move.captured_piece_id>0
        game_state.piece_list[move.captured_piece_id] = 0
    end

    #check if move is legal
    if first(game_state.check_stack) || move.piece_id == get_king_id(color)
        exposed_king = is_in_check(color, game_state)
    else
        exposed_king = discovered_attack(opposite_color, game_state)
    end

    if exposed_king #undomove
        #Undo piece board
        game_state.pieces[move.from] = move.piece
        game_state.pieces[move.to] = move.captured_piece

        #Undo color board
        game_state.colors[move.from] = color
        if move.captured_piece_id>0
            game_state.colors[move.to] = opposite_color
        else
            game_state.colors[move.to] =  no_color
        end

        game_state.piece_list[move.piece_id] = move.from
        if move.captured_piece_id>0
            game_state.piece_list[move.captured_piece_id] = move.to
        end

        return false
    else
        
        #Update turn 
        game_state.turn = opposite_color

        #Update check stack
        push!(game_state.check_stack, is_in_check(opposite_color, game_state)) #See if move puts the opponent's king in check

        #Update move stack
        push!(game_state.move_stack, move)

        #Update counter
        game_state.piece_move_count[move.piece_id] += 1

        return true
    end

end

function make_move!(game_state::GameState, move::Castle) #No need to verify if legal. It is done on move generation

    color = game_state.turn
    opposite_color = get_opposite_color(game_state.turn)

    #Update pieces
    game_state.pieces[move.king_from] = no_piece
    game_state.pieces[move.king_to] = king
    game_state.pieces[move.rook_from] = no_piece
    game_state.pieces[move.rook_to] = rook

    #Update color
    game_state.colors[move.king_from] = no_color
    game_state.colors[move.king_to] = color
    game_state.colors[move.rook_from] = no_color
    game_state.colors[move.rook_to] = color

    #Update piece list
    game_state.piece_list[move.king_id] = move.king_to
    game_state.piece_list[move.rook_id] = move.rook_to

    #Update turn 
    game_state.turn = opposite_color

    #Update check stack
    push!(game_state.check_stack, is_in_check(opposite_color, game_state)) #See if move puts the opponent's king in check

    #Update move stack
    push!(game_state.move_stack, move)

    #Update counter
    game_state.piece_move_count[move.rook_id] += 1
    game_state.piece_move_count[move.king_id] += 1

    return true
end

function make_move!(game_state::GameState, move::Promotion)

    color = game_state.turn
    opposite_color = get_opposite_color(color)

    #Update piece board
    game_state.pieces[move.from] = no_piece
    game_state.pieces[move.to] = move.promotes_to

    #Update color board
    game_state.colors[move.from] = no_color
    game_state.colors[move.to] = color

    #Update piece list
    game_state.piece_list[move.piece_id] = move.to
    if move.captured_piece_id>0
        game_state.piece_list[move.captured_piece_id] = 0
    end

    #check if move is legal
    if first(game_state.check_stack) || move.piece_id == get_king_id(color)
        exposed_king = is_in_check(color, game_state)
    else
        exposed_king = discovered_attack(opposite_color, game_state)
    end
    if exposed_king #undomove
        #Undo piece board
        game_state.pieces[move.from] = pawn
        game_state.pieces[move.to] = move.captured_piece

        #Undo color board
        game_state.colors[move.from] = color
        if move.captured_piece_id > 0
            game_state.colors[move.to] = opposite_color
        else
            game_state.colors[move.to] =  no_color
        end

        game_state.piece_list[move.piece_id] = move.from
        if move.captured_piece_id>0
            game_state.piece_list[move.captured_piece_id] = move.to
        end

        return false
    else

        #Update turn 
        game_state.turn = opposite_color

        #Update check stack
        push!(game_state.check_stack, is_in_check(opposite_color, game_state)) #See if move puts the opponent's king in check

        #Update move stack
        push!(game_state.move_stack, move)

        #Update counter
        game_state.piece_move_count[move.piece_id] += 1

        return true
    end

end

function make_move!(game_state::GameState, move::EnPassant)

    color = game_state.turn
    opposite_color = get_opposite_color(color)

    #Update piece board
    game_state.pieces[move.from] = no_piece
    game_state.pieces[move.to] = pawn
    game_state.pieces[move.captured_square] = no_piece

    #Update color board
    game_state.colors[move.from] = no_color
    game_state.colors[move.to] = color
    game_state.colors[move.captured_square] = no_color

    #Update piece list
    game_state.piece_list[move.piece_id] = move.to
    game_state.piece_list[move.captured_piece_id] = 0

    #check if move is legal
    if first(game_state.check_stack) || move.piece_id == get_king_id(color)
        exposed_king = is_in_check(color, game_state)
    else
        exposed_king = discovered_attack(opposite_color, game_state)
    end

    if exposed_king #undomove
        #Undo piece board
        game_state.pieces[move.from] = pawn
        game_state.pieces[move.to] = no_piece
        game_state.pieces[move.captured_square] = pawn

        #Undo color board
        game_state.colors[move.from] = color
        game_state.colors[move.to] = no_color
        game_state.colors[move.captured_square] = opposite_color

        game_state.piece_list[move.piece_id] = move.from
        game_state.piece_list[move.captured_piece_id] = move.captured_square

        return false
    else

        #Update turn 
        game_state.turn = opposite_color

        #Update check stack
        push!(game_state.check_stack, is_in_check(opposite_color, game_state)) #See if move puts the opponent's king in check

        #Update move stack
        push!(game_state.move_stack, move)

        #Update counter
        game_state.piece_move_count[move.piece_id] += 1

        return true
    end

end

"""
Following are the undo_board! functions.
They take as input the current game_state and the last move. 
They undo: piece_board, color_board, piece_list, and piece_move count.
Only to be used inside the unmake_move! function
"""

function undo_board!(game_state::GameState, move::SimpleMove)

    color = get_opposite_color(game_state.turn)
    opposite_color = game_state.turn

    #Undo piece board
    game_state.pieces[move.from] = move.piece
    game_state.pieces[move.to] = move.captured_piece

    game_state.piece_list[move.piece_id] = move.from

    #Undo color board
    game_state.colors[move.from] = color
    if move.captured_piece_id>0
        game_state.colors[move.to] = opposite_color
        game_state.piece_list[move.captured_piece_id] = move.to 
    else
        game_state.colors[move.to] =  no_color
    end

    game_state.piece_move_count[move.piece_id] -= 1

end

function undo_board!(game_state::GameState, move::Castle)

    color = get_opposite_color(game_state.turn)

    #Undo pieces
    game_state.pieces[move.king_from] = king
    game_state.pieces[move.king_to] = no_piece
    game_state.pieces[move.rook_from] = rook
    game_state.pieces[move.rook_to] = no_piece

    #Undo color
    game_state.colors[move.king_from] = color
    game_state.colors[move.king_to] = no_color
    game_state.colors[move.rook_from] = color
    game_state.colors[move.rook_to] = no_color

    #Undo piece list
    game_state.piece_list[move.king_id] = move.king_from
    game_state.piece_list[move.rook_id] = move.rook_from

    #Undo piece move count 
    game_state.piece_move_count[move.rook_id] -= 1
    game_state.piece_move_count[move.king_id] -= 1
end

function undo_board!(game_state::GameState, move::EnPassant)

    color = get_opposite_color(game_state.turn)
    opposite_color = game_state.turn

    #Undo piece board
    game_state.pieces[move.from] = pawn
    game_state.pieces[move.to] = no_piece
    game_state.pieces[move.captured_square] = pawn

    #Undo color board
    game_state.colors[move.from] = color
    game_state.colors[move.to] = no_color
    game_state.colors[move.captured_square] = opposite_color

    #Undo piece list
    game_state.piece_list[move.piece_id] = move.from
    game_state.piece_list[move.captured_piece_id] = move.captured_square

    #Undo piece move count 
    game_state.piece_move_count[move.piece_id] -= 1

end

function undo_board!(game_state::GameState, move::Promotion)

    color = get_opposite_color(game_state.turn)
    opposite_color = game_state.turn

    #Undo piece board
    game_state.pieces[move.from] = pawn
    game_state.pieces[move.to] = move.captured_piece

    game_state.piece_list[move.piece_id] = move.from #Undo piece list

    #Undo color board
    game_state.colors[move.from] = color
    if move.captured_piece_id > 0
        game_state.colors[move.to] = opposite_color
        game_state.piece_list[move.captured_piece_id] = move.to #Undo piece list
    else
        game_state.colors[move.to] =  no_color
    end

    #Undo piece move count 
    game_state.piece_move_count[move.piece_id] -= 1
end

function unmake_move!(game_state::GameState)
    """Unmake last move from the move_stack"""

    #Remove last move from stack
    last_move = pop!(game_state.move_stack)

    #Undo board and counter
    undo_board!(game_state, last_move)

    #Update turn 
    opposite_color = get_opposite_color(game_state.turn)
    game_state.turn = opposite_color

    #Update check
    pop!(game_state.check_stack)

    return game_state

end

"""
available_moves_x functions to be used only inside the get_all moves function for consistency. 
They generate available pseudo-legal moves for piece of type x
"""

function available_moves_pawn(piece_id::Int, square::Int, game_state::GameState) #pseudo legal moves

    mailbox_index = mailbox64[square]
    color = game_state.turn
    opposite_color = get_opposite_color(game_state.turn)
    rank = get_rank(square)

    promotions = [bishop, knight, rook, queen]

    if color == white
        infront = UP
        starting_rank = 2
        promotion_rank = 7
        enpassant_rank = 5
    else 
        infront = DOWN
        starting_rank = 7
        promotion_rank = 2
        enpassant_rank = 4
    end

    #moves = AbstractMove[]
    promotion_moves = AbstractMove[]
    capture_moves = AbstractMove[] #including promotion+capture
    quiet_moves = AbstractMove[] #no promotion, no captures

    #Advance move
    newsquare = mailbox[mailbox_index+infront]
    if newsquare>0 && game_state.pieces[newsquare]==no_piece

        if rank == promotion_rank #If the pawn is on the promotion rank, consider all possible promotions
            for promotes_to in promotions
                move = Promotion(piece_id, square, newsquare, 0, no_piece, promotes_to)
                push!(promotion_moves, move)
            end
        else
            move = SimpleMove(piece_id, pawn, square, newsquare, 0, no_piece)
            push!(quiet_moves, move)
        end

    end

    #Double advance move
    passing_square = mailbox[mailbox_index+infront]
    newsquare = mailbox[mailbox_index+infront+infront]
    if rank == starting_rank && game_state.pieces[passing_square] == no_piece && game_state.pieces[newsquare] == no_piece

        move = SimpleMove(piece_id, pawn, square, newsquare, 0, no_piece)
        push!(quiet_moves, move)
    end

    #Captures. Consider capture+promotion
    for d in [RIGHT, LEFT]
        newsquare = mailbox[mailbox_index+infront+d]

        if newsquare > 0 #is inside the board
            if game_state.colors[newsquare]==opposite_color #is occupied by opposite color piece
                seen_piece = game_state.pieces[newsquare]
                seen_piece_id = findfirst(x->x==newsquare, game_state.piece_list)
                if rank == promotion_rank #If the pawn is on the promotion rank, consider all possible promotions
                    for promotes_to in promotions
                        move = Promotion(piece_id, square, newsquare, seen_piece_id, seen_piece, promotes_to)
                        push!(capture_moves, move)
                    end
                else
                    move = SimpleMove(piece_id, pawn, square, newsquare, seen_piece_id, seen_piece)
                    push!(capture_moves, move)
                end
            end
        end 
    end

    #En passant
    if length(game_state.move_stack)>3 && rank==enpassant_rank
        last_move = first(game_state.move_stack)

        if last_move isa SimpleMove
            last_move_displacement = abs(last_move.from - last_move.to)

            if last_move.piece == pawn && last_move_displacement == 16
                d = get_file(last_move.to) - get_file(square)

                if abs(d)==1
                    newsquare = mailbox[mailbox_index+infront+d]
                    captured_square = mailbox[mailbox_index+d]
                    captured_id = findfirst(x->x==captured_square, game_state.piece_list)

                    if game_state.pieces[newsquare] == no_piece #this should be unnecessary since last move checked it is empty
                        move = EnPassant(piece_id, square, newsquare, captured_square, captured_id)
                        push!(capture_moves, move)
                    end
                end

            end
        end
    end

    return promotion_moves, capture_moves, quiet_moves
end

function available_moves_king(piece_id::Int, square::Int, game_state::GameState) #pseudo legal moves
    "Get pseudo-legal moves available to the king. "
    mailbox_index = mailbox64[square]
    opposite_color = get_opposite_color(game_state.turn)

    #moves = AbstractMove[]
    capture_moves = AbstractMove[]
    quiet_moves = AbstractMove[]

    #Normal moves
    for d in ALL_DIRECTIONS
        newsquare = mailbox[mailbox_index+d]

        if newsquare>0 #is inside the board
            seen_piece = game_state.pieces[newsquare]

            if seen_piece==no_piece
                move = SimpleMove(piece_id, king, square, newsquare, 0, no_piece)
                push!(quiet_moves, move)

            elseif game_state.colors[newsquare]==opposite_color
                captured_id = findfirst(x->x==newsquare, game_state.piece_list)
                move = SimpleMove(piece_id, king, square, newsquare, captured_id, seen_piece)
                push!(capture_moves, move)
            end
        end
    end

    #Castling
    if game_state.piece_move_count[piece_id] == 0 && first(game_state.check_stack) == false #king has not moved and is not in check
        if game_state.turn == white
            kingside_rook_id = 8
            kingside_path = [6,7]
            queenside_rook_id = 1
            queenside_path = [4,3]
            queenside_passing_square = 2
        else
            kingside_rook_id = 32
            kingside_path = [62, 63]
            queenside_rook_id = 25
            queenside_path = [60, 59]
            queenside_passing_square = 58
        end

        #kingside castle 
        if game_state.piece_move_count[kingside_rook_id]==0 && game_state.piece_list[kingside_rook_id]>0 #if kingside rook has not moved and is not captured
            free_path = true
            for path_square in kingside_path
                if !(game_state.pieces[path_square]==no_piece) || is_under_attack(path_square, opposite_color, game_state) #square is occupied or attacked
                    free_path=false
                    break
                end
            end

            if free_path
                move = Castle(piece_id, kingside_rook_id, square, kingside_path[end], game_state.piece_list[kingside_rook_id], kingside_path[1], kingside)
                push!(quiet_moves, move)
            end

        end

        #queenside castle 
        if game_state.piece_move_count[queenside_rook_id]==0 && game_state.piece_list[queenside_rook_id]>0 #if queenside rook has not moved and is not captured
            if game_state.pieces[queenside_passing_square]==no_piece #Passing square is not occupied
                free_path = true
                for path_square in queenside_path
                    if !(game_state.pieces[path_square]==no_piece) || is_under_attack(path_square, opposite_color, game_state) #square is occupied or attacked
                        free_path=false
                        break
                    end
                end

                if free_path
                    move = Castle(piece_id, queenside_rook_id, square, queenside_path[end], game_state.piece_list[queenside_rook_id], queenside_path[1], queenside)
                    push!(quiet_moves, move)
                end
            end
        end
    end

    return capture_moves, quiet_moves

end

function available_moves_knight(piece_id::Int, square::Int, game_state::GameState)

    mailbox_index = mailbox64[square]
    opposite_color = get_opposite_color(game_state.turn)

    #moves = AbstractMove[]
    capture_moves = AbstractMove[]
    quiet_moves = AbstractMove[]

    for d in KNIGHT_JUMPS
        newsquare = mailbox[mailbox_index+d]
        if newsquare>0 #check if it is inside the board
            seen_piece = game_state.pieces[newsquare]
            if seen_piece==no_piece
                move = SimpleMove(piece_id, knight, square, newsquare, 0, no_piece)
                push!(quiet_moves, move)
            elseif game_state.colors[newsquare]==opposite_color
                captured_id = findfirst(x->x==newsquare,game_state.piece_list)
                move = SimpleMove(piece_id, knight, square, newsquare, captured_id, seen_piece)
                push!(capture_moves, move)
            end
        end
    end

    return capture_moves, quiet_moves
end

function available_moves_slider(piece_id::Int, piece::Piece, square::Int, game_state::GameState)

    if piece == rook 
        directions = ROOK_DIRECTIONS
    elseif piece == bishop 
        directions = BISHOP_DIRECTIONS 
    elseif piece == queen 
        directions = ALL_DIRECTIONS
    end

    mailbox_index = mailbox64[square]
    opposite_color = get_opposite_color(game_state.turn)

    #moves = AbstractMove[]
    capture_moves = AbstractMove[]
    quiet_moves = AbstractMove[]

    for d in directions
        v = d
        inside = true
        while inside
            newsquare = mailbox[mailbox_index + v] #Move one square in direction d

            if newsquare>0 #check if it is inside the board
                seen_piece = game_state.pieces[newsquare] #get piece currently sitting in new square

                if seen_piece==no_piece #empty square. possible quiet move
                    move = SimpleMove(piece_id, piece, square, newsquare, 0, no_piece)
                    push!(quiet_moves, move)
                    v += d

                elseif game_state.colors[newsquare]==opposite_color #Opposite color piece, possible capture
                    captured_id = findfirst(x->x==newsquare, game_state.piece_list)
                    move = SimpleMove(piece_id, piece, square, newsquare, captured_id, seen_piece)
                    push!(capture_moves, move)
                    break

                else #it encountered a same color piece
                    break

                end

            else #reached end of the board
                inside = false
            end
        end
    end

    return capture_moves, quiet_moves
end

function get_all_moves(game_state::GameState)
    """
    Returns list of all available pseudo-legal moves in the position
    """
    all_promotions = []
    all_captures = []
    all_quiet = []
    
    if game_state.turn == white
        turn_ids = 16:-1:1
    else
        turn_ids = 17:32
    end

    for piece_id in turn_ids
        square = game_state.piece_list[piece_id]

        if square > 0 #Piece is still on the board
            piece = game_state.pieces[square]
            if piece == pawn 
                promotion_moves, capture_moves, quiet_moves = available_moves_pawn(piece_id, square, game_state)
                append!(all_promotions, promotion_moves)
            elseif piece == king 
                capture_moves, quiet_moves = available_moves_king(piece_id, square, game_state)
            elseif piece == knight
                capture_moves, quiet_moves = available_moves_knight(piece_id, square, game_state)
            else
                capture_moves, quiet_moves = available_moves_slider(piece_id, piece, square, game_state)
            end
            append!(all_captures, capture_moves)
            append!(all_quiet, quiet_moves)
        end
    end

    all_moves = AbstractMove[]
    append!(all_moves, all_promotions)
    append!(all_moves, all_captures)
    append!(all_moves, all_quiet)

    return all_moves
end

function is_legal(game_state::GameState, move::AbstractMove)
    """
    Returns true if pseudo-legal move "move" is legal. game_state remains unchanged
    """
    islegal = make_move!(game_state, move)
    if islegal 
        unmake_move!(game_state)
        return true
    else
        return false
    end
end

function get_legal_moves(game_state::GameState)
    """
    Generates a list of all legal moves available in the position.
    """
    moves = get_all_moves(game_state)
    moves = filter!(m->is_legal(game_state,m), moves)
    return moves
end

function square_distance(square_a::Int, square_b::Int)
    file_a = get_file(square_a)
    rank_a = get_rank(square_a)

    file_b = get_file(square_b)
    rank_b = get_rank(square_b)

    return max(abs(file_a - file_b), abs(rank_a - rank_b))
end

function is_diagonal(square_a::Int, square_b::Int)
    file_a = get_file(square_a)
    rank_a = get_rank(square_a)

    file_b = get_file(square_b)
    rank_b = get_rank(square_b)

    if rank_a != rank_b && file_a != file_b
        return true
    else
        return false
    end
end

function main()
    game_state = initalize_board()
    display(game_state)

    moves = get_all_moves(game_state)
    moves = filter!(m->is_legal(game_state,m), moves)
    display(moves)

end
#main()