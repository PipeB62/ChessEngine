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

function negamax(game_state::GameState, depth)

    root_move_list = get_all_moves(game_state)
    root = GameNode(game_state, root_move_list, 0, -INFTY, nothing)
    #stack = [root] 
    count = 0
    while length(stack)>0

        cnode = stack[end]

        if length(cnode.move_queue) == 0 || cnode.depth == depth

            if length(stack)==1 #Got back to root node
                println("Done")
                println(count)
                return cnode.best_move
            end
            
            #Evaluate position
            eval = eval_function(cnode.game_state)

            #Move backward
            prev_node = stack[end-1]
            if -eval > prev_node.score
                prev_node.score = -eval 
                prev_node.best_move = cnode.game_state.last_move
            end
            
            pop!(stack)

        elseif length(cnode.move_queue) > 0
            #Extract move from move list
            move = pop!(cnode.move_queue)

            #Create new node from new position
            new_game_state = deepcopy(cnode.game_state)
            make_move!(new_game_state, move)
            new_move_list = get_all_moves(new_game_state)

            if length(new_move_list)==0 #No available moves: stalemate or checkmate
                #Evaluate position
                if new_game_state.check
                    #checkmate
                    eval = -INFTY
                else
                    #stalemate
                    eval = 0
                end

                #Move backward
                prev_node = stack[end-1]
                if -eval > prev_node.score
                    prev_node.score = -eval 
                    prev_node.best_move = cnode.game_state.last_move
                end

            else
                new_node = GameNode(new_game_state, new_move_list, cnode.depth+1, -INFTY, nothing)

                #Add node to stack
                push!(stack, new_node)
                count+=1
            end

        end

    end

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