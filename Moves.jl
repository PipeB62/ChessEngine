include("BoardAndPieces.jl")


struct SimpleMove <: AbstractMove
    piece_id::Int
    piece::Piece
    from::CartesianIndex
    to::CartesianIndex
    captured_piece_id::Int #0 for no capture
end

function Base.show(io::IO, move::SimpleMove)
    from_text = cartesian_to_chess(move.from)
    to_text = cartesian_to_chess(move.to)
    if move.captured_piece_id == 0
        print(io, move.piece.type, " ", from_text, " to ", to_text)
    else
        print(io, move.piece.type, " ", from_text, " takes ", to_text)
    end
end 

@enum CastleSide queenside=1 kingside=2
struct Castle <: AbstractMove
    king_id::Int
    rook_id::Int
    color::PieceColor
    side::CastleSide
end

function Base.show(io::IO, move::Castle)
    print(io, "Castle ", move.side)
end 

struct Promotion <: AbstractMove
    piece_id::Int
    piece::Piece
    from::CartesianIndex
    to::CartesianIndex
    captured_piece_id::Int #0 for no capture
    promotes_to::PieceType
end

function Base.show(io::IO, move::Promotion)
    from_text = cartesian_to_chess(move.from)
    to_text = cartesian_to_chess(move.to)
    if move.captured_piece_id == 0
        print(io, move.piece.type, " ", from_text, " to ", to_text, ", promotes to ", move.promotes_to)
    else
        print(io, move.piece.type, " ", from_text, " takes ", to_text, ", promotes to ", move.promotes_to)
    end
end 

struct EnPassant <: AbstractMove
    piece_id::Int
    piece::Piece
    from::CartesianIndex
    to::CartesianIndex
    captured_piece_id::Int #0 for no capture
end

function Base.show(io::IO, move::EnPassant)
    
    if move.piece.color==white
        direction = UP
    else
        direction = DOWN
    end

    from_text = cartesian_to_chess(move.from)
    to_text = cartesian_to_chess(move.to)
    capture_text = cartesian_to_chess(move.to-direction)
    print(io, move.piece.type, " ", from_text, " t0 ", to_text, " takes ", capture_text, " en-passant")
end 


function is_in_check(color::PieceColor, vision_graph, pieces)

    king_id = get_king_id(color)
    king_observers = is_seen_by(king_id, vision_graph) #All pieces that see the king
    filter!(x -> pieces[x].color==get_opposite_color(color), king_observers) #Filter only pieces with opposite color

    if length(king_observers)>0 #king is in check
        check = true
    else
        check = false
    end

    return check
end

function is_king_exposed(newboard, moved_piece_id, captured_id, game_state::GameState)
    #check if a move exposes the king without need of recalculating the whole vision graph again

    piece = game_state.pieces[moved_piece_id]
    seen_by = is_seen_by(moved_piece_id, game_state.vision_graph) #Pieces that see the piece

    king_id = get_king_id(piece.color)

    long_range_pieces = [queen, bishop, rook]

    exposesking = false
    for observer_piece_id in seen_by
        
        observer_piece = game_state.pieces[observer_piece_id]

        if observer_piece.color == piece.color #Same color piece can't check its own king
            continue
        end

        if observer_piece.type in long_range_pieces && observer_piece_id != captured_id
            observer_new_vision = calculate_vision(observer_piece_id, newboard, game_state.pieces)
            observer_new_vision_pieces = filter(x->(x>0) , newboard[observer_new_vision])

            if king_id in observer_new_vision_pieces
                exposesking = true
                break
            end
        end
    end

    return exposesking
end

