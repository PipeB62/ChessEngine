include("Moves.jl")
#include("BoardAndPieces.jl")
using Profile

global const PIECE_VALUES = Dict(pawn=>1, bishop=>3, knight=>3, rook=>5, queen=>9, king=>200)

global const INFTY = 100000
global const CENTER_HEATMAP = Int[
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 2, 2, 2, 2, 2, 2, 1,
    1, 2, 3, 3, 3, 3, 2, 1,
    1, 2, 3, 4, 4, 3, 2, 1,
    1, 2, 3, 4, 4, 3, 2, 1,
    1, 2, 3, 3, 3, 3, 2, 1,
    1, 2, 2, 2, 2, 2, 2, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
]

global const CORNER_HEATMAP = Int[
    4, 4, 3, 2, 2, 3, 4, 4,
    4, 4, 3, 2, 2, 3, 4, 4,
    3, 3, 3, 2, 2, 3, 3, 3,
    2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2,
    3, 3, 3, 2, 2, 3, 3, 3,
    4, 4, 3, 2, 2, 3, 4, 4,
    4, 4, 3, 2, 2, 3, 4, 4,
]

# Stage weights: pawns and kings don't count, minor pieces = 1, rooks = 2, queens = 4 => Max score = 24
global const GAME_STAGE_VALUES = Dict(pawn=>0, knight=>1, bishop=>1, rook=>2, queen=>4, king=>0)
global const STAGE_OPENING = 20  # ~83% material remaining
global const STAGE_ENDGAME = 8  # ~33% material remaining

function count_pieces(game_state::GameState)
    """
    Count the total number of pieces left on the board separated by color
    Function simply iterates over all remaining pieces 
    """
    white_count = 0
    black_count = 0

    for piece_id in 1:32
        # If piece is on board
        if game_state.piece_list[piece_id] > 0
            # Currently hardcoded id numbers
            if piece_id <= 16
                white_count += 1
            else
                black_count += 1
            end
        end
    end

    return white_count, black_count

end

function pieces_in_middle(game_state::GameState, min_rank::Int, max_rank::Int)
    """
    Count the total number of pieces in the "middle" (rankwise) of the board for each color. 

    Middle are ranks in [min_rank, max_rank]
    """
    white_count = 0
    black_count = 0
    for piece_id in 1:32
        square = game_state.piece_list[piece_id]
        if square > 0
            rank = get_rank(square)
            if min_rank <= rank <= max_rank
                if piece_id <= 16
                    white_count += 1
                else
                    black_count += 1
                end
            end
        end
    end
    return white_count, black_count
end

function game_stage(game_state::GameState)
    """
    Determine the stage of the game based on remaining material weight.
    Pawns and kings are excluded from the material score.
        Opening:     material score >= STAGE_OPENING  (most pieces still on board)
        Middlegame:  STAGE_ENDGAME <= material score < STAGE_OPENING
        Endgame:     material score < STAGE_ENDGAME
    """
    material_score = 0
    for piece_id in 1:32
        square = game_state.piece_list[piece_id]
        if square > 0
            material_score += GAME_STAGE_VALUES[game_state.pieces[square]]
        end
    end

    if material_score >= STAGE_OPENING
        return :Opening
    elseif material_score >= STAGE_ENDGAME
        return :Middlegame
    else
        return :Endgame
    end
end

function count_attackers(square::Int, attacked_by_color::Color, game_state::GameState)
    """
    Returns the number of pieces of color attacked_by_color that attack the given square.
    Based on is_under_attack but accumulates a count instead of returning on first attacker found.
    """
    count = 0
    mailbox_index = mailbox64[square]
    color = get_opposite_color(attacked_by_color)

    # Knight attacks
    for d in KNIGHT_JUMPS
        newsquare = mailbox[mailbox_index + d]
        if newsquare > 0
            if game_state.pieces[newsquare] == knight && game_state.colors[newsquare] == attacked_by_color
                count += 1
            end
        end
    end

    # Pawn attacks
    if color == white
        infront = UP
    else
        infront = DOWN
    end
    for d in [RIGHT, LEFT]
        newsquare = mailbox[mailbox_index + d + infront]
        if newsquare > 0
            if game_state.pieces[newsquare] == pawn && game_state.colors[newsquare] == attacked_by_color
                count += 1
            end
        end
    end

    # Rook/queen attacks
    for d in ROOK_DIRECTIONS
        v = d
        inside = true
        while inside
            newsquare = mailbox[mailbox_index + v]
            if newsquare > 0
                piece = game_state.pieces[newsquare]
                if piece == no_piece
                    v += d
                    continue
                elseif (piece == rook || piece == queen) && game_state.colors[newsquare] == attacked_by_color
                    count += 1
                    break
                else
                    break
                end
            else
                inside = false
            end
        end
    end

    # Bishop/queen attacks
    for d in BISHOP_DIRECTIONS
        v = d
        inside = true
        while inside
            newsquare = mailbox[mailbox_index + v]
            if newsquare > 0
                piece = game_state.pieces[newsquare]
                if piece == no_piece
                    v += d
                    continue
                elseif (piece == bishop || piece == queen) && game_state.colors[newsquare] == attacked_by_color
                    count += 1
                    break
                else
                    break
                end
            else
                inside = false
            end
        end
    end

    # King attacks
    for d in ALL_DIRECTIONS
        newsquare = mailbox[mailbox_index + d]
        if newsquare > 0
            if game_state.pieces[newsquare] == king && game_state.colors[newsquare] == attacked_by_color
                count += 1
            end
        end
    end

    return count
