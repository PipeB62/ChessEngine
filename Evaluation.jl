include("Moves.jl")

global const PIECE_VALUES = Dict(pawn=>1, bishop=>3, knight=>3, rook=>5, queen=>9, king=>200)

global const INFTY = 100000

function piece_value(piece::Piece)
    if piece.color == white
        mult = 1
    else 
        mult = -1
    end

    return mult*PIECE_VALUES[piece.type]
end

function piece_balance(game_state::GameState)
    balance = 0
    for square_id in game_state.board
        if square_id>0
            balance += piece_value(game_state.pieces[square_id])
        end
    end

    return balance
end

function eval_function(game_state::GameState)
    if game_state.turn == white
        mult = 1
    else 
        mult = -1
    end

    f = mult*piece_balance(game_state)

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
    stack = [root] 

    while length(stack)>0

        cnode = stack[end]

        if length(cnode.move_queue) == 0 || cnode.depth == depth

            if length(stack)==1 #Got back to root node
                println("Done")
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
            end

        end

    end

end

function main()
    game_state = initalize_board()
    println("Start...")
    best_move = negamax(game_state, 3)

    println("Best move:", best_move)
end
#main()