function update_vision_graph!(vision_graph, move::SimpleMove, newboard, pieces)

    from_square_node_id = LinearIndices((8,8))[move.from] + 32 #Square nodes go from 33 to 96
    to_square_node_id = LinearIndices((8,8))[move.to] + 32 

    #Remove arrow from_square->piece, and all arrows piece -> squares
    rem_edge!(vision_graph, from_square_node_id, move.piece_id) 
    outneighs = [i for i in outneighbors(vision_graph, move.piece_id)] 
    for square_id in outneighs
        rem_edge!(vision_graph, move.piece_id, square_id)
    end

    if length(outneighbors(vision_graph,move.piece_id))>0
        print("Edges not removed properly, 1")
    end

    #If capture, remove arrow to_square -> captured_piece, and all arrows captured_piece -> squares
    if move.captured_piece_id>0

        rem_edge!(vision_graph, to_square_node_id, move.captured_piece_id)

        outneighs = [i for i in outneighbors(vision_graph, move.captured_piece_id)] 
        for i in outneighs
            rem_edge!(vision_graph, move.captured_piece_id, i)
        end

        if length(outneighbors(vision_graph,move.piece_id))>0
            print("Edges not removed properly, 2")
        end
    end

    #Add arrow to_square -> piece 
    add_edge!(vision_graph, to_square_node_id, move.piece_id)

    #Update vision of moved piece 
    new_vision = calculate_vision(move.piece_id, newboard, pieces)
    new_vision_node_ids = LinearIndices((8,8))[new_vision] .+ 32
    for square_id in new_vision_node_ids
        add_edge!(vision_graph, move.piece_id, square_id)
    end

    #Update vision of long range pieces that saw the moved piece (discovery) and pieces that see the to_square (blocks)
    long_range_pieces = [queen, bishop, rook]
    update_ids1 = inneighbors(vision_graph, from_square_node_id) 
    update_ids2 = inneighbors(vision_graph, to_square_node_id) 
    update_ids = union(update_ids1, update_ids2) #Join without repetition 
    filter!(x->x!=move.piece_id, update_ids) #Remove moved piece from list

    for update_piece_id in update_ids
        
        update_piece = pieces[update_piece_id]

        if update_piece.type in long_range_pieces #Only need to update long range pieces
            
            #Remove current edges
            outneighs = [i for i in outneighbors(vision_graph, update_piece_id)] 
            for square_id in outneighs
                rem_edge!(vision_graph, update_piece_id, square_id)
            end

            if length(outneighbors(vision_graph, update_piece_id))>0
                print("Edges not removed properly, 3")
            end
            
            new_vision = calculate_vision(update_piece_id, newboard, pieces)
            new_vision_node_ids = LinearIndices((8,8))[new_vision] .+ 32
            for square_id in new_vision_node_ids
                add_edge!(vision_graph, update_piece_id, square_id) 
            end

        end
    end

    return vision_graph

end 

function make_move!(game_state::GameState, move::SimpleMove)

    opposite_color = get_opposite_color(game_state.turn)

    #Update board
    game_state.board[move.from] = 0
    game_state.board[move.to] = move.piece_id

    #Update vision_graph from updated board (pieces dont change)
    update_vision_graph!(game_state.vision_graph, move, game_state.board, game_state.pieces) 

    #Update turn 
    game_state.turn = opposite_color

    #Update check.
    game_state.check = is_in_check(opposite_color, game_state.vision_graph, game_state.pieces) #See if move puts the opponent's king in check

    #Update last move
    game_state.last_move = move

    #Update counter
    game_state.pieces_move_count[move.piece_id] += 1

    return game_state

end

function make_move!(game_state::GameState, move::Castle)

    king_from_row = 5
    if move.side == kingside
        king_to_row = 7
        rook_from_row = 8
        rook_to_row =  6
    else
        king_to_row = 3
        rook_from_row = 1
        rook_to_row =  4
    end

    if move.color == white
        rank = 1
    else 
        rank = 8
    end

    opposite_color = get_opposite_color(game_state.turn)

    #Update board
    game_state.board[king_from_row, rank] = 0
    game_state.board[king_to_row, rank] = move.king_id
    game_state.board[rook_from_row, rank] = 0
    game_state.board[rook_to_row, rank] = move.rook_id

    #Update vision_graph from updated board (pieces dont change)
    game_state.vision_graph = create_vision_graph(game_state.board, game_state.pieces) #Vision graph from scratch

    #Update turn 
    game_state.turn = opposite_color

    #Update check.
    game_state.check = is_in_check(opposite_color, game_state.vision_graph, game_state.pieces) #See if move puts the opponent's king in check

    #Update last move
    game_state.last_move = move

    #Update counter
    game_state.pieces_move_count[move.rook_id] += 1
    game_state.pieces_move_count[move.king_id] += 1

    return game_state
end

function make_move!(game_state::GameState, move::Promotion)
    opposite_color = get_opposite_color(game_state.turn)

    #Update board
    game_state.board[move.from] = 0
    game_state.board[move.to] = move.piece_id

    #Update pieces
    game_state.pieces[move.piece_id] = Piece(move.piece.color, move.promotes_to)

    #Update vision_graph from updated board 
    game_state.vision_graph = create_vision_graph(game_state.board, game_state.pieces) #Vision graph from scratch

    #Update turn 
    game_state.turn = opposite_color

    #Update check.
    game_state.check = is_in_check(opposite_color, game_state.vision_graph, game_state.pieces) #See if move puts the opponent's king in check

    #Update last move
    game_state.last_move = move

    #Update counter
    game_state.pieces_move_count[move.piece_id] += 1

    return game_state
