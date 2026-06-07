include("Moves.jl")
#include("BoardAndPieces.jl")
using Profile

global const PIECE_VALUES = Dict(pawn=>1, bishop=>3, knight=>3, rook=>5, queen=>9, king=>200)

global const INFTY = 100000

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

    return penalty
end

function eval_function(game_state::GameState)
    if game_state.turn == white
        mult = 1
    else 
        mult = -1
    end

    f = mult*(piece_balance(game_state) + development(game_state))

    return f
end

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