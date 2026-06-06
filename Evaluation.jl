include("Moves.jl")
include("BoardAndPieces.jl")
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

function piece_balance(game_state::GameState)
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

mutable struct GameNode
    game_state::GameState
    move_queue::Vector{AbstractMove}
    depth::Int
    score::Int
    best_move::Union{AbstractMove, Nothing}
end

function negamax2(game_state::GameState, depth)
    if depth==0
        return nothing, eval_function(game_state)
    end

    move_list = get_legal_moves(game_state)
    best_score = -INFTY
    best_move = nothing

    if length(move_list)==0 #No available moves: stalemate or checkmate
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

    for move in move_list
        make_move!(game_state, move)
        opp_move, opp_score = negamax2(game_state, depth-1)
        unmake_move!(game_state)
        our_score = -opp_score

        if our_score > best_score
            best_score = our_score 
            best_move = move
        end
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