end

function make_move!(game_state::GameState, move::EnPassant)

    if move.piece.color==white
        direction = UP
    else
        direction = DOWN
    end

    opposite_color = get_opposite_color(game_state.turn)

    #Update board
    game_state.board[move.from] = 0
    game_state.board[move.to] = move.piece_id
    game_state.board[move.to-direction] = 0 #capture pawn

    #Update vision_graph from updated board (pieces dont change)
    game_state.vision_graph = create_vision_graph(game_state.board, game_state.pieces) #Vision graph from scratch

    #Update turn 
    game_state.turn = opposite_color

    #Update check.
    game_state.check = is_in_check(opposite_color, game_state.vision_graph, game_state.pieces) #See if move puts the opponent's king in check

    #Update last move
    game_state.last_move = move

    #Update counter
    game_state.pieces_move_count[move.piece_id] += 1

    return game_state
end


function available_moves_pawn(piece_id, game_state::GameState)

    piece = game_state.pieces[piece_id]
    vision = get_square_vision(piece_id, game_state.vision_graph) #squares seen by the piece (for pawns its the diagonals)
    current_position = get_position(piece_id,game_state.board) #Current position (coordinates) of the piece
    promotions = [bishop, knight, rook, queen]

    if piece.color == white
        infront = current_position + UP
        infront2 = infront + UP
        starting_rank = 2
        promotion_rank = 7
        enpassant_rank = 5
    else 
        infront = current_position + DOWN
        infront2 = infront + DOWN
        starting_rank = 7
        promotion_rank = 2
        enpassant_rank = 4
    end

    opposite_color = get_opposite_color(piece.color)

    moves = AbstractMove[]

    #Advance move
    if game_state.board[infront] == 0

        newboard = copy(game_state.board)
        newboard[current_position] = 0
        newboard[infront] = piece_id

        #make sure the move does not expose the king
        exposedking = is_king_exposed(newboard, piece_id, 0, game_state)

        incheck = game_state.check
        if incheck #If the king is in check, only accept moves that block
            new_vision_graph = create_vision_graph(newboard,game_state.pieces) #For check revision, not necessary to update game_state.pieces in case of promotion
            incheck = is_in_check(piece.color, new_vision_graph, game_state.pieces)
        end

        if !exposedking && !incheck
            if current_position[2] == promotion_rank #If the pawn is on the promotion rank, consider all possible promotions
                for promotes_to in promotions
                    move = Promotion(piece_id, piece, current_position, infront, 0, promotes_to)
                    push!(moves, move)
                end
            else
                move = SimpleMove(piece_id, piece, current_position, infront, 0)
                push!(moves, move)
            end
        end 

    end

    #Double advance move
    if current_position[2] == starting_rank && game_state.board[infront] == 0 && game_state.board[infront2] == 0 

        newboard = copy(game_state.board)
        newboard[current_position] = 0
        newboard[infront2] = piece_id

        #make sure the move does not expose the king
        exposedking = is_king_exposed(newboard, piece_id, 0, game_state)

        incheck = game_state.check
        if incheck #If the king is in check, only accept moves that block
            new_vision_graph = create_vision_graph(newboard,game_state.pieces) #For check revision, not necessary to update game_state.pieces in case of promotion
            incheck = is_in_check(piece.color, new_vision_graph, game_state.pieces)
        end

        if !exposedking && !incheck
            move = SimpleMove(piece_id, piece, current_position, infront2, 0)
            push!(moves, move)
        end 

    end

    #Captures. Consider capture+promotion
    for square in vision
        square_id = game_state.board[square]

        if square_id > 0 && game_state.pieces[square_id].color == opposite_color #Square is occupied by opposite color

            captured_id = square_id
            newboard = copy(game_state.board)
            newboard[current_position] = 0
            newboard[square] = piece_id

            #make sure the move does not expose the king
            exposedking = is_king_exposed(newboard, piece_id, captured_id, game_state)

            incheck = game_state.check
            if incheck #If the king is in check, only accept moves that block
                new_vision_graph = create_vision_graph(newboard,game_state.pieces) #For check revision, not necessary to update game_state.pieces in case of promotion
                incheck = is_in_check(piece.color, new_vision_graph, game_state.pieces)
            end

            if !exposedking && !incheck
                if current_position[2] == promotion_rank #If the pawn is on the promotion rank, consider all possible promotions
                    for promotes_to in promotions
                        move = Promotion(piece_id, piece, current_position, square, captured_id, promotes_to)
                        push!(moves, move)
                    end
                else
                    move = SimpleMove(piece_id, piece, current_position, square, captured_id)
                    push!(moves, move)
                end
            end
        end 
    end

    #En passant
    if current_position[2] == enpassant_rank
        last_move_vector = game_state.last_move.from - game_state.last_move.to
        if game_state.last_move.piece.type == pawn && abs(last_move_vector[2])==2

            sides = [RIGHT, LEFT]
            for side in sides
                side_id = game_state.board[current_position+side]
                if side_id == game_state.last_move.piece_id #en passant possible
                    captured_id = side_id

                    newboard = copy(game_state.board)
                    newboard[current_position] = 0
                    newboard[current_position+side] = 0
                    newboard[infront+side] = piece_id

                    #make sure the move does not expose the king
                    exposedking = is_king_exposed(newboard, piece_id, captured_id, game_state)

                    incheck = game_state.check
                    if incheck #If the king is in check, only accept moves that block
                        new_vision_graph = create_vision_graph(newboard,game_state.pieces) #For check revision, not necessary to update game_state.pieces in case of promotion
                        incheck = is_in_check(piece.color, new_vision_graph, game_state.pieces)
                    end

                    if !exposedking && !incheck
                        move = EnPassant(piece_id, piece, current_position, infront+side, captured_id)
                        push!(moves, move)
                    end 

                    break
                end

            end

        end

    end

    return moves