end

function space_control(game_state::GameState)
    """
    Measures space control: total attackers on each square weighted by CENTER_HEATMAP.
    A square attacked by multiple pieces contributes its heatmap value multiple times,
    rewarding coordination and redundancy of control over central squares.
    Returns a signed score: positive => white controls more space.
    """
    white_score = 0
    black_score = 0

    for square in 1:64
        white_score += is_under_attack(square, white, game_state) * CENTER_HEATMAP[square]
        black_score += is_under_attack(square, black, game_state) * CENTER_HEATMAP[square]
    end

    return white_score - black_score
end

function piece_value(piece::Piece, color::Color)
    if color == white
        mult = 1
    else 
        mult = -1
    end

    return mult*PIECE_VALUES[piece]
end

function piece_balance(game_state::GameState) #Positive => white has more pieces
    balance = 0
    for piece_id in 1:32
        square = game_state.piece_list[piece_id]
        if square>0
            balance += piece_value(game_state.pieces[square], game_state.colors[square])
        end
    end

    return balance
end

function development(game_state::GameState)
        
    white_pieces_ids = [2,3,6,7] #bishops and knights
    black_pieces_ids = [26,27,30,31]

    penalty = 0.0

    for id in white_pieces_ids
        if game_state.piece_move_count[id]==0
            penalty -= 0.5
        end
    end

    for id in black_pieces_ids
        if game_state.piece_move_count[id]==0
            penalty += 0.5
        end
    end

    # White queen
    id = 4
    if game_state.piece_move_count[id]==0
        penalty -= 50
    end

    # Black queen
    id = 32
    if game_state.piece_move_count[id]==0
        penalty += 50
    end

    return penalty
end

function eval_function(game_state::GameState)
    if game_state.turn == white
        mult = 1
    else
        mult = -1
    end

    piece_balance_weight = 1
    developement_weight = 0.5
    space_weight = 0.25

    # Prefer to move king away from center
    # Prefer to move pieces towards the king

    # Check what stage of the game we are in
    stage = game_stage(game_state)

    if stage == :Opening
        eval_score = mult * (piece_balance_weight * piece_balance(game_state) + 
                             developement_weight  * development(game_state) + 
                             space_weight         * space_control(game_state))

    elseif stage == :Middlegame
        eval_score = mult * (piece_balance_weight * piece_balance(game_state) + 
                             space_weight         * space_control(game_state))

    elseif stage == :Endgame
        eval_score = mult * (piece_balance_weight * piece_balance(game_state) +
                             2*space_weight       * space_control(game_state))

    end

    return eval_score
end

# function eval_function(game_state::GameState)
#     if game_state.turn == white
#         mult = 1
#     else 
#         mult = -1
#     end

#     f = mult*(piece_balance(game_state) + development(game_state))

#     return f
# end

function negamax2(game_state::GameState, depth::Int, alpha::Real = -INFTY, beta::Real = INFTY)
    """
    negamax with alpha beta pruning.
    """
    if depth==0
        return nothing, eval_function(game_state)
    end

    move_list = get_all_moves(game_state) #pseudo-legal moves
    best_score = -INFTY
    best_move = nothing

    illegal_moves_count = 0
    for move in move_list
        islegal = make_move!(game_state, move) 
        if islegal
            opp_move, opp_score = negamax2(game_state, depth-1, -beta, -alpha)
            unmake_move!(game_state)
            our_score = -opp_score

            alpha = max(alpha, our_score) # worse assured score

            if our_score > best_score
                best_score = our_score 
                best_move = move
            end

            if alpha >= beta
                break
            end

        else
            illegal_moves_count += 1
        end
    end

    if length(move_list)==illegal_moves_count #No available moves: stalemate or checkmate
        #Evaluate position
        if first(game_state.check_stack)
            #checkmate
            eval = -INFTY
        else
            #stalemate
            eval = 0
        end
        return nothing, eval
    end

    if isnothing(best_move) #Forced mate edge case?
        ix = findfirst(x->is_legal(game_state, x), move_list)
        best_move = move_list[ix]
    end

    return best_move, best_score

end

function main()
    game_state = initalize_board()
    println("Start...")
    best_move = negamax2(game_state, 1)
    println("Start 2...")
    #@profview best_move = negamax2(game_state, 4) #Only works when running from vs code. See what funcitions take the most time to run

    println("Best move:", best_move)
end
#main()