end

function available_moves_king(piece_id, game_state::GameState)

    piece = game_state.pieces[piece_id]
    vision = get_square_vision(piece_id, game_state.vision_graph) #squares seen by the piece (for pawns its the diagonals)
    current_position = get_position(piece_id,game_state.board) #Current position (coordinates) of the piece

    opposite_color = get_opposite_color(piece.color)

    moves = AbstractMove[]

    #Normal moves
    for square in vision
        square_protectors = is_seen_by(square, game_state.vision_graph)
        filter!(x -> game_state.pieces[x].color==opposite_color, square_protectors) #Filter only pieces with opposite color
        square_id = game_state.board[square]
        if length(square_protectors)==0 #square is not protected

            if square_id == 0 #square is free
                captured_id = 0
            elseif square_id > 0 && game_state.pieces[square_id].color == opposite_color #square is occupied by opposite color piece
                captured_id = square_id
            else #square is occupied by same color piece
                continue
            end

            newboard = copy(game_state.board)
            newboard[current_position] = 0
            newboard[square] = piece_id

            exposedking = is_king_exposed(newboard, piece_id, captured_id, game_state)

            if !exposedking
                move = SimpleMove(piece_id, piece, current_position, square, captured_id)
                push!(moves, move)
            end
        end

    end

    #Castling
    if game_state.pieces_move_count[piece_id] == 0 && game_state.check == false #king has not moved and is not in check
        if piece.color == white
            kingside_rook_id = 8
            kingside_path = [CartesianIndex(6,1),CartesianIndex(7,1)]
            queenside_rook_id = 1
            queenside_path = [CartesianIndex(4,1),CartesianIndex(3,1),CartesianIndex(2,1)]
        else
            kingside_rook_id = 32
            kingside_path = [CartesianIndex(6,8),CartesianIndex(7,8)]
            queenside_rook_id = 25
            queenside_path = [CartesianIndex(4,8),CartesianIndex(3,8),CartesianIndex(2,8)]
        end

        #kingside castle 
        if game_state.pieces_move_count[kingside_rook_id]==0 #if kingside rook has not moved
            free_path = true
            for path_square in kingside_path
                if game_state.board[path_square]>0 #square is occupied
                    free_path=false
                    break
                end
                square_attackers = is_seen_by(path_square, game_state.vision_graph)
                filter!(x -> game_state.pieces[x].color==opposite_color, square_attackers) #Filter only pieces with opposite color
                if length(square_attackers)>0
                    free_path = false
                    break
                end
            end

            if free_path
                move = Castle(piece_id, kingside_rook_id, piece.color, kingside)
                push!(moves, move)
            end

        end

        #queenside castle 
        if game_state.pieces_move_count[queenside_rook_id]==0 #if queenside rook has not moved
            free_path = true
            for path_square in queenside_path
                if game_state.board[path_square]>0 #square is occupied
                    free_path=false
                    break
                end
                square_attackers = is_seen_by(path_square, game_state.vision_graph)
                filter!(x -> game_state.pieces[x].color==opposite_color, square_attackers) #Filter only pieces with opposite color
                if length(square_attackers)>0
                    free_path = false
                    break
                end
            end

            if free_path
                move = Castle(piece_id, queenside_rook_id, piece.color, queenside)
                push!(moves, move)
            end
        end
    end

    return moves

end

function available_moves_other(piece_id, game_state::GameState)
    #For all pieces except pawns and kings, for which additional considerations are needed

    piece = game_state.pieces[piece_id]
    vision = get_square_vision(piece_id, game_state.vision_graph) #squares seen by the piece
    current_position = get_position(piece_id,game_state.board) #Current position (coordinates) of the piece

    moves = AbstractMove[]
    for square in vision
        newboard = copy(game_state.board)

        if game_state.board[square] == 0 #Square is not occupied
            #make the move on the board
            newboard[current_position] = 0 
            newboard[square] = piece_id
            captured_id = 0

        elseif game_state.board[square] > 0 #Square is occupied
            #If square is occupied by opposite color, capture
            seen_piece_id = game_state.board[square]
            seen_piece = game_state.pieces[seen_piece_id]
            if seen_piece.color == piece.color #Can't capture same color pieces
                continue
            else
                newboard[current_position] = 0 
                newboard[square] = piece_id
                captured_id = seen_piece_id
            end
        end

        #make sure the move does not expose the king
        exposedking = is_king_exposed(newboard, piece_id, captured_id, game_state::GameState)

        incheck = game_state.check
        if incheck #If the king is in check, only accept moves that block
            new_vision_graph = create_vision_graph(newboard,game_state.pieces)
            incheck = is_in_check(piece.color, new_vision_graph, game_state.pieces)
        end

        if !exposedking && !incheck
            newmove = SimpleMove(piece_id, piece, current_position, square, captured_id)
            push!(moves, newmove)
        end
    end

    return moves

end

function available_moves(piece_id, game_state::GameState)
    piece = game_state.pieces[piece_id]

    if piece.color != game_state.turn
        print("Not your turn")
        return nothing
    end

    if piece.type == pawn 
        moves = available_moves_pawn(piece_id, game_state)
    elseif piece.type == king 
        moves = available_moves_king(piece_id, game_state)
    else
        moves = available_moves_other(piece_id, game_state)
    end

    return moves

end

function get_all_moves(game_state::GameState)
    allmoves = AbstractMove[]
    if game_state.turn == white
        turn_ids = 1:16
    else
        turn_ids = 17:32
    end

    for piece_id in turn_ids
        if piece_id in game_state.board
            moves = available_moves(piece_id, game_state)
            append!(allmoves, moves)
        end
    end

    return allmoves
end

function main()
    initial_game_state = initalize_board()
    display(initial_game_state)

    test_board = zeros(Int8,8,8)
    test_board[5,1] = 5 #white king
    test_board[1,8] = 29 #black king

    #test_board[1,1] = 1 #white queenside rook
    #test_board[8,1] = 8 #white kingside rook

    #test_board[4,2] = 25 #black queenside rook
    #test_board[8,1] = 32 #black kingside rook

    test_board[5,2] = 28 #black queen

    #test_board[7,4] = 30 #black bishop

    #test_board[5,3] = 21 #black e pawn
    test_board[4,3] = 20 #black d pawn

    #last_move = SimpleMove(20,initial_game_state.pieces[20],CartesianIndex(4,7),CartesianIndex(4,5),0)
    #last_move = SimpleMove(22,initial_game_state.pieces[22],CartesianIndex(6,7),CartesianIndex(6,5),0)
    #last_move = SimpleMove(32,initial_game_state.pieces[32],CartesianIndex(8,8),CartesianIndex(5,8),0)
    last_move = nothing

    turn = white

    vision_graph = create_vision_graph(test_board, initial_game_state.pieces)
    pieces_move_count = zeros(Int, 32)
    
    turn_in_check = is_in_check(turn, vision_graph, initial_game_state.pieces)
    println(turn_in_check)
    opp_in_check = is_in_check(get_opposite_color(turn), vision_graph, initial_game_state.pieces)

    if opp_in_check
        println("Illegal position")
    end

    game_state = GameState(test_board, initial_game_state.pieces, vision_graph, turn, turn_in_check, last_move, pieces_move_count)
    display(game_state)

    moves = available_moves(5,game_state)
    display(moves)

end

#main()